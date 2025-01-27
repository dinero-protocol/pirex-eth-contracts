// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IBridgeQuoter {
    function getAmountOut(
        address token,
        uint256 amountIn
    ) external view returns (uint256 amountSent, uint256 amountReceived);
}
