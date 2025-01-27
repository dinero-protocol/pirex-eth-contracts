// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {LiquidStakingTokenCompose} from "../LiquidStakingTokenCompose.sol";
import {IArbitrumMessenger} from "../interfaces/IArbitrumMessenger.sol";
import {IL1Receiver} from "src/vendor/layerzero/syncpools/interfaces/IL1Receiver.sol";

/**
 * @title  OrbitLST
 * @notice An LiquidStakingToken OApp contract using non native bridges for syncing L2 deposits.
 * @dev    This contract facilitates interactions between mainnet PirexEth contracts and the L2 system.
 * @author redactedcartel.finance
 */
contract OrbitLST is LiquidStakingTokenCompose {
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

        IArbitrumMessenger(getMessenger()).sendTxToL1{value: _value}(
            getReceiver(),
            message
        );
    }
}
