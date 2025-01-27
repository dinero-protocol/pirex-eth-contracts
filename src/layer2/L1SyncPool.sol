// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {IPirexEth} from "../interfaces/IPirexEthDeposit.sol";
import {Constants} from "src/vendor/layerzero/syncpools/L1/L1BaseSyncPoolUpgradeable.sol";
import {IDineroERC20} from "src/interfaces/IDineroERC20.sol";
import {Errors} from "./libraries/Errors.sol";

/**
 * @title L1 Base Sync Pool
 * @dev Base contract for Layer 1 sync pools
 * This contract is intended to be inherited by a lockbox contract
 * that will handle the sync of balances from Layer 2 to Layer 1
 * anticipating the deposit of tokens during the fast sync and 
 * finalizing sync by depositing ETH to Pirex ETH during the slow sync
 */
abstract contract L1SyncPool is OwnableUpgradeable {
    struct L1SyncPoolStorage {
        /**
         * @notice The pirexEth instance.
         * @dev This variable holds the address of the PirexEth contract instance.
         */
        IPirexEth pirexEth;
        /**
         * @notice The address of the tokenOut contract.
         * @dev This variable holds the address of the tokenOut contract.
         */
        IERC20 tokenOut;
        /**
         * @notice The total amount of unbacked tokens.
         * @dev This variable holds the total amount of unbacked tokens.
         */
        uint256 totalUnbackedTokens;
        /**
         * @notice Mapping between EID and receiver address.
         * @dev Mapping to keep track of the receiver address for each EID.
         */
        mapping(uint32 => address) receivers;
        /**
         * @notice Processed messages.
         * @dev Mapping to keep track of processed messages.
         */
        mapping(bytes32 => bool) processedMessages;
    }

    // keccak256(abi.encode(uint256(keccak256(syncpools.storage.l1syncpool)) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant L1SyncPoolStorageLocation =
        0xec90cfc37697dc33dbcf188d524bdc2a41f251df5a390991a45d6388ac04b500;

    function _getL1SyncPoolStorage()
        internal
        pure
        returns (L1SyncPoolStorage storage $)
    {
        assembly {
            $.slot := L1SyncPoolStorageLocation
        }
    }

    /**
     * @notice Emitted on setting receiver.
     * @param  originEid  uint32   Origin EID.
     * @param  receiver   address  Address of the receiver.
     */
    event ReceiverSet(uint32 indexed originEid, address receiver);

    /**
     * @notice Emitted on setting tokenOut.
     * @param  tokenOut  address  Address of the tokenOut.
     */
    event TokenOutSet(address tokenOut);

    /**
     * @notice Emitted on setting platform.
     * @param  platform  address  Address of the platform.
     */
    event PlatformSet(address platform);

    /**
     * @notice Emitted on withdrawal.
     * @param  receiver  address  Address of the receiver.
     * @param  amount    uint256  Amount.
     */
    event Withdraw(address receiver, uint256 amount);

    /**
     * @dev Initialize the contract
     * @param platform Address of the platform
     * @param tokenOut Address of the main token
     */
    function __L1BaseSyncPool_init(
        address platform,
        address tokenOut
    ) internal onlyInitializing {
        _setPlatform(platform);
        _setTokenOut(tokenOut);
    }

    /**
     * @dev Get the main token address
     * @return The main token address
     */
    function getTokenOut() public view returns (IERC20) {
        L1SyncPoolStorage storage $ = _getL1SyncPoolStorage();
        return $.tokenOut;
    }

    /**
     * @dev Get the receiver address for a specific origin EID
     * @param originEid Origin EID
     * @return The receiver address
     */
    function getReceiver(uint32 originEid) public view returns (address) {
        L1SyncPoolStorage storage $ = _getL1SyncPoolStorage();
        return $.receivers[originEid];
    }

    /**
     * @dev Get the total unbacked tokens
     * @return The total unbacked tokens
     */
    function getTotalUnbackedTokens() public view returns (uint256) {
        L1SyncPoolStorage storage $ = _getL1SyncPoolStorage();
        return $.totalUnbackedTokens;
    }

    /**
     * @dev Receive a message from an L2
     * Will revert if:
     * - The caller is not the receiver
     * @param originEid Origin EID
     * @param guid Message GUID
     * @param tokenIn Token address
     * @param amountIn Amount in
     * @param amountOut Amount out
     */
    function onMessageReceived(
        uint32 originEid,
        bytes32 guid,
        address tokenIn,
        uint256 amountIn,
        uint256 amountOut
    ) public payable virtual {
        L1SyncPoolStorage storage $ = _getL1SyncPoolStorage();

        if (msg.sender != $.receivers[originEid])
            revert Errors.UnauthorizedCaller();

        _finalizeDeposit(originEid, guid, tokenIn, amountIn, amountOut);
    }

    /**
     * @dev Set the receiver address for a specific origin EID
     * @param originEid Origin EID
     * @param receiver Receiver address
     */
    function setReceiver(uint32 originEid, address receiver) public onlyOwner {
        _setReceiver(originEid, receiver);
    }

    /**
     * @dev Get the platform address
     * @return The platform address
     */
    function getPlatform() public view returns (address) {
        return address(_getL1SyncPoolStorage().pirexEth);
    }

    /**
     * @dev Set the platform address
     * @param platform The platform address
     */
    function setPlatform(address platform) public onlyOwner {
        _setPlatform(platform);
    }

    /**
     * @dev Internal function to set the platform address
     * @param platform The platform address
     */
    function _setPlatform(address platform) internal {
        if (platform == address(0)) revert Errors.ZeroAddress();

        L1SyncPoolStorage storage $ = _getL1SyncPoolStorage();

        $.pirexEth = IPirexEth(platform);

        emit PlatformSet(platform);
    }

    /**
     * @dev Set the main token address
     * @param tokenOut Address of the main token
     */
    function setTokenOut(address tokenOut) public onlyOwner {
        _setTokenOut(tokenOut);
    }

    /**
     * @dev Internal function to set the main token address
     * @param tokenOut Address of the main token
     */
    function _setTokenOut(address tokenOut) internal {
        if (tokenOut == address(0)) revert Errors.ZeroAddress();

        L1SyncPoolStorage storage $ = _getL1SyncPoolStorage();
        $.tokenOut = IERC20(tokenOut);

        emit TokenOutSet(tokenOut);
    }

    /**
     * @dev Internal function to set the receiver address for a specific origin EID
     * @param originEid Origin EID
     * @param receiver Receiver address
     */
    function _setReceiver(uint32 originEid, address receiver) internal {
        if (receiver == address(0)) revert Errors.ZeroAddress();

        L1SyncPoolStorage storage $ = _getL1SyncPoolStorage();
        $.receivers[originEid] = receiver;

        emit ReceiverSet(originEid, receiver);
    }

    /**
     * @dev Internal function to anticipate a deposit
     * Will mint pxEth and transfer it to the lock box
     * @param guid Message GUID
     * @param amountOut Amount of token received by the users
     * @return actualAmountOut The actual amount of token received
     */
    function _anticipatedDeposit(
        bytes32 guid,
        address,
        uint256,
        uint256 amountOut
    ) internal virtual returns (uint256) {
        // if the message was already processed, return 0
        // this should only happen if the slow sync msg arrives first than the fast sync msg
        if (_getL1SyncPoolStorage().processedMessages[guid]) return 0;

        L1SyncPoolStorage storage $ = _getL1SyncPoolStorage();

        _getL1SyncPoolStorage().processedMessages[guid] = true;

        $.totalUnbackedTokens += amountOut;

        IDineroERC20 pxETH = IDineroERC20(address(getTokenOut()));

        pxETH.mint(address(this), amountOut);

        return amountOut;
    }

    /**
     * @dev Internal function to update lockbox state when finalizing a deposit
     */
    function _handleFinalizeDeposit(
        bytes32 guid,
        uint256 amountOut
    ) internal virtual {}

    /**
     * @dev Internal function to finalize a deposit
     * Will swap the dummy tokens for the actual ETH
     * Will revert if:
     * - The token in is not ETH
     * - The amount in is not equal to the value
     * - The dummy token is not set
     * @param guid Message GUID
     * @param tokenIn Address of the token in
     * @param amountIn Amount in
     */
    function _finalizeDeposit(
        uint32,
        bytes32 guid,
        address tokenIn,
        uint256 amountIn,
        uint256 amountOut
    ) internal {
        if (amountOut > msg.value) revert Errors.InvalidAmount();

        // if the message was not processed, anticipate the deposit first
        // this should not normally happen
        if (!_getL1SyncPoolStorage().processedMessages[guid]) {
            _anticipatedDeposit(guid, tokenIn, amountIn, amountOut);
        }

        L1SyncPoolStorage storage $ = _getL1SyncPoolStorage();

        $.totalUnbackedTokens > amountOut
            ? $.totalUnbackedTokens -= amountOut
            : $.totalUnbackedTokens = 0;

        // sent the ETH to PirexETH
        (uint256 postFeeAmount, ) = IPirexEth(getPlatform()).deposit{
            value: msg.value
        }(address(this), false);

        // if it receives from the deposit more tokens than anticipated
        // then it should only burn the anticipated amount (amountOut)
        // this might happen if the deposit fee gets reduced from the moment of the L2 deposit
        // to the moment of the deposit finalization
        // the extra pxEth amount can be withdrawn by the owner through `withdraw()`
        uint256 amountToBurn = postFeeAmount > amountOut
            ? amountOut
            : postFeeAmount;

        // burn the pxEth
        IDineroERC20(address(getTokenOut())).burn(address(this), amountToBurn);

        // notify the lockbox to deposit up to amountIn into the vault
        _handleFinalizeDeposit(guid, amountOut);
    }

    /**
     * @notice Transfers to `receiver` the excess tokens not burned during the sync finalization
     * because of the amount received being greater than the anticipated amount
     * @param receiver the address of the token receiver
     */
    function withdraw(address receiver, uint256 amount) external onlyOwner {
        if (amount == 0) revert Errors.ZeroAmount();

        IDineroERC20 pxEth = IDineroERC20(address(getTokenOut()));

        pxEth.transfer(receiver, amount);

        emit Withdraw(receiver, amount);
    }
}
