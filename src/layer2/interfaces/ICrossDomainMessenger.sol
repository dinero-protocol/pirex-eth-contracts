// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface ICrossDomainMessenger {
    function sendMessage(
        address _target,
        uint256 _value,
        bytes memory _message,
        uint32 _minGasLimit
    ) external payable;

    function xDomainMessageSender() external view returns (address);
}
