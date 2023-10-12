// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {Errors} from "./libraries/Errors.sol";
import {DataTypes} from "./libraries/DataTypes.sol";
import {IPirexFees} from "./interfaces/IPirexFees.sol";
import {PirexEthValidators} from "./PirexEthValidators.sol";

/// @title  Main contract for handling interactions with pxETH
/// @author redactedcartel.finance
contract PirexEth is PirexEthValidators {
    using SafeTransferLib for ERC20;

    // Pirex fee repository and distribution contract
    IPirexFees public immutable pirexFees;

    // Maximum Fees (e.g. 200000 / 1000000 = 20%)
    mapping(DataTypes.Fees => uint32) public maxFees;

    // Fees (e.g. 5000 / 1000000 = 0.5%)
    mapping(DataTypes.Fees => uint32) public fees;

    // Contract paused state
    uint256 public paused;

    // Events
    event Deposit(
        address indexed caller,
        address indexed receiver,
        bool indexed shouldCompound,
        uint256 deposited,
        uint256 receivedAmount,
        uint256 feeAmount
    );
    event InitiateRedemption(
        uint256 assets,
        uint256 postFeeAmount,
        address indexed receiver
    );
    event RedeemWithUpxEth(
        uint256 tokenId,
        uint256 assets,
        address indexed receiver
    );
    event RedeemWithPxEth(
        uint256 assets,
        uint256 postFeeAmount,
        address indexed _receiver
    );
    event SetFee(DataTypes.Fees indexed f, uint32 fee);
    event SetMaxFee(DataTypes.Fees indexed f, uint32 maxFee);
    event SetPauseState(address account, uint256 state);
    event EmergencyWithdrawal(
        address indexed receiver,
        address indexed token,
        uint256 amount
    );

    // Modifiers
    modifier whenNotPaused() {
        if (paused == _PAUSED) revert Errors.Paused();
        _;
    }

    /**
        @param  _pxEth                     address  PxETH contract address
        @param  _admin                     address  Admin address
        @param  _beaconChainDepositContract  address  The address of the beacon chain deposit contract
        @param  _upxEth                    address  UpxETH address
        @param  _depositSize               uint256  Amount of eth to stake
        @param  _preDepositAmount          uint256  Amount of ETH for pre-deposit
        @param  _pirexFees                 address  PirexFees contract address
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
        address _pirexFees,
        uint48 _initialDelay
    )
        PirexEthValidators(
            _pxEth,
            _admin,
            _beaconChainDepositContract,
            _upxEth,
            _depositSize,
            _preDepositAmount,
            _initialDelay
        )
    {
        if (_pirexFees == address(0)) revert Errors.ZeroAddress();

        pirexFees = IPirexFees(_pirexFees);
        maxFees[DataTypes.Fees.Deposit] = 200_000;
        maxFees[DataTypes.Fees.Redemption] = 200_000;
        maxFees[DataTypes.Fees.InstantRedemption] = 200_000;
        paused = _NOT_PAUSED;
    }

    /*//////////////////////////////////////////////////////////////
                            MUTATIVE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /** 
        @notice Set fee
        @param  f    enum    Fee
        @param  fee  uint32  Fee amount
     */
    function setFee(
        DataTypes.Fees f,
        uint32 fee
    ) external onlyRole(GOVERNANCE_ROLE) {
        if (fee > maxFees[f]) revert Errors.InvalidFee();

        fees[f] = fee;

        emit SetFee(f, fee);
    }

    /** 
        @notice Set Max fee
        @param  f       enum    Fee
        @param  maxFee  uint32  Max fee amount
     */
    function setMaxFee(
        DataTypes.Fees f,
        uint32 maxFee
    ) external onlyRole(GOVERNANCE_ROLE) {
        if (maxFee < fees[f]) revert Errors.InvalidMaxFee();

        maxFees[f] = maxFee;

        emit SetMaxFee(f, maxFee);
    }

    /** 
        @notice toggle the contract's pause state
    */
    function togglePauseState() external onlyRole(GOVERNANCE_ROLE) {
        paused = paused == _PAUSED ? _NOT_PAUSED : _PAUSED;

        emit SetPauseState(msg.sender, paused);
    }

    /**
        @notice Emergency withdrawal for all ERC20 tokens (except pxETH) and ETH
        @dev    This function should only be called under major emergency
        @param  receiver  address  Receiver address
        @param  token     address  Token address
        @param  amount    uint256  Token amount
     */
    function emergencyWithdraw(
        address receiver,
        address token,
        uint256 amount
    ) external onlyRole(GOVERNANCE_ROLE) onlyWhenDepositEtherPaused {
        if (paused == _NOT_PAUSED) revert Errors.NotPaused();
        if (receiver == address(0)) revert Errors.ZeroAddress();
        if (amount == 0) revert Errors.ZeroAmount();
        if (token == address(pxEth)) revert Errors.InvalidToken();

        if (token == address(0)) {
            // Handle ETH withdrawal
            (bool _success, ) = payable(receiver).call{value: amount}("");
            assert(_success);
        } else {
            ERC20(token).safeTransfer(receiver, amount);
        }

        emit EmergencyWithdrawal(receiver, token, amount);
    }

    /**
        @notice Handle pxETH minting in return for ETH deposits
        @param  receiver         address  Receiver of the minted pxETH or apxEth
        @param  shouldCompound   bool     Whether to also compound into the vault
        @return postFeeAmount    uint256  pxETH minted for the receiver
        @return feeAmount        uint256  pxETH distributed as fees
    */
    function deposit(
        address receiver,
        bool shouldCompound
    )
        external
        payable
        whenNotPaused
        nonReentrant
        returns (uint256 postFeeAmount, uint256 feeAmount)
    {
        if (msg.value == 0) revert Errors.ZeroAmount();
        if (receiver == address(0)) revert Errors.ZeroAddress();

        // Get the pxETH amounts for the receiver and the protocol (fees)
        (postFeeAmount, feeAmount) = _computeAssetAmounts(
            DataTypes.Fees.Deposit,
            msg.value
        );

        // Mint pxETH for the receiver (or this contract if compounding) excluding fees
        _mintPxEth(shouldCompound ? address(this) : receiver, postFeeAmount);

        if (shouldCompound) {
            // Deposit pxETH excluding fees into the autocompounding vault
            // then mint shares (apxETH) for the user
            autoPxEth.deposit(postFeeAmount, receiver);
        }

        // Mint pxETH for fee distribution contract
        if (feeAmount != 0) {
            _mintPxEth(address(pirexFees), feeAmount);
        }

        // Redirect the deposit to beacon chain deposit contract
        _addPendingDeposit(msg.value);

        emit Deposit(
            msg.sender,
            receiver,
            shouldCompound,
            msg.value,
            postFeeAmount,
            feeAmount
        );
    }

    /**
        @notice Initiate redemption by burning pxETH in return for upxETH
        @param  _assets                      uint256  If caller is AutoPxEth then apxETH; pxETH otherwise
        @param  _receiver                    address  Receiver for upxETH
        @param  _shouldTriggerValidatorExit  bool     Whether the initiation should trigger voluntary exit     
        @return postFeeAmount                uint256  pxETH burnt for the receiver
        @return feeAmount                    uint256  pxETH distributed as fees
    */
    function initiateRedemption(
        uint256 _assets,
        address _receiver,
        bool _shouldTriggerValidatorExit
    )
        external
        override
        whenNotPaused
        nonReentrant
        returns (uint256 postFeeAmount, uint256 feeAmount)
    {
        if (_assets == 0) revert Errors.ZeroAmount();
        if (_receiver == address(0)) revert Errors.ZeroAddress();

        uint256 _pxEthAmount;

        if (msg.sender == address(autoPxEth)) {
            // The pxETH amount is calculated as per apxETH-ETH ratio during current block
            _pxEthAmount = autoPxEth.redeem(
                _assets,
                address(this),
                address(this)
            );
        } else {
            _pxEthAmount = _assets;
        }

        // Get the pxETH amounts for the receiver and the protocol (fees)
        (postFeeAmount, feeAmount) = _computeAssetAmounts(
            DataTypes.Fees.Redemption,
            _pxEthAmount
        );

        uint256 _requiredValidators = (pendingWithdrawal + postFeeAmount) /
            DEPOSIT_SIZE;

        if (_shouldTriggerValidatorExit && _requiredValidators == 0)
            revert Errors.NoValidatorExit();

        if (_requiredValidators > getStakingValidatorCount())
            revert Errors.NotEnoughValidators();

        emit InitiateRedemption(_pxEthAmount, postFeeAmount, _receiver);

        address _owner = msg.sender == address(autoPxEth)
            ? address(this)
            : msg.sender;

        _burnPxEth(_owner, postFeeAmount);

        if (feeAmount != 0) {
            // Allow PirexFees to distribute fees directly from sender
            pxEth.operatorApprove(_owner, address(pirexFees), feeAmount);

            // Distribute fees
            pirexFees.distributeFees(_owner, address(pxEth), feeAmount);
        }

        _initiateRedemption(
            postFeeAmount,
            _receiver,
            _shouldTriggerValidatorExit
        );
    }

    /**
        @notice Redeem back ETH using upxEth
        @param  _tokenId  uint256  Redeem batch identifier
        @param  _assets   uint256  Amount of ETH to redeem
        @param _receiver  address  Address of the ETH receiver
     */
    function redeemWithUpxEth(
        uint256 _tokenId,
        uint256 _assets,
        address _receiver
    ) external whenNotPaused nonReentrant {
        if (_assets == 0) revert Errors.ZeroAmount();
        if (_receiver == address(0)) revert Errors.ZeroAddress();

        DataTypes.ValidatorStatus _validatorStatus = status[
            batchIdToValidator[_tokenId]
        ];

        if (
            _validatorStatus != DataTypes.ValidatorStatus.Dissolved &&
            _validatorStatus != DataTypes.ValidatorStatus.Slashed
        ) {
            revert Errors.StatusNotDissolvedOrSlashed();
        }

        if (outstandingRedemptions < _assets) revert Errors.NotEnoughETH();

        outstandingRedemptions -= _assets;
        upxEth.burn(msg.sender, _tokenId, _assets);

        (bool _success, ) = payable(_receiver).call{value: _assets}("");
        assert(_success);

        emit RedeemWithUpxEth(_tokenId, _assets, _receiver);
    }

    /**
        @notice Instant redeem back ETH using pxETH  
        @param  _assets        uint256  Amount of pxETH to redeem
        @param  _receiver      address  Address of the ETH receiver 
        @return postFeeAmount  uint256  Post-fee amount for the receiver
        @return feeAmount      uint256  Fee amount sent to the PirexFees
     */
    function instantRedeemWithPxEth(
        uint256 _assets,
        address _receiver
    )
        external
        whenNotPaused
        nonReentrant
        returns (uint256 postFeeAmount, uint256 feeAmount)
    {
        if (_assets == 0) revert Errors.ZeroAmount();
        if (_receiver == address(0)) revert Errors.ZeroAddress();

        // Get the pxETH amounts for the receiver and the protocol (fees)
        (postFeeAmount, feeAmount) = _computeAssetAmounts(
            DataTypes.Fees.InstantRedemption,
            _assets
        );

        if (postFeeAmount > buffer) revert Errors.NotEnoughBuffer();

        if (feeAmount != 0) {
            // Allow PirexFees to distribute fees directly from sender
            pxEth.operatorApprove(msg.sender, address(pirexFees), feeAmount);

            // Distribute fees
            pirexFees.distributeFees(msg.sender, address(pxEth), feeAmount);
        }

        _burnPxEth(msg.sender, postFeeAmount);
        buffer -= postFeeAmount;

        (bool _success, ) = payable(_receiver).call{value: postFeeAmount}("");
        assert(_success);

        emit RedeemWithPxEth(_assets, postFeeAmount, _receiver);
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
        @notice Compute post-fee asset and fee amounts from a fee type and total assets
        @param  f              enum     Fee
        @param  assets         uint256  ETH or pxETH asset amount
        @return postFeeAmount  uint256  Post-fee asset amount (for mint/burn/claim/etc.)
        @return feeAmount      uint256  Fee amount
     */
    function _computeAssetAmounts(
        DataTypes.Fees f,
        uint256 assets
    ) internal view returns (uint256 postFeeAmount, uint256 feeAmount) {
        feeAmount = (assets * fees[f]) / DENOMINATOR;
        postFeeAmount = assets - feeAmount;

        assert(feeAmount + postFeeAmount == assets);
    }
}
