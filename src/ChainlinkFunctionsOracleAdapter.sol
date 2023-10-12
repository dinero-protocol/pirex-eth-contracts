// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {AccessControl} from "openzeppelin-contracts/contracts/access/AccessControl.sol";
import {Functions, FunctionsClient} from "./vendor/chainlink/functions/FunctionsClient.sol";
import {Errors} from "./libraries/Errors.sol";
import {IPirexEth} from "./interfaces/IPirexEth.sol";
import {DataTypes} from "./libraries/DataTypes.sol";
import {IOracleAdapter} from "./interfaces/IOracleAdapter.sol";

contract ChainlinkFunctionsOracleAdapter is
    IOracleAdapter,
    FunctionsClient,
    AccessControl
{
    using Functions for Functions.Request;

    // General state variables
    IPirexEth public pirexEth;
    uint64 public subscriptionId;
    uint32 public gasLimit;
    mapping(bytes32 => bytes) public requestIdToValidatorPubKey;
    string public source;

    // Events
    event SetPirexEth(address _pirexEth);
    event RequestValidatorExit(bytes validatorPubKey);

    /**
        @param  oracle  address  Oracle address
     */
    constructor(address oracle) FunctionsClient(oracle) {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    /** 
        @notice Set source code
        @param  _source  string  Source code
     */
    function setSourceCode(
        string calldata _source
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        source = _source;
    }

    /** 
        @notice Set subscription identifier
        @param  _subscriptionId  uint64  Subscription identifier
     */
    function setSubscriptionId(
        uint64 _subscriptionId
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        subscriptionId = _subscriptionId;
    }

    /** 
        @notice Set gas limit
        @param  _gasLimit  uint32  Gas limit
     */
    function setGasLimit(
        uint32 _gasLimit
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        gasLimit = _gasLimit;
    }

    /** 
        @notice Send the request for voluntary exit
        @param  _pubKey  bytes  Key
     */
    function requestVoluntaryExit(bytes calldata _pubKey) external override {
        if (msg.sender != address(pirexEth)) revert Errors.NotPirexEth();

        Functions.Request memory req;

        // Get pubKey
        string[] memory args = new string[](1);
        args[0] = string(_pubKey);

        req.initializeRequest(
            Functions.Location.Inline,
            Functions.CodeLanguage.JavaScript,
            source
        );
        req.addArgs(args);

        bytes32 assignedReqID = sendRequest(req, subscriptionId, gasLimit);
        requestIdToValidatorPubKey[assignedReqID] = _pubKey;
    }

    /** 
        @notice Fullfil request
        @param  requestId  bytes32  Request identifier
        @param  response   bytes    Response
     */
    function fulfillRequest(
        bytes32 requestId,
        bytes memory response,
        bytes memory
    ) internal override {
        assert(
            keccak256(response) ==
                keccak256(requestIdToValidatorPubKey[requestId])
        );

        // dissolve validator
        // TODO : pass value while calling dissolveValidator
        pirexEth.dissolveValidator(response);
    }

    /** 
        @notice Set the PirexEth contract address
        @param  _pirexEth  address  PirexEth contract address    
     */
    function setPirexEth(
        address _pirexEth
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_pirexEth == address(0)) revert Errors.ZeroAddress();

        emit SetPirexEth(_pirexEth);

        pirexEth = IPirexEth(_pirexEth);
    }
}
