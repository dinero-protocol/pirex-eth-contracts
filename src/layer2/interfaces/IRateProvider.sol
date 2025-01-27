// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IL2ExchangeRateProvider} from "src/vendor/layerzero/syncpools/interfaces/IL2ExchangeRateProvider.sol";

interface IRateProvider is IL2ExchangeRateProvider {
    function getConversionAmount(
        address tokenIn,
        uint256 amountIn
    ) external returns (uint256 amountOut);

    function getAssetsPerShare() external returns (uint256 assetsPerShare);
}
