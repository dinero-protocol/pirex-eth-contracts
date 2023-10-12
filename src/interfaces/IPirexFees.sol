// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface IPirexFees {
    /** 
        @notice Distribute fees
        @param  from    address  Fee source
        @param  token   address  Fee token
        @param  amount  uint256  Fee token amount
     */
    function distributeFees(
        address from,
        address token,
        uint256 amount
    ) external;
}
