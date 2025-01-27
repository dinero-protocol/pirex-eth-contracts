// SPDX-License-Identifier: LZBL-1.2
pragma solidity ^0.8.20;

import {L1BaseReceiverUpgradeable} from "../L1BaseReceiverUpgradeable.sol";
import {ICrossDomainMessenger} from "../../interfaces/ICrossDomainMessenger.sol";
import {Constants} from "../../libraries/Constants.sol";

/**
 * @title L1 Mode Receiver ETH
 * @notice L1 receiver contract for ETH
 * @dev This contract receives messages from the L2 messenger and forwards them to the L1 sync pool
 * It only supports ETH
 */
contract L1ModeReceiverETHUpgradeable is L1BaseReceiverUpgradeable {
    error L1ModeReceiverETH__OnlyETH();

    /**
     * @dev Initializer for L1 Mode Receiver ETH
     * @param l1SyncPool Address of the L1 sync pool
     * @param messenger Address of the messenger contract
     * @param owner Address of the owner
     */
    function initialize(address l1SyncPool, address messenger, address owner) external initializer {
        __Ownable_init(owner);
        __L1BaseReceiver_init(l1SyncPool, messenger);
    }

    /**
     * @dev Function to receive messages from the L2 messenger
     * @param message The message received from the L2 messenger
     */
    function onMessageReceived(bytes calldata message) external payable virtual override {
        (uint32 originEid, bytes32 guid, address tokenIn, uint256 amountIn, uint256 amountOut) =
            abi.decode(message, (uint32, bytes32, address, uint256, uint256));

        if (tokenIn != Constants.ETH_ADDRESS) revert L1ModeReceiverETH__OnlyETH();

        address sender = ICrossDomainMessenger(getMessenger()).xDomainMessageSender();

        _forwardToL1SyncPool(
            originEid, bytes32(uint256(uint160(sender))), guid, tokenIn, amountIn, amountOut, msg.value
        );
    }
}
