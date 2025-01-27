// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {MessagingReceipt} from "src/vendor/layerzero/protocol/interfaces/ILayerZeroEndpointV2.sol";

/**
 * @title ILiquidStakingToken.
 * @notice Interface for the LiquidStakingToken contract.
 * @author redactedcartel.finance
 */
interface ILiquidStakingToken {
    /**
     * @return the amount of shares that corresponds to `_assets` (pxEth).
     */
    function convertToShares(uint256 assets) external view returns (uint256);

    /**
     * @return the amount of assets that corresponds to `_shares` token shares.
     * @param floor if true, the result is rounded down, otherwise it's rounded up.
     */
    function convertToAssets(uint256 shares, bool floor) external view returns (uint256);

    /**
     * @notice Mint LiquidStakingToken tokens to the recipient.
     * @param _amount          uint256  The amount of LiquidStakingToken to mint.
     * @param _assetsPerShare uint256  The assets per share value.
     * @param _receiver        address  The recipient of the minted LiquidStakingToken.
     */
    function mint(
        address _receiver,
        uint256 _amount,
        uint256 _assetsPerShare
    ) external;

    /**
     * @notice transfer `_amount` LiquidStakingToken tokens from the sender to the recipient.
     * @param sender    address  The sender of the LiquidStakingToken tokens.
     * @param recipient address  The recipient of the LiquidStakingToken tokens.
     * @param amount    uint256  The amount of LiquidStakingToken tokens to transfer.
     */
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    /**
     * @notice transfer `_amount` LiquidStakingToken tokens from the sender to the recipient.
     * @param recipient address  The recipient of the LiquidStakingToken tokens.
     * @param amount    uint256  The amount of LiquidStakingToken tokens to transfer.
     */
    function transfer(
        address recipient,
        uint256 amount
    ) external returns (bool);

    /**
     * @notice Sync the unsynchronized pending deposit.
     * @dev    Only the Sync Pool contract can sync to signal a sync message sent to L1.
     * @param token         address token address on Layer 1
     * @param amountIn      uint256 Amount of tokens deposited on Layer 2
     * @param amountOut     uint256 Amount of tokens minted on Layer 2
     * @param refundAddress address The address to receive any excess fee values sent to the endpoint.
     * @param options      bytes Extra options for the messaging protocol
     * @return receipt Messaging receipt
     */
    function sync(
        address token,
        uint256 amountIn,
        uint256 amountOut,
        address refundAddress,
        bytes calldata options
    ) external payable returns (MessagingReceipt memory);

    /**
     * @dev Deposit tokens on Layer 2
     * This will mint tokenOut on Layer 2 using the exchange rate for tokenIn to tokenOut.
     * The amount deposited and minted will be stored in the token data which can be synced to Layer 1.
     * Will revert if:
     * - The amountIn is zero
     * - The token is unauthorized (that is, the l1Address is address(0))
     * - The amountOut is less than the minAmountOut
     * @param tokenIn Address of the token
     * @param amountIn Amount of tokens to deposit
     * @param minAmountOut Minimum amount of tokens to mint on Layer 2
     * @return amountOut Amount of tokens minted on Layer 2
     */
    function deposit(
        address tokenIn,
        uint256 amountIn,
        uint256 minAmountOut
    ) external payable returns (uint256 amountOut);

    /**
     * @notice Deposit tokens on Layer 2 and wrap them
     * This will mint tokenOut on Layer 2 using the exchange rate for tokenIn to tokenOut.
     * The amount deposited and minted will be stored in the token data which can be synced to Layer 1.
     * The minted tokens will be wrapped and sent to the sender.
     * @param tokenIn Address of the token
     * @param amountIn Amount of tokens to deposit
     * @param minAmountOut Minimum amount of tokens to mint on Layer 2
     * @return amountOut Amount of tokens minted on Layer 2
     */
    function depositAndWrap(
        address tokenIn,
        uint256 amountIn,
        uint256 minAmountOut
    ) external payable returns (uint256 amountOut);
}
