// SPDX-License-Identifier: LZBL-1.2
pragma solidity ^0.8.20;

interface IL2ExchangeRateProvider {
    function getConversionAmount(address tokenIn, uint256 amountIn) external returns (uint256 amountOut);
    function getPostFeeAmount(address tokenIn, uint256 amountIn) external view returns (uint256);
}
