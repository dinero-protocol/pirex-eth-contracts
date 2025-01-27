// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IMintableERC20} from "./IMintableERC20.sol";

interface IDummyToken is IMintableERC20 {
    function burn(uint256 amount) external;
}
