// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface ICrossDomainMessengerMorph {
    function sendMessage(
        address _target,
        uint256 _value,
        bytes calldata _message,
        uint256 _minGasLimit
    ) external payable;

    function xDomainMessageSender() external view returns (address);
}
