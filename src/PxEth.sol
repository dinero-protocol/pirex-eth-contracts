// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {DineroERC20} from "./DineroERC20.sol";
import {Errors} from "./libraries/Errors.sol";

/// @title  Main token for the PirexEth system used in the Dinero ecosystem
/// @author redactedcartel.finance
contract PxEth is DineroERC20 {
    // Roles
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    /**
        @param _admin         address  Admin address
        @param _initialDelay  uint48   Delay required to schedule the acceptance 
                                       of a access control transfer started
    */
    constructor(
        address _admin,
        uint48 _initialDelay
    ) DineroERC20("Pirex Ether", "pxETH", 18, _admin, _initialDelay) {}

    /** 
        @notice Approve allowances by operator with specified accounts and amount
        @param  _from    address  Owner of the tokens
        @param  _to      address  Account to be approved
        @param  _amount  uint256  Amount to be approved
     */
    function operatorApprove(
        address _from,
        address _to,
        uint256 _amount
    ) external onlyRole(OPERATOR_ROLE) {
        if (_from == address(0)) revert Errors.ZeroAddress();
        if (_to == address(0)) revert Errors.ZeroAddress();
        if (_amount == 0) revert Errors.ZeroAmount();

        allowance[_from][_to] = _amount;

        emit Approval(_from, _to, _amount);
    }
}
