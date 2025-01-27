// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

interface IL2BaseToken {
    function withdrawWithMessage(
        address _l1Receiver,
        bytes calldata _additionalData
    ) external payable;
}