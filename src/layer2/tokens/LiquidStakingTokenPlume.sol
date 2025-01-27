// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IWETH} from "src/layer2/interfaces/IWETH.sol";
import {LiquidStakingToken, L2SyncPool} from "../LiquidStakingToken.sol";
import {IArbitrumMessenger} from "../interfaces/IArbitrumMessenger.sol";
import {IL1Receiver} from "src/vendor/layerzero/syncpools/interfaces/IL1Receiver.sol";
import {Constants} from "src/layer2/libraries/Constants.sol";
import {Errors} from "src/layer2/libraries/Errors.sol";

/**
 * @title  PlumeLST
 * @notice An LiquidStakingToken OApp contract using non native bridges for syncing L2 deposits.
 * @dev    This contract facilitates interactions between mainnet PirexEth contracts and the L2 system.
 * @author redactedcartel.finance
 */
contract PlumeLST is LiquidStakingToken {
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

    /**
     * @inheritdoc L2SyncPool
     */
    function _deposit(
        address tokenIn,
        uint256 amountIn,
        uint256 minAmountOut
    ) internal override returns (uint256 amountOut) {
        if (amountIn == 0) revert Errors.ZeroAmount();

        L2SyncPoolStorage storage $ = _getL2SyncPoolStorage();

        Token storage token = $.tokens[tokenIn];
        if (token.l1Address == address(0)) revert Errors.UnauthorizedToken();
        // The contract only holds ETH, always update ETH mapping
        token = $.tokens[Constants.ETH_ADDRESS];

        uint256 amountReceived = amountIn;
        if (tokenIn != Constants.ETH_ADDRESS) {
            // get the actual amount sent and the expected amount received after bridging
            (amountIn, amountReceived) = $.bridgeQuoter.getAmountOut(
                tokenIn,
                amountIn
            );
        }

        amountOut = $.l2ExchangeRateProvider.getPostFeeAmount(
            tokenIn,
            amountReceived
        );

        if (amountOut < minAmountOut) revert Errors.InsufficientAmountOut();

        emit Deposit(tokenIn, amountIn, minAmountOut);

        _receiveTokenIn(tokenIn, amountIn);

        token.unsyncedAmountIn += amountIn;

        if (
            token.maxSyncAmount != 0 &&
            token.unsyncedAmountIn > token.maxSyncAmount
        ) {
            revert Errors.MaxSyncAmountExceeded();
        }

        token.unsyncedAmountOut += amountOut;
    }

    /**
     * @inheritdoc L2SyncPool
     */
    function _receiveTokenIn(
        address tokenIn,
        uint256 amountIn
    ) internal override {
        if (tokenIn == Constants.ETH_ADDRESS) {
            if (amountIn != msg.value) revert Errors.InvalidAmountIn();
        } else {
            if (msg.value != 0) revert Errors.InvalidAmountIn();

            // warning: not safe with transfer tax tokens
            SafeERC20.safeTransferFrom(
                IERC20(tokenIn),
                msg.sender,
                address(this),
                amountIn
            );

            uint256 balanceBefore = address(this).balance;

            // withdraw ETH from WETH
            IWETH(tokenIn).withdraw(amountIn);

            // assert new balance is correct
            if (address(this).balance != balanceBefore + amountIn) {
                revert Errors.NativeTransferFailed();
            }
        }
    }

    receive() external payable {}
}
