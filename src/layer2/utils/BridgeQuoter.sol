// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IBridgeQuoter} from "src/layer2/interfaces/IBridgeQuoter.sol";

contract BridgeQuoter is IBridgeQuoter {
    function getAmountOut(
        address,
        uint256 amountIn
    ) external pure returns (uint256, uint256) {
        return (amountIn, amountIn);
    }
}