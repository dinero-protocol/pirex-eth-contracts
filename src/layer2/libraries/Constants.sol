// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

/**
 * @title  Constants
 * @notice Library containing various constants for the L2LiquidStakingToken system.
 * @author redactedcartel.finance
 */
library Constants {
    /**
     * @notice Message type constant for deposit.
     * @dev This constant defines the message type for deposit operations.
     */
    uint8 constant MESSAGE_TYPE_DEPOSIT = 1;

    /**
     * @notice Message type constant for deposit.
     * @dev This constant defines the message type for deposit operations.
     */
    uint8 constant MESSAGE_TYPE_DEPOSIT_WRAP = 2;

    /**
     * @notice Message type constant for withdrawal.
     * @dev This constant defines the message type for withdrawal operations.
     */
    uint8 constant MESSAGE_TYPE_WITHDRAW = 3;

    /**
     * @notice Message type constant for rebase.
     * @dev This constant defines the message type for rebase operations.
     */
    uint8 constant MESSAGE_TYPE_REBASE = 4;

    /**
     * @notice Message type constant for sync.
     * @dev This constant defines the message type for sync operations.
     */
    uint8 constant MESSAGE_TYPE_SYNC = 5;

    /**
     * @notice The destination endpoint ID for Mainnet.
     * @dev This constant holds the destination endpoint ID for Mainnet.
     */
    uint32 constant MAINNET_EID = 30101;

    /**
     * @notice Fee denominator for precise fee calculations.
     * @dev This constant holds the fee denominator for precise fee calculations.
     */
    uint256 constant FEE_DENOMINATOR = 1_000_000;

    /**
     * @notice Max rebase fee.
     * @dev This constant holds the maximum rebase fee that can be set.
     */
    uint256 constant MAX_REBASE_FEE = 200_000;

    /**
     * @notice Max deposit fee.
     * @dev This constant holds the maximum sync deposit fee that can be set.
     */
    uint256 constant MAX_DEPOSIT_FEE = 200_000;

    /**
     * @dev The address of the ETH token.
     */
    address constant ETH_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
}
