// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {LiquidStakingTokenCompose} from "../LiquidStakingTokenCompose.sol";
import {IL2BaseToken} from "src/layer2/interfaces/IL2BaseToken.sol";
import {IL1Receiver} from "src/vendor/layerzero/syncpools/interfaces/IL1Receiver.sol";

/**
 * @title  ZKSyncLST
 * @notice An implementation of the LiquidStakingToken contract on ZkSync Era that sends slow sync messages to the L2 system.
 * @dev    This contract facilitates interactions between mainnet PirexEth contracts and the ZKSync.
 * @author Dinero Protocol
 */
contract ZKSyncLST is LiquidStakingTokenCompose {
    /**
     * @notice Contract constructor to initialize LiquidStakingTokenVault with necessary parameters and configurations.
     * @dev    This constructor sets up the LiquidStakingTokenVault contract, configuring key parameters and initializing state variables.
     * @param  _endpoint   address  The address of the LOCAL LayerZero endpoint.
     * @param  _srcEid     uint32   The source endpoint ID.
     */
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(
        address _endpoint,
        uint32 _srcEid
    ) LiquidStakingTokenCompose(_endpoint, _srcEid) {}

    /**
     * @dev Internal function to send a slow sync message
     * @param _value Amount of ETH to send
     * @param _data Data to send
     */
    function _sendSlowSyncMessage(
        address,
        uint256 _value,
        uint256,
        bytes memory _data
    ) internal override {
        bytes memory message = abi.encodeCall(
            IL1Receiver.onMessageReceived,
            _data
        );

        IL2BaseToken(getMessenger()).withdrawWithMessage{value: _value}(
            getReceiver(),
            message
        );
    }
}
