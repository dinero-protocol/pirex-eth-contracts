// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

library Errors {
    /**
     * @dev Zero address specified
     */
    error ZeroAddress();

    /**
     * @dev Zero amount specified
     */
    error ZeroAmount();

    /**
     * @dev Invalid fee specified
     */
    error InvalidFee();

    /**
     * @dev not same as deposit size
     */
    error InvalidAmount();

    /**
     * @dev Invalid nonce
     */
    error InvalidNonce();

    /**
     * @dev not allowed
     */
    error NotAllowed();

    /**
     * @dev Only ETH allowed
     */
    error OnlyETH();

    /**
     * @dev Invalid rate
     */
    error InvalidRate();

    /**
     * @dev Withdraw limit exceeded
     */
    error WithdrawLimitExceeded();

    /**
     * @dev Unauthorized caller on SyncPool
     */
    error UnauthorizedCaller();

    /**
     * @dev Native transfer failed on SyncPool
     */
    error NativeTransferFailed();

    /**
     * @dev Insufficient amount out
     */
    error InsufficientAmountOut();
    
    /**
     * @dev Insufficient amount to sync
     */
    error InsufficientAmountToSync();
    
    /**
     * @dev Unauthorized token
     */
    error UnauthorizedToken();

    /**
     * @dev Invalid amount in
     */
    error InvalidAmountIn();

    /**
     * @dev Max sync amount exceeded, to prevent going over the bridge limit
     */
    error MaxSyncAmountExceeded();

    /**
     * @dev Unsupported destination chain
     */
    error UnsupportedEid();

    /**
     * @dev Multichain eposits can't be wrapped
     */
    error MultichainDepositsCannotBeWrapped();
}
