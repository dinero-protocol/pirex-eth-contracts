// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {MessagingFee, MessagingReceipt} from "src/vendor/layerzero-upgradeable/oapp/OAppSenderUpgradeable.sol";
import {Constants} from "../libraries/Constants.sol";
import {Errors} from "../libraries/Errors.sol";
import {IRateLimiter} from "src/vendor/layerzero/syncpools/interfaces/IRateLimiter.sol";
import {LiquidStakingToken} from "../LiquidStakingToken.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {IL1Receiver} from "src/vendor/layerzero/syncpools/interfaces/IL1Receiver.sol";
import {IArbitrumMessenger} from "../interfaces/IArbitrumMessenger.sol";

/**
 * @title  LiquidStakingTokenOrbit
 * @notice An LiquidStakingToken OApp contract using non native bridges for syncing L3 deposits.
 * @dev    This contract facilitates interactions between mainnet PirexEth contracts and the Orbit system.
 * @author redactedcartel.finance
 */
contract LiquidStakingTokenOrbit is LiquidStakingToken {
    /**
     * @dev Library: SafeERC20 - Provides safe transfer functions for ERC20 tokens.
     */
    using SafeERC20 for IERC20;

    /**
     * @notice The endpoint ID for L2.
     * @dev This constant defines the source endpoint ID for the L2.
     */
    uint32 internal immutable L2_EID;

    /**
     * @notice Contract constructor to initialize LiquidStakingTokenVault with necessary parameters and configurations.
     * @dev    This constructor sets up the LiquidStakingTokenVault contract, configuring key parameters and initializing state variables.
     * @param  _endpoint   address  The address of the LOCAL LayerZero endpoint.
     * @param  _srcEid     uint32   The source endpoint ID.
     * @param  _arbEid      uint32   The arbitrum endpoint ID.
     */
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(
        address _endpoint,
        uint32 _srcEid,
        uint32 _arbEid
    ) LiquidStakingToken(_endpoint, _srcEid) {
        L2_EID = _arbEid;
    }

    /**
     * @dev Internal function to sync tokens to L1
     * This will send an additional message to the messenger contract after the LZ message
     * This message will contain the ETH that the LZ message anticipates to receive
     * @param _l2TokenIn Address of the token on Layer 2
     * @param _amountIn Amount of tokens deposited on Layer 2
     * @param _amountOut Amount of tokens minted on Layer 2
     * @param _extraOptions Extra options for the messaging protocol
     * @return receipt Messaging receipt
     */
    function _sync(
        address _l2TokenIn,
        address _l1TokenIn,
        uint256 _amountIn,
        uint256 _amountOut,
        bytes calldata _extraOptions,
        MessagingFee calldata
    )
        internal
        override
        nonReentrant
        whenNotPaused
        returns (MessagingReceipt memory)
    {
        bytes memory _payload = abi.encode(
            Constants.MESSAGE_TYPE_SYNC,
            _l2TokenIn,
            _amountIn,
            _amountOut
        );

        bytes memory _combinedOptions = combineOptions(
            L1_EID,
            0,
            _extraOptions
        );

        MessagingFee memory l1MsgFee = _quote(
            L1_EID,
            _payload,
            _combinedOptions,
            false
        );

        // send fast sync message
        MessagingReceipt memory receipt = _lzSend(
            L1_EID,
            _payload,
            _combinedOptions,
            MessagingFee(l1MsgFee.nativeFee, 0),
            payable(msg.sender)
        );

        _addToSyncQueue(receipt);

        uint256 l2MsgFee = msg.value - l1MsgFee.nativeFee;
        _lzSend(
            L2_EID,
            abi.encode(L2_EID, receipt.guid, _l1TokenIn, _amountIn, _amountOut),
            combineOptions(L2_EID, 0, _extraOptions),
            MessagingFee(l2MsgFee, 0),
            payable(msg.sender)
        );

        IArbitrumMessenger(getMessenger()).outboundTransfer(
            _l1TokenIn,
            getReceiver(),
            _amountIn,
            ""
        );

        L2TokenStorage storage $ = _getLiquidStakingTokenStorage();

        IRateLimiter(getRateLimiter()).updateRateLimit(
            address(this),
            Constants.ETH_ADDRESS,
            $.unsyncedShares,
            0
        );
        $.unsyncedShares = 0;

        return receipt;
    }

    function _sendSlowSyncMessage(
        address,
        uint256,
        uint256,
        bytes memory
    ) internal pure override {
        revert("Not implemented");
    }

    /**
     * @dev Quote the messaging fee for a sync
     * @param  _tokenIn  address  Address of the input token
     * @param  _options   bytes    Additional options for the message.
     */
    function quoteSync(
        address _tokenIn,
        bytes calldata _options
    ) external view override returns (MessagingFee memory msgFee) {
        Token storage token = _getL2SyncPoolStorage().tokens[_tokenIn];

        bytes memory _l1Payload = abi.encode(
            Constants.MESSAGE_TYPE_SYNC,
            _tokenIn,
            token.unsyncedAmountIn,
            token.unsyncedAmountOut
        );

        bytes memory _l1CombinedOptions = combineOptions(L1_EID, 0, _options);

        bytes memory _l2Payload = abi.encode(
            endpoint.eid(),
            bytes32("sync"),
            _tokenIn,
            1e18,
            1e18
        );

        bytes memory _l2CombinedOptions = combineOptions(L2_EID, 0, _options);

        msgFee = _quote(L1_EID, _l1Payload, _l1CombinedOptions, false);

        msgFee.nativeFee += _quote(
            L2_EID,
            _l2Payload,
            _l2CombinedOptions,
            false
        ).nativeFee;

        return msgFee;
    }

    /**
     * @dev Internal function to pay the native fee associated with the message.
     * @param _nativeFee The native fee to be paid.
     * @return nativeFee The amount of native currency paid.
     *
     * @dev This function is overridden to handle the native fee payment for multiple layerzero txs.
     */
    function _payNative(
        uint256 _nativeFee
    ) internal override returns (uint256 nativeFee) {
        if (msg.value < _nativeFee) revert NotEnoughNative(msg.value);
        return _nativeFee;
    }
}
