// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

interface IOutbox {
    /**
     * @notice When l2ToL1Sender returns a nonzero address, the message was originated by an L2 account
     *         When the return value is zero, that means this is a system message
     * @dev the l2ToL1Sender behaves as the tx.origin, the msg.sender should be validated to protect against reentrancies
     */
    function l2ToL1Sender() external view returns (address);
}