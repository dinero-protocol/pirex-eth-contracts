//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IWrappedLiquidStakedToken {
    function wrap(uint256 _amount) external returns (uint256);
    function unwrap(uint256 _amount) external returns (uint256);
    function getLSTAddress() external view returns (address);
    function transfer(address recipient, uint256 amount) external returns (bool);
}