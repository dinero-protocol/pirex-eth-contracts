// SPDX-License-Identifier: LZBL-1.2
pragma solidity ^0.8.20;

interface IL1Receiver {
    function onMessageReceived(bytes calldata message) external payable;
}
