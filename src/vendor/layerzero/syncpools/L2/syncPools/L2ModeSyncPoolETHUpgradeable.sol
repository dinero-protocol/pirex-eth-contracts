// SPDX-License-Identifier: LZBL-1.2
pragma solidity ^0.8.20;

import {
    MessagingFee,
    MessagingReceipt
} from "src/vendor/layerzero/protocol/interfaces/ILayerZeroEndpointV2.sol";

import {BaseMessengerUpgradeable} from "../../utils/BaseMessengerUpgradeable.sol";
import {BaseReceiverUpgradeable} from "../../utils/BaseReceiverUpgradeable.sol";
import {L2BaseSyncPoolUpgradeable} from "../L2BaseSyncPoolUpgradeable.sol";
import {ICrossDomainMessenger} from "../../interfaces/ICrossDomainMessenger.sol";
import {Constants} from "../../libraries/Constants.sol";
import {IL1Receiver} from "../../interfaces/IL1Receiver.sol";

/**
 * @title L2 Mode Sync Pool for ETH
 * @dev A sync pool that only supports ETH on Mode L2
 * This contract allows to send ETH from L2 to L1 during the sync process
 */
contract L2ModeSyncPoolETHUpgradeable is
    L2BaseSyncPoolUpgradeable,
    BaseMessengerUpgradeable,
    BaseReceiverUpgradeable
{
    error L2ModeSyncPoolETH__OnlyETH();

    /**
     * @dev Constructor for L2 Mode Sync Pool for ETH
     * @param endpoint Address of the LayerZero endpoint
     */
    constructor(address endpoint) L2BaseSyncPoolUpgradeable(endpoint) {}

    /**
     * @dev Initialize the contract
     * @param l2ExchangeRateProvider Address of the exchange rate provider
     * @param rateLimiter Address of the rate limiter
     * @param tokenOut Address of the token to mint on Layer 2
     * @param dstEid Destination endpoint ID (most of the time, the Layer 1 endpoint ID)
     * @param messenger Address of the messenger contract (most of the time, the L2 native bridge address)
     * @param receiver Address of the receiver contract (most of the time, the L1 receiver contract)
     * @param delegate Address of the owner
     */
    function initialize(
        address l2ExchangeRateProvider,
        address rateLimiter,
        address tokenOut,
        uint32 dstEid,
        address messenger,
        address receiver,
        address delegate
    ) external initializer {
        __L2BaseSyncPool_init(l2ExchangeRateProvider, rateLimiter, tokenOut, dstEid, delegate);
        __BaseMessenger_init(messenger);
        __BaseReceiver_init(receiver);
        __Ownable_init(delegate);
    }

    /**
     * @dev Only allows ETH to be received
     * @param tokenIn The token address
     * @param amountIn The amount of tokens
     */
    function _receiveTokenIn(address tokenIn, uint256 amountIn) internal virtual override {
        if (tokenIn != Constants.ETH_ADDRESS) revert L2ModeSyncPoolETH__OnlyETH();

        super._receiveTokenIn(tokenIn, amountIn);
    }

    /**
     * @dev Internal function to sync tokens to L1
     * This will send an additional message to the messenger contract after the LZ message
     * This message will contain the ETH that the LZ message anticipates to receive
     * @param dstEid Destination endpoint ID
     * @param l1TokenIn Address of the token on Layer 1
     * @param amountIn Amount of tokens deposited on Layer 2
     * @param amountOut Amount of tokens minted on Layer 2
     * @param extraOptions Extra options for the messaging protocol
     * @param fee Messaging fee
     * @return receipt Messaging receipt
     */
    function _sync(
        uint32 dstEid,
        address l2TokenIn,
        address l1TokenIn,
        uint256 amountIn,
        uint256 amountOut,
        bytes calldata extraOptions,
        MessagingFee calldata fee
    ) internal virtual override returns (MessagingReceipt memory) {
        if (l1TokenIn != Constants.ETH_ADDRESS || l2TokenIn != Constants.ETH_ADDRESS) {
            revert L2ModeSyncPoolETH__OnlyETH();
        }

        address receiver = getReceiver();
        address messenger = getMessenger();

        uint32 originEid = endpoint.eid();

        MessagingReceipt memory receipt =
            super._sync(dstEid, l2TokenIn, l1TokenIn, amountIn, amountOut, extraOptions, fee);

        bytes memory data = abi.encode(originEid, receipt.guid, l1TokenIn, amountIn, amountOut);
        bytes memory message = abi.encodeCall(IL1Receiver.onMessageReceived, data);

        ICrossDomainMessenger(messenger).sendMessage{value: amountIn}(receiver, message, _minGasLimit());

        return receipt;
    }

    /**
     * @dev Internal function to get the minimum gas limit
     * This function should be overridden to set a minimum gas limit to forward during the execution of the message
     * by the L1 receiver contract. This is mostly needed if the underlying contract have some try/catch mechanism
     * as this could be abused by gas-griefing attacks.
     * @return minGasLimit Minimum gas limit
     */
    function _minGasLimit() internal view virtual returns (uint32) {
        return 0;
    }
}
