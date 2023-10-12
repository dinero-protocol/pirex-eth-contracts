// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {AccessControlDefaultAdminRules} from "openzeppelin-contracts/contracts/access/AccessControlDefaultAdminRules.sol";
import {DataTypes} from "./libraries/DataTypes.sol";
import {IOracleAdapter} from "./interfaces/IOracleAdapter.sol";
import {IPirexEth} from "./interfaces/IPirexEth.sol";
import {Errors} from "./libraries/Errors.sol";

/// @title  Responsible for managing validators rewards
/// @author redactedcartel.finance
contract RewardRecipient is AccessControlDefaultAdminRules {
    bytes32 public constant KEEPER_ROLE = keccak256("KEEPER_ROLE");
    bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");

    // Pirex contracts
    IPirexEth public pirexEth;
    IOracleAdapter public oracleAdapter;

    // Events
    event SetContract(DataTypes.Contract indexed c, address contractAddress);

    // Modifiers
    modifier onlyOracleAdapter() {
        if (msg.sender != address(oracleAdapter))
            revert Errors.NotOracleAdapter();
        _;
    }

    /**
        @param  _admin         address  Admin address
        @param  _initialDelay  uint48   Delay required to schedule the acceptance 
                                        of a access control transfer started
     */
    constructor(
        address _admin,
        uint48 _initialDelay
    ) AccessControlDefaultAdminRules(_initialDelay, _admin) {}

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

        if (c == DataTypes.Contract.OracleAdapter) {
            oracleAdapter = IOracleAdapter(contractAddress);
        }
    }

    /** 
        @notice Dissolve validator
        @param  _pubKey  bytes    Key
        @param  _amount  uint256  ETH amount
     */
    function dissolveValidator(
        bytes calldata _pubKey,
        uint256 _amount
    ) external onlyOracleAdapter {
        pirexEth.dissolveValidator{value: _amount}(_pubKey);
    }

    /** 
        @notice Slash validator
        @param  _pubKey          bytes                      Key
        @param  _removeIndex     uint256                    Validator public key index
        @param  _amount          uint256                    ETH amount released from Beacon chain
        @param  _unordered       bool                       Removed in gas efficient way or not
        @param  _useBuffer       bool                       whether to use buffer to compensate the penalty
        @param  _burnerAccounts  DataTypes.BurnerAccount[]  Burner accounts
     */
    function slashValidator(
        bytes calldata _pubKey,
        uint256 _removeIndex,
        uint256 _amount,
        bool _unordered,
        bool _useBuffer,
        DataTypes.BurnerAccount[] calldata _burnerAccounts
    ) external payable onlyRole(KEEPER_ROLE) {
        if (_useBuffer && msg.value > 0) {
            revert Errors.NoETHAllowed();
        }
        pirexEth.slashValidator{value: _amount + msg.value}(
            _pubKey,
            _removeIndex,
            _amount,
            _unordered,
            _useBuffer,
            _burnerAccounts
        );
    }

    /**
        @notice Harvest and mint staking rewards
        @param  _amount    uint256  Amount of ETH to be harvested
        @param  _endBlock  uint256  Block until which ETH rewards are computed
    */
    function harvest(
        uint256 _amount,
        uint256 _endBlock
    ) external onlyRole(KEEPER_ROLE) {
        pirexEth.harvest{value: _amount}(_endBlock);
    }

    /**
        @notice Receive MEV rewards
     */
    receive() external payable {}
}
