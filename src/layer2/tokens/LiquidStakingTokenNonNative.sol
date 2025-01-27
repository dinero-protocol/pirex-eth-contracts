// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {MessagingFee, MessagingReceipt} from "src/vendor/layerzero-upgradeable/oapp/OAppSenderUpgradeable.sol";
import {Constants} from "../libraries/Constants.sol";
import {Errors} from "../libraries/Errors.sol";
import {IBridgeAdapter} from "src/layer2/interfaces/IBridgeAdapter.sol";
import {IRateLimiter} from "src/vendor/layerzero/syncpools/interfaces/IRateLimiter.sol";
import {LiquidStakingToken} from "../LiquidStakingToken.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title  NonNativeLST
 * @notice An LiquidStakingToken OApp contract using non native bridges for syncing L2 deposits.
 * @dev    This contract facilitates interactions between mainnet PirexEth contracts and the L2 system.
 * @author redactedcartel.finance
 */
contract NonNativeLST is LiquidStakingToken {
    /**
     * @dev Library: SafeERC20 - Provides safe transfer functions for ERC20 tokens.
     */
    using SafeERC20 for IERC20;

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
    ) LiquidStakingToken(_endpoint, _srcEid) {}

    /**
     * @dev Internal function to send a slow sync message
     * @param _l2TokenIn Address of the token on Layer 2
     * @param _value Amount of ETH to send
     * @param _fastSyncNativeFee The amount of ETH already used as native fee in the fast sync
     * @param _data Data to send
     */
    function _sendSlowSyncMessage(
        address _l2TokenIn,
        uint256 _value,
        uint256 _fastSyncNativeFee,
        bytes memory _data
    ) internal override {
        if (_l2TokenIn != Constants.ETH_ADDRESS) {
            IERC20(_l2TokenIn).safeTransfer(getMessenger(), _value);
        }

        // send slow sync message
        uint256 messageServiceFee = msg.value - _fastSyncNativeFee;
        if (_l2TokenIn == Constants.ETH_ADDRESS) messageServiceFee += _value;

        IBridgeAdapter(getMessenger()).sendMessage{value: messageServiceFee}(
            getReceiver(),
            _l2TokenIn,
            msg.sender,
            _data,
            _minGasLimit()
        );
    }

    /**
     * @dev Internal function to pay the native fee associated with the message.
     * @param _nativeFee The native fee to be paid.
     * @return nativeFee The amount of native currency paid.
     *
     * @dev This function is overridden to handle the native fee payment for multiple layerzero txs.
     */
    function _payNative(
        uint256 _nativeFee
    ) internal override returns (uint256 nativeFee) {
        if (msg.value < _nativeFee) revert NotEnoughNative(msg.value);
        return _nativeFee;
    }
}
