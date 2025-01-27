// SPDX-License-Identifier: MIT

pragma solidity 0.8.25;

/**
 * @title  IPirexEth
 * @notice Interface for the PirexEth contract
 * @dev    This interface defines the methods for interacting with PirexEth.
 * @author redactedcartel.finance
 */
interface IPirexEth {
    /**
     * @notice Handle pxETH minting in return for ETH deposits.
     * @dev    This function handles the minting of pxETH in return for ETH deposits.
     * @param  receiver        address  Receiver of the minted pxETH or apxEth
     * @param  shouldCompound  bool     Whether to also compound into the vault
     * @return postFeeAmount   uint256  pxETH minted for the receiver
     * @return feeAmount       uint256  pxETH distributed as fees
     */
    function deposit(
        address receiver,
        bool shouldCompound
    ) external payable returns (uint256 postFeeAmount, uint256 feeAmount);
}
