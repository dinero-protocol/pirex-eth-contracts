// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {IERC20} from "openzeppelin-contracts/contracts/interfaces/IERC20.sol";
import {IAutoPxEth} from "../interfaces/IAutoPxEth.sol";
import {L1SyncPool} from "src/layer2/L1SyncPool.sol";
import {IPirexEth} from "../interfaces/IPirexEthDeposit.sol";
import {ReentrancyGuardUpgradeable} from "openzeppelin-contracts-upgradeable/contracts/utils/ReentrancyGuardUpgradeable.sol";
import {PausableUpgradeable} from "openzeppelin-contracts-upgradeable/contracts/utils/PausableUpgradeable.sol";
import {OAppUpgradeable} from "src/vendor/layerzero-upgradeable/oapp/OAppUpgradeable.sol";
import {MessagingFee, MessagingReceipt} from "src/vendor/layerzero-upgradeable/oapp/OAppSenderUpgradeable.sol";
import {OAppOptionsType3Upgradeable} from "src/vendor/layerzero-upgradeable/oapp/libs/OAppOptionsType3Upgradeable.sol";
import {Origin} from "src/vendor/layerzero-upgradeable/oapp/interfaces/IOAppReceiver.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import {Constants} from "./libraries/Constants.sol";
import {Errors} from "./libraries/Errors.sol";

/**
 * @title  LiquidStakingTokenLockbox
 * @notice An OApp contract for handling LiquidStakingToken operations between mainnet and L2.
 * @dev    This contract facilitates interactions between mainnet PirexEth contracts and the L2 system.
 * @author redactedcartel.finance
 */
contract LiquidStakingTokenLockbox is
    L1SyncPool,
    OAppUpgradeable,
    OAppOptionsType3Upgradeable,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable
{
    /**
     * @dev Library: SafeERC20 - Provides safe transfer functions for ERC20 tokens.
     */
    using SafeERC20 for IERC20;

    /**
     * @dev Library: FixedPointMathLib - Provides fixed-point arithmetic for uint256.
     */
    using FixedPointMathLib for uint256;

    /**
     * @notice The destination endpoint ID for L2.
     * @dev This constant defines the destination endpoint ID for the L2.
     */
    uint32 private immutable L2_EID;

    /// @custom:storage-location erc7201:redacted.storage.LiquidStakingTokenLockbox
    struct LockboxStorage {
        /**
         * @notice The autoPxEth vault that holds the assets.
         * @dev This variable holds the address of the autoPxEth contract instance.
         */
        IAutoPxEth autoPxEth;
        /**
         * @notice The average exchange rate between the share apxEth and pxEth.
         * @dev This constant defines the exchange rate between the share apxEth and pxEth, used for accounting rewards accrued.
         */
        uint256 avgAssetsPerShare;
        /**
         * @notice The total shares in the vault.
         * @dev This variable holds the total shares in the vault.
         */
        uint256 totalShares;
        /**
         * @notice The pending deposit amount.
         * @dev This variable holds the amount received from L1SyncPool that has not been deposited into the vault.
         */
        uint256 pendingDeposit;
        /**
         * @dev the maximum number of synced Ids to be sent in a single message.
         * @dev This variable holds the maximum number of synced Ids to be sent in a single message to avoid out of gas.
         */
        uint256 maxSyncedIdBatch;
        /**
         * @notice The nonce for the received messages.
         * @dev Mapping to track the maximum received nonce for each source endpoint and sender
         */
        mapping(uint32 eid => mapping(bytes32 sender => uint64 nonce)) receivedNonce;
        /**
         * @notice The array of synced IDs pending finalization on L2.
         * @dev This variable holds the array of synced IDs which the finalization msg
         * has been received from the native bridge but it's pending finalization on L2.
         */
        bytes32[] syncedIds;
        /**
         * @notice The index of the first synced ID in the syncedIds array.
         * @dev This variable holds the index of the first synced ID in the syncedIds array
         * to avoid iterating over the entire array on each deposit. It is updated on rebases and deposits.
         */
        uint256 firstSyncedIdIndex;
        /**
         * @notice Mapping to track the accounts that can pause the contract.
         * @dev This mapping holds the accounts that can pause the contract.
         */
        mapping(address => bool) canPause;
    }

    // keccak256(abi.encode(uint256(keccak256(redacted.storage.LiquidStakingTokenLockbox)) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant LockboxStorageLocation =
        0x66e37df93132872b068c94e269011111fc6654928406c14abdb4dc0ec2753900;

    function _getLockboxStorage()
        private
        pure
        returns (LockboxStorage storage $)
    {
        assembly {
            $.slot := LockboxStorageLocation
        }
    }

    /**
     * @notice Emitted on sending deposit message.
     * @dev    Origin token address is set to address(0) for native (ETH) deposit
     * @param  guid             bytes32  GUID of the OFT message.
     * @param  fromAddress      address  Address of the sender on the src chain.
     * @param  toAddress        address  Address of the recipient on the src chain.
     * @param  originToken      address  Origin token address used for deposit
     * @param  amount           uint256  Deposit amount (in pxEth).
     * @param  assetsPerShare   uint256  The assetsPerShare at the time of deposit.
     */
    event Deposit(
        bytes32 indexed guid,
        address indexed fromAddress,
        address indexed toAddress,
        address originToken,
        uint256 amount,
        uint256 assetsPerShare
    );

    /**
     * @notice Emitted on sending rebase message.
     * @param  guid             bytes32  GUID of the OFT message.
     * @param  caller           address  Address of the rebase caller.
     * @param  amount           uint256  Total rewards accrued value.
     * @param  assetsPerShare   uint256  The assetsPerShare at the time of rebase.
     */
    event Rebase(
        bytes32 indexed guid,
        address indexed caller,
        uint256 amount,
        uint256 assetsPerShare
    );

    /**
     * @notice Emitted on receiving and processing withdrawal message.
     * @param  guid       bytes32  GUID of the OFT message.
     * @param  toAddress  address  Address of the recipient on the src chain.
     * @param  amount     uint256  Withdrawal amount (in pxEth).
     */
    event Withdrawal(
        bytes32 indexed guid,
        address indexed toAddress,
        uint256 amount
    );

    /**
     * @notice Emitted on deposits received from the sync pool.
     * @param  amount           uint256  Deposit amount (in pxEth).
     * @param  shouldCompound   bool  Whether funds were deposited into the vault.
     */
    event DepositSync(uint256 amount, bool shouldCompound);

    /**
     * @notice Emitted on withdrawals sent to the sync pool.
     * @param  amount   uint256  Withdrawal amount (in pxEth).
     */
    event WithdrawalSync(uint256 amount);

    /**
     * @notice Emitted when the pause is set.
     * @param  account  address  The account that can pause the contract.
     * @param  allowed  bool     The allowed status.
     */
    event canPauseSet(address indexed account, bool allowed);

    /**
     * @notice Contract constructor to initialize LiquidStakingTokenVault with necessary parameters and configurations.
     * @dev    This constructor sets up the LiquidStakingTokenVault contract, configuring key parameters and initializing state variables.
     * @param  _endpoint   address  The address of the LOCAL LayerZero endpoint.
     * @param  _dstEid     uint32   The destination endpoint ID for L2.
     */
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address _endpoint, uint32 _dstEid) OAppUpgradeable(_endpoint) {
        L2_EID = _dstEid;
        _disableInitializers();
    }

    /**
     * @dev modifier to allow only the owner or the canPause address to pause the contract
     */
    modifier onlyCanPause() {
        if (!_canPause(_msgSender())) revert Errors.NotAllowed();
        _;
    }

    /**
     * @notice LiquidStakingTokenVault initializer with necessary parameters and configurations.
     * @dev    This initializer sets up the LiquidStakingTokenVault contract, configuring key parameters and initializing state variables.
     * @param  _owner      address The owner of the contract.
     * @param  _delegate   address  The delegate capable of making OApp configurations inside of the endpoint.
     * @param  _pirexEth   address  PirexEth contract address.
     * @param  _autoPxEth  address  AutoPxEth contract address.
     */
    function initialize(
        address _delegate,
        address _owner,
        address _pirexEth,
        address _pxEth,
        address _autoPxEth,
        uint256 _maxSyncedIdBatch
    ) external initializer {
        if (_pirexEth == address(0)) revert Errors.ZeroAddress();
        if (_pxEth == address(0)) revert Errors.ZeroAddress();
        if (_autoPxEth == address(0)) revert Errors.ZeroAddress();

        __L1BaseSyncPool_init(_pirexEth, _pxEth);
        __LiquidStakingTokenLockbox_init(
            _delegate,
            _owner,
            _autoPxEth,
            _maxSyncedIdBatch
        );
    }

    function __LiquidStakingTokenLockbox_init(
        address _delegate,
        address _owner,
        address _autoPxEth,
        uint256 _maxSyncedIdBatch
    ) internal onlyInitializing {
        __ReentrancyGuard_init();
        __Pausable_init();
        __Ownable_init(_owner);
        __OAppCore_init(_delegate);
        __LiquidStakingTokenLockbox_init_unchained(
            _autoPxEth,
            _maxSyncedIdBatch
        );
    }

    function __LiquidStakingTokenLockbox_init_unchained(
        address _autoPxEth,
        uint256 _maxSyncedIdBatch
    ) internal {
        LockboxStorage storage $ = _getLockboxStorage();

        _setMaxSyncedIdBatch(_maxSyncedIdBatch);

        $.autoPxEth = IAutoPxEth(_autoPxEth);

        getTokenOut().approve(address($.autoPxEth), type(uint256).max);
    }

    /**
     * @notice Handler for processing layerzero messages from L2.
     * @dev    Only accept and handle the withdrawal message from L2, which then perform withdrawal from autoPxEth into pxEth.
     * @dev    _origin   Origin   The origin information containing the source endpoint and sender address.
     * @dev    _guid     bytes32  The unique identifier for the received LayerZero message.
     * @param  _message  bytes    The payload of the received message.
     * @dev              address  The address of the executor for the received message.
     * @dev              bytes    Additional arbitrary data provided by the corresponding executor.
     */
    function _lzReceive(
        Origin calldata _origin,
        bytes32 _guid,
        bytes calldata _message,
        address,
        bytes calldata
    ) internal override nonReentrant {
        _acceptNonce(_origin.srcEid, _origin.sender, _origin.nonce);

        LockboxStorage storage $ = _getLockboxStorage();

        uint256 _messageType = abi.decode(_message[:32], (uint256));

        if (_messageType == Constants.MESSAGE_TYPE_SYNC) {
            (address _token, uint256 _amountIn, uint256 _amountOut) = abi
                .decode(_message[32:], (address, uint256, uint256));

            uint256 amount = _anticipatedDeposit(
                _guid,
                _token,
                _amountIn,
                _amountOut
            );

            $.pendingDeposit += amount;

            return;
        }

        if (_messageType != Constants.MESSAGE_TYPE_WITHDRAW)
            revert Errors.NotAllowed();

        (uint256 _amount, address _receiver) = abi.decode(
            _message[32:],
            (uint256, address)
        );

        // Withdraw from pendingDeposit first
        uint256 pendingAmount = $.pendingDeposit;

        if (pendingAmount > 0) {
            if (pendingAmount >= _amount) {
                $.pendingDeposit -= _amount;

                getTokenOut().safeTransfer(_receiver, _amount);

                emit Withdrawal(_guid, _receiver, _amount);

                return;
            }

            getTokenOut().safeTransfer(_receiver, pendingAmount);

            $.pendingDeposit = 0;
        }

        // Adjust withdrawal amount based on the withdrawalPenalty
        // and the current assets in the vault
        uint256 postFeeAmount = _calculateWithdrawalAmount(
            _amount - pendingAmount
        );

        IAutoPxEth autoPxEth = $.autoPxEth;

        uint256 preBalance = autoPxEth.balanceOf(address(this));

        autoPxEth.withdraw(postFeeAmount, _receiver, address(this));

        $.totalShares -= preBalance - autoPxEth.balanceOf(address(this));

        emit Withdrawal(_guid, _receiver, pendingAmount + postFeeAmount);
    }

    /**
     * @notice Perform deposit via PirexEth and then relaying the message to L2.
     * @dev    Accept ETH deposits and then mint apxEth to be stored in the vault as well as sending message to L2.
     * @param  _receiver  address  The recipient of the deposit in L2.
     * @param  _refundAddress The address to receive any excess funds sent to layer zero.
     * @param  _amount    uint256  Deposit amount.
     * @param _shouldWrap bool     Whether to wrap rebase token on destination chain.
     * @param  _options   bytes    Additional options for the message.
     */
    function depositEth(
        address _receiver,
        address _refundAddress,
        uint256 _amount,
        bool _shouldWrap,
        bytes calldata _options
    ) external payable nonReentrant whenNotPaused {
        if (_receiver == address(0)) revert Errors.ZeroAddress();
        if (_refundAddress == address(0)) revert Errors.ZeroAddress();
        if (_amount == 0) revert Errors.ZeroAmount();
        // msg.value includes layerzero fees so the exact deposit amount must be specified
        if (msg.value <= _amount) revert Errors.InvalidAmount();

        LockboxStorage storage $ = _getLockboxStorage();

        IAutoPxEth autoPxEth = $.autoPxEth;

        uint256 preBalance = autoPxEth.balanceOf(address(this));

        // Deposit via PirexEth and receive apxEth in return to be kept in this vault
        (uint256 postFeeAmount, ) = IPirexEth(getPlatform()).deposit{
            value: _amount
        }(address(this), true);

        uint256 shares = autoPxEth.balanceOf(address(this)) - preBalance;

        $.totalShares += shares;

        uint256 assetsPerShare = autoPxEth.convertToAssets(1e18);

        _updateAverageAssetsPerShare(shares, assetsPerShare);

        _sendDeposit(
            postFeeAmount,
            assetsPerShare,
            msg.value - _amount,
            _receiver,
            _refundAddress,
            address(0),
            _shouldWrap,
            _options
        );
    }

    /**
     * @notice Perform deposit via AutoPxEth and then relaying the message to L2.
     * @dev    Accept pxEth deposits and then mint apxEth to be stored in the vault as well as sending message to L2.
     * @param  _receiver  address  The recipient of the deposit in L2.
     * @param  _refundAddress The address to receive any excess funds sent to layer zero.
     * @param  _amount    uint256  Deposit amount.
     * @param _shouldWrap bool     Whether to wrap rebase token on destination chain.
     * @param  _options   bytes    Additional options for the message.
     */
    function depositPxEth(
        address _receiver,
        address _refundAddress,
        uint256 _amount,
        bool _shouldWrap,
        bytes calldata _options
    ) external payable nonReentrant whenNotPaused {
        if (_receiver == address(0)) revert Errors.ZeroAddress();
        if (_refundAddress == address(0)) revert Errors.ZeroAddress();
        if (_amount == 0) revert Errors.ZeroAmount();

        LockboxStorage storage $ = _getLockboxStorage();

        IAutoPxEth autoPxEth = $.autoPxEth;
        IERC20 pxEth = getTokenOut();

        pxEth.safeTransferFrom(msg.sender, address(this), _amount);

        // Deposit via PirexEth and receive apxEth in return to be kept in this vault
        uint256 shares = autoPxEth.deposit(_amount, address(this));
        uint256 amount = autoPxEth.convertToAssets(shares);

        $.totalShares += shares;

        uint256 assetsPerShare = autoPxEth.convertToAssets(1e18);

        _updateAverageAssetsPerShare(shares, assetsPerShare);

        _sendDeposit(
            amount,
            assetsPerShare,
            msg.value,
            _receiver,
            _refundAddress,
            address(pxEth),
            _shouldWrap,
            _options
        );
    }

    /**
     * @notice Perform deposit and then relaying the message to L2.
     * @dev    Accept apxEth deposits to be stored in the vault as well as sending message to L2.
     * @param  _receiver  address  The recipient of the deposit in L2.
     * @param  _refundAddress The address to receive any excess funds sent to layer zero.
     * @param  _amount    uint256  Deposit amount (in shares).
     * @param  _options   bytes    Additional options for the message.
     */
    function depositApxEth(
        address _receiver,
        address _refundAddress,
        uint256 _amount,
        bool _shouldWrap,
        bytes calldata _options
    ) external payable nonReentrant whenNotPaused {
        if (_receiver == address(0)) revert Errors.ZeroAddress();
        if (_refundAddress == address(0)) revert Errors.ZeroAddress();
        if (_amount == 0) revert Errors.ZeroAmount();

        LockboxStorage storage $ = _getLockboxStorage();

        IAutoPxEth autoPxEth = $.autoPxEth;

        IERC20(address(autoPxEth)).safeTransferFrom(
            msg.sender,
            address(this),
            _amount
        );

        uint256 pxEthAmount = autoPxEth.convertToAssets(_amount);

        $.totalShares += _amount;

        uint256 assetsPerShare = autoPxEth.convertToAssets(1e18);

        _updateAverageAssetsPerShare(_amount, assetsPerShare);

        _sendDeposit(
            pxEthAmount,
            assetsPerShare,
            msg.value,
            _receiver,
            _refundAddress,
            address(autoPxEth),
            _shouldWrap,
            _options
        );
    }

    /**
     * @notice Perform rebase on L2
     * @dev    Calculate rebase rate based on latest assetsPerShare and accrue treasury fee.
     * @param  _refundAddress The address to receive any excess funds sent to layer zero.
     * @param  _options  bytes   Additional options for the message.
     */
    function rebase(
        address _refundAddress,
        bytes calldata _options
    ) external payable nonReentrant whenNotPaused {
        LockboxStorage storage $ = _getLockboxStorage();

        uint256 assetsPerShare = $.autoPxEth.convertToAssets(1e18);

        uint256 assetsIncrease = assetsPerShare - $.avgAssetsPerShare;

        if (assetsIncrease == 0) revert Errors.InvalidAmount();

        // amount increased by pxEth rewards accrued
        uint256 amount = assetsIncrease.mulDivDown($.totalShares, 1e18);

        if (amount == 0) revert Errors.InvalidAmount();

        bytes memory payload = abi.encode(
            Constants.MESSAGE_TYPE_REBASE,
            amount,
            assetsPerShare,
            address(0),
            _syncedIdsBatchUpdate()
        );

        bytes memory combinedOptions = combineOptions(L2_EID, 0, _options);

        $.avgAssetsPerShare = assetsPerShare;

        MessagingReceipt memory msgReceipt = _lzSend(
            L2_EID,
            payload,
            combinedOptions,
            MessagingFee(msg.value, 0),
            payable(_refundAddress)
        );

        emit Rebase(msgReceipt.guid, msg.sender, amount, assetsPerShare);
    }

    /**
     * @notice Perform deposit apxEth from the sync pool.
     * @dev     Accept apxEth deposits to be stored in the vault.
     * @param  _syncId          bytes32  The sync ID of the deposit.
     * @param  _amount          uint256  Deposit amount (in apxEth).
     */
    function _handleFinalizeDeposit(
        bytes32 _syncId,
        uint256 _amount
    ) internal override nonReentrant {
        LockboxStorage storage $ = _getLockboxStorage();

        if ($.pendingDeposit > 0) {
            IAutoPxEth autoPxEth = $.autoPxEth;

            uint256 amount = _amount > $.pendingDeposit
                ? $.pendingDeposit
                : _amount;

            $.pendingDeposit -= amount;

            uint256 shares = autoPxEth.deposit(amount, address(this));

            $.totalShares += shares;

            _updateAverageAssetsPerShare(
                shares,
                autoPxEth.convertToAssets(1e18)
            );

            $.syncedIds.push(_syncId);

            emit DepositSync(amount, true);
        }
    }

    /**
     * @notice Set the maximum number of synced Ids to be sent in a single message.
     * @param _maxSyncedIdBatch The maximum number of synced Ids to be sent in a single message.
     */
    function setMaxSyncedIdBatch(uint256 _maxSyncedIdBatch) external onlyOwner {
        _setMaxSyncedIdBatch(_maxSyncedIdBatch);
    }

    /**
     * @notice Set the maximum number of synced Ids to be sent in a single message.
     * @param _maxSyncedIdBatch The maximum number of synced Ids to be sent in a single message.
     */
    function _setMaxSyncedIdBatch(uint256 _maxSyncedIdBatch) internal {
        if (_maxSyncedIdBatch == 0) revert Errors.InvalidAmount();

        _getLockboxStorage().maxSyncedIdBatch = _maxSyncedIdBatch;
    }

    /**
     * @notice Set the last received nonce for the specified source endpoint and sender.
     * @dev this should be used to fix the nonce if there's a problem in the execution of a particular message.
     * @param _srcEid Source endpoint ID.
     * @param _sender Sender's address in bytes32 format.
     * @param _nonce The nonce to be set.
     */
    function setNonce(
        uint32 _srcEid,
        bytes32 _sender,
        uint64 _nonce
    ) external onlyOwner {
        _getLockboxStorage().receivedNonce[_srcEid][_sender] = _nonce;
    }

    /**
     * @dev Public function to get the next expected nonce for a given source endpoint and sender.
     * @param _srcEid Source endpoint ID.
     * @param _sender Sender's address in bytes32 format.
     * @return uint64 Next expected nonce.
     */
    function nextNonce(
        uint32 _srcEid,
        bytes32 _sender
    ) public view override returns (uint64) {
        return _getLockboxStorage().receivedNonce[_srcEid][_sender] + 1;
    }

    /**
     * @dev Internal function to accept nonce from the specified source endpoint and sender.
     * @param _srcEid Source endpoint ID.
     * @param _sender Sender's address in bytes32 format.
     * @param _nonce The nonce to be accepted.
     */
    function _acceptNonce(
        uint32 _srcEid,
        bytes32 _sender,
        uint64 _nonce
    ) internal {
        LockboxStorage storage $ = _getLockboxStorage();

        if (_nonce != $.receivedNonce[_srcEid][_sender] + 1)
            revert Errors.InvalidNonce();

        $.receivedNonce[_srcEid][_sender] += 1;
    }

    /**
     * @notice Internal function to set the canPause address.
     * @param _address the address to check if it can pause the contract.
     */
    function _canPause(address _address) internal view returns (bool) {
        return
            _getLockboxStorage().canPause[_address] ||
            _address == owner();
    }

    /**
     * @notice Function to set the canPause address.
     * @param _address the address to check if it can pause the contract.
     */
    function setCanPause(address _address, bool _allowed) external onlyOwner {
        _getLockboxStorage().canPause[_address] = _allowed;
    }

    /**
     * @notice Check if an address can pause the contract.
     * @param _address the address to check if it can pause the contract.
     */
    function canPause(address _address) external view returns (bool) {
        return _canPause(_address);
    }

    /**
     * @notice Pause deposit and rebase operations.
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @notice Unpause deposit and rebase operations.
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    /**
     * @notice Quote gas cost for deposit messages
     * @param  _receiver  address  The recipient of the deposit in L2.
     * @param  _amount    uint256  Deposit amount.
     * @param  _options   bytes    Additional options for the message.
     */
    function quoteDeposit(
        address _receiver,
        uint256 _amount,
        bytes calldata _options
    ) external view returns (MessagingFee memory msgFee) {
        LockboxStorage storage $ = _getLockboxStorage();

        bytes memory payload = abi.encode(
            Constants.MESSAGE_TYPE_DEPOSIT,
            _amount, // Use amount directly for quote
            $.autoPxEth.convertToAssets(1e18),
            _receiver,
            _syncedIdsBatch()
        );

        bytes memory combinedOptions = combineOptions(L2_EID, 0, _options);

        return _quote(L2_EID, payload, combinedOptions, false);
    }

    /**
     * @notice Quote gas cost for rebase message
     * @param  _options   bytes   Additional options for the message.
     */
    function quoteRebase(
        bytes calldata _options
    ) external view returns (MessagingFee memory msgFee) {
        LockboxStorage storage $ = _getLockboxStorage();

        bytes memory payload = abi.encode(
            Constants.MESSAGE_TYPE_REBASE,
            1e18, // Use 1e18 as placeholder for quote
            $.autoPxEth.convertToAssets(1e18),
            address(0),
            _syncedIdsBatch()
        );

        bytes memory combinedOptions = combineOptions(L2_EID, 0, _options);

        return _quote(L2_EID, payload, combinedOptions, false);
    }

    /**
     * @notice AutoPxEth contract address.
     */
    function getAutoPxEth() external view returns (address) {
        return address(_getLockboxStorage().autoPxEth);
    }

    /**
     * @notice The pending deposit amount.
     */
    function pendingDeposit() external view returns (uint256) {
        return _getLockboxStorage().pendingDeposit;
    }

    /**
     * @notice The average exchange rate between the share apxEth and pxEth, used for calculating the fee.
     */
    function averageAssetsPerShare() external view returns (uint256) {
        return _getLockboxStorage().avgAssetsPerShare;
    }

    /**
     * @notice The total shares in the vault.
     */
    function totalShares() external view returns (uint256) {
        return _getLockboxStorage().totalShares;
    }

    /**
     * @notice All finalized sync IDs.
     */
    function syncedIds() external view returns (bytes32[] memory) {
        return _getLockboxStorage().syncedIds;
    }

    /**
     * @notice All finalized sync Ids pending to be sent to L2.
     * @param  batchLimit  bool  Whether to limit the batch size.
     */
    function syncedIdsPending(
        bool batchLimit
    ) external view returns (bytes32[] memory) {
        LockboxStorage storage $ = _getLockboxStorage();

        uint256 firstSyncedIdIndex = $.firstSyncedIdIndex;
        uint256 syncedIdsLen = $.syncedIds.length - firstSyncedIdIndex;

        if (syncedIdsLen == 0) return new bytes32[](0);

        uint256 size = syncedIdsLen;
        if (batchLimit) {
            uint256 maxBatch = $.maxSyncedIdBatch;
            size = syncedIdsLen > maxBatch ? maxBatch : syncedIdsLen;
        }

        bytes32[] memory idsPending = new bytes32[](size);

        for (uint256 i; i < size; i++) {
            idsPending[i] = $.syncedIds[firstSyncedIdIndex + i];
        }

        return idsPending;
    }

    /**
     * @notice The maximum number of synced Ids to be sent in a single message.
     */
    function maxSyncedIdBatch() external view returns (uint256) {
        return _getLockboxStorage().maxSyncedIdBatch;
    }

    /**
     * @dev    Adjusts the withdrawal amount based on the withdrawalPenalty and the current assets in the vault.
     * @param  _amount uint256  The LiquidStakingToken amount to withdraw.
     * @return uint256 The amount to withdraw.
     */
    function _calculateWithdrawalAmount(
        uint256 _amount
    ) internal view returns (uint256) {
        LockboxStorage storage $ = _getLockboxStorage();

        IAutoPxEth autoPxEth = $.autoPxEth;

        uint256 withdrawalPenalty = autoPxEth.withdrawalPenalty();

        uint256 penalty = _amount.mulDivUp(
            withdrawalPenalty,
            Constants.FEE_DENOMINATOR
        );

        uint256 previewRedeem = _amount - penalty;

        uint256 totalAssets = autoPxEth.previewRedeem(
            autoPxEth.balanceOf(address(this))
        );

        return previewRedeem > totalAssets ? totalAssets : previewRedeem;
    }

    /**
     * @dev Update avgAssetsPerShare proportional to newly deposited assets.
     * @param  _newShares                uint256  The new shares to added.
     * @param  _currentAssetsPerShare    uint256  The current assetsPerShare in autoPxEth.
     */
    function _updateAverageAssetsPerShare(
        uint256 _newShares,
        uint256 _currentAssetsPerShare
    ) internal {
        LockboxStorage storage $ = _getLockboxStorage();

        uint256 sharesBalance = $.totalShares;
        uint256 preDepositShares = sharesBalance - _newShares;
        uint256 assetsPerShare = $.avgAssetsPerShare;

        $.avgAssetsPerShare =
            ((assetsPerShare * preDepositShares) +
                (_currentAssetsPerShare * _newShares)) /
            sharesBalance;
    }

    /**
     * @dev Internal function to send deposit message to L2.
     * @param  _amount          uint256  Deposit amount.
     * @param  _assetsPerShare  uint256  The assetsPerShare at the time of deposit.
     * @param  _nativeFee       uint256  The ETH fee to be paid for the message.
     * @param  _receiver        address  The recipient of the deposit in the L2.
     * @param  _refundAddress   address  The address to receive any excess funds sent to layer zero.
     * @param  _asset           address  The address of the asset being deposited.
     * @param  _options         bytes    Additional options for the message.
     */
    function _sendDeposit(
        uint256 _amount,
        uint256 _assetsPerShare,
        uint256 _nativeFee,
        address _receiver,
        address _refundAddress,
        address _asset,
        bool _shouldWrap,
        bytes calldata _options
    ) internal {
        bytes memory payload = abi.encode(
            _shouldWrap
                ? Constants.MESSAGE_TYPE_DEPOSIT_WRAP
                : Constants.MESSAGE_TYPE_DEPOSIT,
            _amount,
            _assetsPerShare,
            _receiver,
            _syncedIdsBatchUpdate()
        );

        MessagingReceipt memory msgReceipt = _lzSend(
            L2_EID,
            payload,
            combineOptions(L2_EID, 0, _options),
            MessagingFee(_nativeFee, 0),
            payable(_refundAddress)
        );

        emit Deposit(
            msgReceipt.guid,
            msg.sender,
            _receiver,
            _asset,
            _amount,
            _assetsPerShare
        );
    }

    /**
     * @dev Internal function to pay the native fee associated with the message.
     * @param _nativeFee The native fee to be paid.
     * @return nativeFee The amount of native currency paid.
     *
     * @dev This function is overridden to handle the native fee payment for the depositEth.
     */
    function _payNative(
        uint256 _nativeFee
    ) internal override returns (uint256 nativeFee) {
        if (msg.value < _nativeFee) revert NotEnoughNative(msg.value);
        return _nativeFee;
    }

    /**
     * @dev internal function to get the next batch of synced IDs to be sent to L2
     *      and update the sync queue.
     */
    function _syncedIdsBatchUpdate() internal returns (bytes32[] memory) {
        bytes32[] memory syncedIdsBatch = _syncedIdsBatch();

        _getLockboxStorage().firstSyncedIdIndex += syncedIdsBatch.length;

        return syncedIdsBatch;
    }

    /**
     * @dev internal function to get the next batch of synced IDs to be sent to L2.
     */
    function _syncedIdsBatch() internal view returns (bytes32[] memory) {
        LockboxStorage storage $ = _getLockboxStorage();

        // finalized synced ids not yet sent to L2
        uint256 firstSyncedIdIndex = $.firstSyncedIdIndex;
        uint256 syncedIdsLen = $.syncedIds.length - firstSyncedIdIndex;

        if (syncedIdsLen == 0) return new bytes32[](0);

        uint256 maxBatch = $.maxSyncedIdBatch;
        uint256 size = syncedIdsLen > maxBatch ? maxBatch : syncedIdsLen;

        bytes32[] memory syncedIdsBatch = new bytes32[](size);

        for (uint256 i; i < size; i++) {
            syncedIdsBatch[i] = $.syncedIds[firstSyncedIdIndex + i];
        }

        return syncedIdsBatch;
    }
}
