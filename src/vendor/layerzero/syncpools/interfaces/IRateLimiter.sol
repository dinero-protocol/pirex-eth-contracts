// SPDX-License-Identifier: LZBL-1.2
pragma solidity ^0.8.20;

interface IRateLimiter {
    function updateRateLimit(address sender, address tokenIn, uint256 amountIn, uint256 amountOut) external;
}
