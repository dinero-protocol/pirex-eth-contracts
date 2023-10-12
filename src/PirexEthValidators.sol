// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ReentrancyGuard} from "solmate/utils/ReentrancyGuard.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {AccessControlDefaultAdminRules} from "openzeppelin-contracts/contracts/access/AccessControlDefaultAdminRules.sol";
import {ERC1155Solmate} from "./tokens/ERC1155Solmate.sol";
import {Errors} from "./libraries/Errors.sol";
import {DataTypes} from "./libraries/DataTypes.sol";
import {ValidatorQueue} from "./libraries/ValidatorQueue.sol";
import {IOracleAdapter} from "./interfaces/IOracleAdapter.sol";
import {IPirexEth} from "./interfaces/IPirexEth.sol";
import {IDepositContract} from "./interfaces/IDepositContract.sol";
import {AutoPxEth} from "./AutoPxEth.sol";
import {PxEth} from "./PxEth.sol";

/// @title  Responsible for managing validators and deposits for the Eth2.0 deposit contract
/// @author redactedcartel.finance
abstract contract PirexEthValidators is
    ReentrancyGuard,
    AccessControlDefaultAdminRules,
    IPirexEth
{
    using ValidatorQueue for DataTypes.ValidatorDeque;
    using SafeTransferLib for ERC20;

    // Denominator
    uint256 public constant DENOMINATOR = 1_000_000;

    // Roles
    bytes32 public constant KEEPER_ROLE = keccak256("KEEPER_ROLE");
    bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");

    uint256 internal constant _NOT_PAUSED = 1;
    uint256 internal constant _PAUSED = 2;

    // External Contract
    address public immutable beaconChainDepositContract;

    // Deposit that a validator must do prior to adding to initialized validator queue
    uint256 public immutable preDepositAmount;

    // Default deposit size can only be set once
    uint256 public immutable DEPOSIT_SIZE;

    // Withdrawal credentials
    bytes public withdrawalCredentials;

    // Buffer for instant withdrawals and emergency topups
    uint256 public buffer;

    // Maximum buffer for instant withdrawals and emergency topups
    uint256 public maxBufferSize;

    // Percentage from pxEth total supply will be allocated to max buffer size
    uint256 public maxBufferSizePct;

    // Maximum count of validators to be processed in a single _deposit call
    uint256 public maxProcessedValidatorCount = 20;

    // Pirex contracts
    ERC1155Solmate public upxEth;
    PxEth public pxEth;
    AutoPxEth public autoPxEth;
    IOracleAdapter public oracleAdapter;
    address public rewardRecipient;

    // Whether depositing ether to beacon chain deposit contract is paused
    uint256 public depositEtherPaused;

    // Buffer for pending deposits to be staked
    // It is required to be greater than or equal to multiples of DEPOSIT_SIZE
    // including preDepositAmount
    uint256 public pendingDeposit;

    // Queue to prioritise validator spinning on FIFO basis
    DataTypes.ValidatorDeque internal _initializedValidators;

    // Queue to prioritise next validator to be exited when required on FIFO basis
    DataTypes.ValidatorDeque internal _stakingValidators;

    // Buffer for withdrawals to be unstaked
    // It is required to be greater than or equal to multiples of DEPOSIT_SIZE
    uint256 public pendingWithdrawal;

    // ETH that is available for redemptions
    uint256 public outstandingRedemptions;

    // Batch Id for validator's voluntary exit
    uint256 public batchId;

    // End block for the ETH rewards calculation
    uint256 public endBlock;

    // Validator statuses
    mapping(bytes => DataTypes.ValidatorStatus) public status;

    // Map batchId to validator pubKey
    mapping(uint256 => bytes) public batchIdToValidator;

    // Accounts for burning pxEth when buffer is used of top-up and validator is slashed
    mapping(address => bool) public burnerAccounts;

    // Events
    event ValidatorDeposit(bytes pubKey);
    event SetContract(DataTypes.Contract indexed c, address contractAddress);
    event DepositEtherPaused(uint256 newStatus);
    event Harvest(uint256 amount, uint256 endBlock);
    event SetMaxBufferSizePct(uint256 pct);
    event ApproveBurnerAccount(address indexed account);
    event RevokeBurnerAccount(address indexed account);
    event DissolveValidator(bytes pubKey);
    event SlashValidator(
        bytes pubKey,
        bool useBuffer,
        uint256 releasedAmount,
        uint256 penalty
    );
    event TopUp(bytes pubKey, bool useBuffer, uint256 topUpAmount);
    event SetMaxProcessedValidatorCount(uint256 count);
    event UpdateMaxBufferSize(uint256 maxBufferSize);
    event SetWithdrawCredentials(bytes withdrawalCredentials);

    // Modifiers
    modifier onlyRewardRecipient() {
        if (msg.sender != rewardRecipient) revert Errors.NotRewardRecipient();
        _;
    }

    modifier onlyWhenDepositEtherPaused() {
        if (depositEtherPaused == _NOT_PAUSED)
            revert Errors.DepositingEtherNotPaused();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                        CONSTRUCTOR/INITIALIZATION LOGIC
    //////////////////////////////////////////////////////////////*/

    /**
        @param  _pxEth                     address  PxETH contract address
        @param  _admin                     address  Admin address
        @param  _beaconChainDepositContract  address  The address of the deposit precompile
        @param  _upxEth                    address  UpxETH address
        @param  _depositSize               uint256  Amount of ETH to stake
        @param  _preDepositAmount          uint256  Amount of ETH for pre-deposit
        @param  _initialDelay              uint48   Delay required to schedule the acceptance 
                                                    of a access control transfer started
     */
    constructor(
        address _pxEth,
        address _admin,
        address _beaconChainDepositContract,
        address _upxEth,
        uint256 _depositSize,
        uint256 _preDepositAmount,
        uint48 _initialDelay
    ) AccessControlDefaultAdminRules(_initialDelay, _admin) {
        if (_pxEth == address(0)) revert Errors.ZeroAddress();
        if (_beaconChainDepositContract == address(0))
            revert Errors.ZeroAddress();
        if (_upxEth == address(0)) revert Errors.ZeroAddress();
        if (_depositSize < 1 ether && _depositSize % 1 gwei != 0)
            revert Errors.ZeroMultiplier();
        if (
            _preDepositAmount > _depositSize ||
            _preDepositAmount < 1 ether ||
            _preDepositAmount % 1 gwei != 0
        ) revert Errors.ZeroMultiplier();

        pxEth = PxEth(_pxEth);
        DEPOSIT_SIZE = _depositSize;
        beaconChainDepositContract = _beaconChainDepositContract;
        preDepositAmount = _preDepositAmount;
        upxEth = ERC1155Solmate(_upxEth);
        depositEtherPaused = _NOT_PAUSED;
    }

    /*//////////////////////////////////////////////////////////////
                                VIEW
    //////////////////////////////////////////////////////////////*/

    /**
        @notice Get the number of initialized validators
        @return uint256
     */
    function getInitializedValidatorCount() external view returns (uint256) {
        return _initializedValidators.count();
    }

    /**
        @notice Get the number of staking validators
        @return uint256
     */
    function getStakingValidatorCount() public view returns (uint256) {
        return _stakingValidators.count();
    }

    /**
        @notice Get the initialized validator info at the specified index
        @param  _i  uint256  Index
        @return     bytes    Public key
        @return     bytes    Withdrawal credentials
        @return     bytes    Signature
        @return     bytes32  Deposit data root hash
        @return     address  pxETH receiver
     */
    function getInitializedValidatorAt(
        uint256 _i
    )
        external
        view
        returns (bytes memory, bytes memory, bytes memory, bytes32, address)
    {
        return _initializedValidators.get(withdrawalCredentials, _i);
    }

    /**
        @notice Get the staking validator info at the specified index
        @param  _i  uint256  Index
        @return     bytes    Public key
        @return     bytes    Withdrawal credentials
        @return     bytes    Signature
        @return     bytes32  Deposit data root hash
        @return     address  pxETH receiver
     */
    function getStakingValidatorAt(
        uint256 _i
    )
        external
        view
        returns (bytes memory, bytes memory, bytes memory, bytes32, address)
    {
        return _stakingValidators.get(withdrawalCredentials, _i);
    }

    /*//////////////////////////////////////////////////////////////
                        RESTRICTED FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
        @notice Set a contract address
        @param  c                enum     Contract
        @param  contractAddress  address  Contract address    
     */
    function setContract(
        DataTypes.Contract c,
        address contractAddress
    ) external onlyRole(GOVERNANCE_ROLE) {
        if (contractAddress == address(0)) revert Errors.ZeroAddress();

        emit SetContract(c, contractAddress);

        if (c == DataTypes.Contract.UpxEth) {
            upxEth = ERC1155Solmate(contractAddress);
        }
        if (c == DataTypes.Contract.PxEth) {
            pxEth = PxEth(contractAddress);
        }
        if (c == DataTypes.Contract.AutoPxEth) {
            ERC20 pxEthERC20 = ERC20(address(pxEth));
            address oldVault = address(autoPxEth);

            if (oldVault != address(0)) {
                pxEthERC20.safeApprove(oldVault, 0);
            }

            autoPxEth = AutoPxEth(contractAddress);
            pxEthERC20.safeApprove(address(autoPxEth), type(uint256).max);
        }
        if (c == DataTypes.Contract.OracleAdapter) {
            oracleAdapter = IOracleAdapter(contractAddress);
        }
        if (c == DataTypes.Contract.RewardRecipient) {
            rewardRecipient = contractAddress;
            withdrawalCredentials = abi.encodePacked(
                bytes1(0x01),
                bytes11(0x0),
                contractAddress
            );

            emit SetWithdrawCredentials(withdrawalCredentials);
        }
    }

    /**
        @notice Set the percentage that will be applied to
                total supply of pxEth to determine maxBufferSize
        @param  _pct  uint256  Max buffer size percentage
     */
    function setMaxBufferSizePct(
        uint256 _pct
    ) external onlyRole(GOVERNANCE_ROLE) {
        if (_pct > DENOMINATOR) {
            revert Errors.ExceedsMax();
        }

        maxBufferSizePct = _pct;

        emit SetMaxBufferSizePct(_pct);
    }

    /**
        @notice Set maximum count of processed validator in a _deposit call
        @param  _count  uint256  Max processed count
     */
    function setMaxProcessedValidatorCount(
        uint256 _count
    ) external onlyRole(GOVERNANCE_ROLE) {
        if (_count == 0) {
            revert Errors.InvalidMaxProcessedCount();
        }

        maxProcessedValidatorCount = _count;

        emit SetMaxProcessedValidatorCount(_count);
    }

    /**
        @notice Toggle allowing depositing ETH to validators
     */
    function togglePauseDepositEther() external onlyRole(GOVERNANCE_ROLE) {
        depositEtherPaused = depositEtherPaused == _NOT_PAUSED
            ? _PAUSED
            : _NOT_PAUSED;

        emit DepositEtherPaused(depositEtherPaused);
    }

    /**
        @notice Approve/revoke addresses as burner accounts
        @param  _accounts  address[]  Addresses
        @param  _state     bool       Burner acount state
     */
    function toggleBurnerAccounts(
        address[] calldata _accounts,
        bool _state
    ) external onlyRole(GOVERNANCE_ROLE) {
        uint256 _len = _accounts.length;

        for (uint256 _i; _i < _len; ) {
            address account = _accounts[_i];

            burnerAccounts[account] = _state;

            if (_state) {
                emit ApproveBurnerAccount(account);
            } else {
                emit RevokeBurnerAccount(account);
            }

            unchecked {
                ++_i;
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                            MUTATIVE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
        @notice Update validator to Dissolve once Oracle updates on ETH being released
        @param  _pubKey  bytes  Public key of the validator
     */
    function dissolveValidator(
        bytes calldata _pubKey
    ) external payable override onlyRewardRecipient {
        uint256 _amount = msg.value;
        if (_amount != DEPOSIT_SIZE) revert Errors.InvalidAmount();
        if (status[_pubKey] != DataTypes.ValidatorStatus.Withdrawable)
            revert Errors.NotWithdrawable();

        status[_pubKey] = DataTypes.ValidatorStatus.Dissolved;

        outstandingRedemptions += _amount;

        emit DissolveValidator(_pubKey);
    }

    /**
        @notice Update validator state to be slashed
        @param  _pubKey          bytes                      Public key of the validator
        @param  _removeIndex     uint256                    Index of validator to be slashed
        @param  _amount          uint256                    ETH amount released from Beacon chain 
        @param  _unordered       bool                       Whether remove from staking validator queue in order or not
        @param  _useBuffer       bool                       whether to use buffer to compensate the loss  
        @param  _burnerAccounts  DataTypes.BurnerAccount[]  Burner accounts
     */
    function slashValidator(
        bytes calldata _pubKey,
        uint256 _removeIndex,
        uint256 _amount,
        bool _unordered,
        bool _useBuffer,
        DataTypes.BurnerAccount[] calldata _burnerAccounts
    ) external payable override onlyRewardRecipient {
        uint256 _ethAmount = msg.value;
        uint256 _defaultDepositSize = DEPOSIT_SIZE;
        DataTypes.ValidatorStatus _status = status[_pubKey];

        if (
            _status != DataTypes.ValidatorStatus.Staking &&
            _status != DataTypes.ValidatorStatus.Withdrawable
        ) revert Errors.StatusNotWithdrawableOrStaking();

        if (_useBuffer) {
            _updateBuffer(_defaultDepositSize - _ethAmount, _burnerAccounts);
        } else if (_ethAmount != _defaultDepositSize) {
            revert Errors.InvalidAmount();
        }

        // It is possible that validator can be slashed while exiting
        if (_status == DataTypes.ValidatorStatus.Staking) {
            bytes memory _removedPubKey;

            if (!_unordered) {
                _removedPubKey = _stakingValidators.removeOrdered(_removeIndex);
            } else {
                _removedPubKey = _stakingValidators.removeUnordered(
                    _removeIndex
                );
            }

            assert(keccak256(_pubKey) == keccak256(_removedPubKey));

            _addPendingDeposit(_defaultDepositSize);
        } else {
            outstandingRedemptions += _defaultDepositSize;
        }
        status[_pubKey] = DataTypes.ValidatorStatus.Slashed;

        emit SlashValidator(
            _pubKey,
            _useBuffer,
            _amount,
            DEPOSIT_SIZE - _amount
        );
    }

    /**
        @notice Add multiple synced validators in the queue to be ready for staking
        @param  _validators  DataTypes.Validator[]  Validators details
     */
    function addInitializedValidators(
        DataTypes.Validator[] memory _validators
    ) external onlyWhenDepositEtherPaused onlyRole(GOVERNANCE_ROLE) {
        uint256 _arrayLength = _validators.length;
        for (uint256 _i; _i < _arrayLength; ) {
            if (
                status[_validators[_i].pubKey] != DataTypes.ValidatorStatus.None
            ) revert Errors.NoUsedValidator();

            _initializedValidators.add(_validators[_i], withdrawalCredentials);

            unchecked {
                ++_i;
            }
        }
    }

    /**
        @notice Swap initialized validators specified by the indexes
        @param  _fromIndex  uint256  From index
        @param  _toIndex    uint256  To index
     */
    function swapInitializedValidator(
        uint256 _fromIndex,
        uint256 _toIndex
    ) external onlyWhenDepositEtherPaused onlyRole(GOVERNANCE_ROLE) {
        _initializedValidators.swap(_fromIndex, _toIndex);
    }

    /**
        @notice Pop initialized validators
        @param  _times  uint256  Count of pop operations
     */
    function popInitializedValidator(
        uint256 _times
    ) external onlyWhenDepositEtherPaused onlyRole(GOVERNANCE_ROLE) {
        _initializedValidators.pop(_times);
    }

    /**
        @notice Remove initialized validators
        @param  _removeIndex  uint256  Remove index
        @param  _unordered    bool     Whether unordered or ordered
     */
    function removeInitializedValidator(
        bytes calldata _pubKey,
        uint256 _removeIndex,
        bool _unordered
    ) external onlyWhenDepositEtherPaused onlyRole(GOVERNANCE_ROLE) {
        bytes memory _removedPubKey;

        if (_unordered) {
            _removedPubKey = _initializedValidators.removeUnordered(
                _removeIndex
            );
        } else {
            _removedPubKey = _initializedValidators.removeOrdered(_removeIndex);
        }

        assert(keccak256(_removedPubKey) == keccak256(_pubKey));
    }

    /**
        @notice Clear initialized validators
     */
    function clearInitializedValidator()
        external
        onlyWhenDepositEtherPaused
        onlyRole(GOVERNANCE_ROLE)
    {
        _initializedValidators.clear();
    }

    /**
        @notice Trigger deposit to the ETH 2.0 deposit contract when allowed
    */
    function depositPrivileged() external nonReentrant onlyRole(KEEPER_ROLE) {
        // Initial pause check
        if (depositEtherPaused == _PAUSED)
            revert Errors.DepositingEtherPaused();

        _deposit();
    }

    /**
        @notice Topup ETH to the validator if current balance drops below effective balance  
        @param  _pubKey           bytes                      Validator public key
        @param  _signature        bytes                      A BLS12-381 signature
        @param  _depositDataRoot  bytes32                    The SHA-256 hash of the SSZ-encoded DepositData object.
        @param  _topUpAmount      uint256                    Top-up amount
        @param  _useBuffer        bool                       Whether to use buffer
        @param  _burnerAccounts   DataTypes.BurnerAccount[]  Burner accounts
    */
    function topUpStake(
        bytes calldata _pubKey,
        bytes calldata _signature,
        bytes32 _depositDataRoot,
        uint256 _topUpAmount,
        bool _useBuffer,
        DataTypes.BurnerAccount[] calldata _burnerAccounts
    ) external payable nonReentrant onlyRole(KEEPER_ROLE) {
        if (status[_pubKey] != DataTypes.ValidatorStatus.Staking)
            revert Errors.ValidatorNotStaking();

        if (_useBuffer) {
            if (msg.value > 0) {
                revert Errors.NoETHAllowed();
            }
            _updateBuffer(_topUpAmount, _burnerAccounts);
        } else if (msg.value != _topUpAmount) {
            revert Errors.NoETH();
        }

        (bool success, ) = beaconChainDepositContract.call{value: _topUpAmount}(
            abi.encodeCall(
                IDepositContract.deposit,
                (_pubKey, withdrawalCredentials, _signature, _depositDataRoot)
            )
        );

        assert(success);

        emit TopUp(_pubKey, _useBuffer, _topUpAmount);
    }

    /**
        @notice Harvest and mint staking rewards when available
        @param  _endBlock  uint256  Block until which ETH rewards is computed
    */
    function harvest(
        uint256 _endBlock
    ) external payable override onlyRewardRecipient {
        if (msg.value != 0) {
            // update end block
            endBlock = _endBlock;

            // Mint pxETH directly for the vault
            _mintPxEth(address(autoPxEth), msg.value);

            // Update rewards tracking with the newly added rewards
            autoPxEth.notifyRewardAmount();

            // Direct the excess balance for pending deposit
            _addPendingDeposit(msg.value);

            emit Harvest(msg.value, _endBlock);
        }
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
        @notice Internal method for minting pxETH
        @param  _account  uint256  Account
        @param  _amount   uint256  Amount
    */
    function _mintPxEth(address _account, uint256 _amount) internal {
        pxEth.mint(_account, _amount);
        uint256 _maxBufferSize = (pxEth.totalSupply() * maxBufferSizePct) /
            DENOMINATOR;
        maxBufferSize = _maxBufferSize;
        emit UpdateMaxBufferSize(_maxBufferSize);
    }

    /**
        @notice Internal method for burning pxETH
        @param  _account  uint256  Account
        @param  _amount   uint256  Amount
    */
    function _burnPxEth(address _account, uint256 _amount) internal {
        pxEth.burn(_account, _amount);
        uint256 _maxBufferSize = (pxEth.totalSupply() * maxBufferSizePct) /
            DENOMINATOR;
        maxBufferSize = _maxBufferSize;
        emit UpdateMaxBufferSize(_maxBufferSize);
    }

    /**
        @notice Spin up validator if sufficient ETH is available
     */
    function _deposit() internal {
        uint256 remainingCount = maxProcessedValidatorCount;
        uint256 _remainingdepositAmount = DEPOSIT_SIZE - preDepositAmount;

        while (
            _initializedValidators.count() != 0 &&
            pendingDeposit >= _remainingdepositAmount &&
            remainingCount > 0
        ) {
            // Get validator information
            (
                bytes memory _pubKey,
                bytes memory _withdrawalCredentials,
                bytes memory _signature,
                bytes32 _depositDataRoot,
                address _receiver
            ) = _initializedValidators.getNext(withdrawalCredentials);

            // Make sure the validator hasn't been deposited into already
            // to prevent sending an extra eth equal to `_remainingdepositAmount`
            // until withdrawals are allowed
            if (status[_pubKey] != DataTypes.ValidatorStatus.None)
                revert Errors.NoUsedValidator();

            (bool success, ) = beaconChainDepositContract.call{
                value: _remainingdepositAmount
            }(
                abi.encodeCall(
                    IDepositContract.deposit,
                    (
                        _pubKey,
                        _withdrawalCredentials,
                        _signature,
                        _depositDataRoot
                    )
                )
            );

            assert(success);

            pendingDeposit -= _remainingdepositAmount;

            if (preDepositAmount != 0) {
                _mintPxEth(_receiver, preDepositAmount);
            }

            unchecked {
                --remainingCount;
            }

            status[_pubKey] = DataTypes.ValidatorStatus.Staking;

            _stakingValidators.add(
                DataTypes.Validator(
                    _pubKey,
                    _signature,
                    _depositDataRoot,
                    _receiver
                ),
                _withdrawalCredentials
            );

            emit ValidatorDeposit(_pubKey);
        }
    }

    /**
        @notice Add pending deposit and spin up validator if required ETH available
        @param  _amount  uint256  ETH asset amount
     */
    function _addPendingDeposit(uint256 _amount) internal virtual {
        uint256 _remainingBufferSpace = (
            maxBufferSize > buffer ? maxBufferSize - buffer : 0
        );
        uint256 _remainingAmount = _amount;

        if (_remainingBufferSpace != 0) {
            bool _canBufferSpaceFullyUtilized = _remainingBufferSpace <=
                _remainingAmount;
            buffer += _canBufferSpaceFullyUtilized
                ? _remainingBufferSpace
                : _remainingAmount;
            _remainingAmount -= _canBufferSpaceFullyUtilized
                ? _remainingBufferSpace
                : _remainingAmount;
        }

        pendingDeposit += _remainingAmount;

        if (depositEtherPaused == _NOT_PAUSED) {
            // Spin up a validator when possible
            _deposit();
        }
    }

    /**
        @notice Internal handler for validator related logic on redemption
        @param  _pxEthAmount                 uint256  Amount of pxETH
        @param  _receiver                    address  Receiver for upxETH
        @param  _shouldTriggerValidatorExit  bool     Whether initiate partial redemption 
                                                      with validator exit or not                                            
    */
    function _initiateRedemption(
        uint256 _pxEthAmount,
        address _receiver,
        bool _shouldTriggerValidatorExit
    ) internal {
        pendingWithdrawal += _pxEthAmount;

        while (pendingWithdrawal / DEPOSIT_SIZE != 0) {
            uint256 _allocationPossible = DEPOSIT_SIZE +
                _pxEthAmount -
                pendingWithdrawal;

            upxEth.mint(_receiver, batchId, _allocationPossible, "");

            (bytes memory _pubKey, , , , ) = _stakingValidators.getNext(
                withdrawalCredentials
            );

            pendingWithdrawal -= DEPOSIT_SIZE;
            _pxEthAmount -= _allocationPossible;

            oracleAdapter.requestVoluntaryExit(_pubKey);

            batchIdToValidator[batchId++] = _pubKey;
            status[_pubKey] = DataTypes.ValidatorStatus.Withdrawable;
        }

        if (_shouldTriggerValidatorExit && _pxEthAmount > 0)
            revert Errors.NoPartialInitiateRedemption();

        if (_pxEthAmount > 0) {
            upxEth.mint(_receiver, batchId, _pxEthAmount, "");
        }
    }

    function _updateBuffer(
        uint256 _amount,
        DataTypes.BurnerAccount[] calldata _burnerAccounts
    ) private {
        if (buffer < _amount) {
            revert Errors.NotEnoughBuffer();
        }
        uint256 _len = _burnerAccounts.length;
        uint256 _sum;

        for (uint256 _i; _i < _len; ) {
            if (!burnerAccounts[_burnerAccounts[_i].account])
                revert Errors.AccountNotApproved();

            _sum += _burnerAccounts[_i].amount;

            _burnPxEth(_burnerAccounts[_i].account, _burnerAccounts[_i].amount);

            unchecked {
                ++_i;
            }
        }

        assert(_sum == _amount);
        buffer -= _amount;
    }
}
