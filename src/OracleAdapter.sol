// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {AccessControlDefaultAdminRules} from "openzeppelin-contracts/contracts/access/AccessControlDefaultAdminRules.sol";
import {IPirexEth} from "./interfaces/IPirexEth.sol";
import {IRewardRecipient} from "./interfaces/IRewardRecipient.sol";
import {IOracleAdapter} from "./interfaces/IOracleAdapter.sol";
import {Errors} from "./libraries/Errors.sol";
import {DataTypes} from "./libraries/DataTypes.sol";

contract OracleAdapter is IOracleAdapter, AccessControlDefaultAdminRules {
    // General state variables
    IPirexEth public pirexEth;
    IRewardRecipient public rewardRecipient;
    bytes32 public constant ORACLE_ROLE = keccak256("ORACLE_ROLE");
    bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");

    // Events
    event SetContract(DataTypes.Contract indexed c, address contractAddress);
    event RequestValidatorExit(bytes pubKey);
    event SetPirexEth(address _pirexEth);

    /**
        @param _initialDelay  uint48  Delay required to schedule the acceptance 
    */
    constructor(
        uint48 _initialDelay
    ) AccessControlDefaultAdminRules(_initialDelay, msg.sender) {}

    /**
        @notice Set a contract address
        @param  c                enum     Contract
        @param  contractAddress  address  Contract address    
     */
    function setContract(
        DataTypes.Contract c,
        address contractAddress
    ) external onlyRole(GOVERNANCE_ROLE) {
        if (contractAddress == address(0)) revert Errors.ZeroAddress();

        emit SetContract(c, contractAddress);

        if (c == DataTypes.Contract.PirexEth) {
            pirexEth = IPirexEth(contractAddress);
        }

        if (c == DataTypes.Contract.RewardRecipient) {
            rewardRecipient = IRewardRecipient(contractAddress);
        }
    }

    /** 
        @notice Send the request for voluntary exit
        @param  _pubKey  bytes  Key
     */
    function requestVoluntaryExit(bytes calldata _pubKey) external override {
        if (msg.sender != address(pirexEth)) revert Errors.NotPirexEth();

        emit RequestValidatorExit(_pubKey);
    }

    /** 
        @notice Dissolve validator
        @param  _pubKey  bytes    Key
        @param  _amount  uint256  ETH amount
     */
    function dissolveValidator(
        bytes calldata _pubKey,
        uint256 _amount
    ) external onlyRole(ORACLE_ROLE) {
        rewardRecipient.dissolveValidator(_pubKey, _amount);
    }
}
