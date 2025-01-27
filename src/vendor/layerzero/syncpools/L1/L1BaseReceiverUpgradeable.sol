// SPDX-License-Identifier: LZBL-1.2
pragma solidity ^0.8.20;

import {OwnableUpgradeable} from "openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";

import {BaseMessengerUpgradeable} from "../utils/BaseMessengerUpgradeable.sol";
import {IL1SyncPool} from "../interfaces/IL1SyncPool.sol";
import {IL1Receiver} from "../interfaces/IL1Receiver.sol";

/**
 * @title L1 Base Receiver
 * @notice Base contract for L1 receivers
 * This contract is intended to receive messages from the native L2 bridge, decode the message
 * and then forward it to the L1 sync pool.
 */
abstract contract L1BaseReceiverUpgradeable is OwnableUpgradeable, BaseMessengerUpgradeable, IL1Receiver {
    struct L1BaseReceiverStorage {
        IL1SyncPool l1SyncPool;
    }

    // keccak256(abi.encode(uint256(keccak256(l1basereceiver.storage.l1syncpool)) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant L1BaseReceiverStorageLocation =
        0xec90cfc37697dc33dbcf188d524bdc2a41f251df5a390991a45d6388ac04b500;

    function _getL1BaseReceiverStorage() internal pure returns (L1BaseReceiverStorage storage $) {
        assembly {
            $.slot := L1BaseReceiverStorageLocation
        }
    }

    error L1BaseReceiver__UnauthorizedCaller();
    error L1BaseReceiver__UnauthorizedL2Sender();

    event L1SyncPoolSet(address l1SyncPool);

    function __L1BaseReceiver_init(address l1SyncPool, address messenger) internal onlyInitializing {
        __BaseMessenger_init(messenger);
        __L1BaseReceiver_init_unchained(l1SyncPool);
    }

    function __L1BaseReceiver_init_unchained(address l1SyncPool) internal onlyInitializing {
        _setL1SyncPool(l1SyncPool);
    }

    /**
     * @dev Get the L1 sync pool address
     * @return The L1 sync pool address
     */
    function getL1SyncPool() public view virtual returns (address) {
        L1BaseReceiverStorage storage $ = _getL1BaseReceiverStorage();
        return address($.l1SyncPool);
    }

    /**
     * @dev Set the L1 sync pool address
     * @param l1SyncPool The L1 sync pool address
     */
    function setL1SyncPool(address l1SyncPool) public virtual onlyOwner {
        _setL1SyncPool(l1SyncPool);
    }

    /**
     * @dev Internal function to set the L1 sync pool address
     * @param l1SyncPool The L1 sync pool address
     */
    function _setL1SyncPool(address l1SyncPool) internal virtual {
        L1BaseReceiverStorage storage $ = _getL1BaseReceiverStorage();
        $.l1SyncPool = IL1SyncPool(l1SyncPool);

        emit L1SyncPoolSet(l1SyncPool);
    }

    /**
     * @dev Internal function to forward the message to the L1 sync pool
     * @param originEid Origin endpoint ID
     * @param sender Sender address
     * @param guid Message GUID
     * @param tokenIn Token address
     * @param amountIn Amount of tokens
     * @param amountOut Amount of tokens
     * @param valueToL1SyncPool Value to send to the L1 sync pool
     */
    function _forwardToL1SyncPool(
        uint32 originEid,
        bytes32 sender,
        bytes32 guid,
        address tokenIn,
        uint256 amountIn,
        uint256 amountOut,
        uint256 valueToL1SyncPool
    ) internal virtual {
        if (msg.sender != getMessenger()) revert L1BaseReceiver__UnauthorizedCaller();
        if (_getAuthorizedL2Address(originEid) != sender) revert L1BaseReceiver__UnauthorizedL2Sender();

        L1BaseReceiverStorage storage $ = _getL1BaseReceiverStorage();
        $.l1SyncPool.onMessageReceived{value: valueToL1SyncPool}(originEid, guid, tokenIn, amountIn, amountOut);
    }

    /**
     * @dev Internal function to get the authorized L2 address
     * @param originEid Origin endpoint ID
     * @return The authorized L2 address
     */
    function _getAuthorizedL2Address(uint32 originEid) internal view virtual returns (bytes32) {
        L1BaseReceiverStorage storage $ = _getL1BaseReceiverStorage();
        return $.l1SyncPool.peers(originEid);
    }
}
