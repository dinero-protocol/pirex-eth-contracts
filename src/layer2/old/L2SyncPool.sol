// SPDX-License-Identifier: LZBL-1.2
pragma solidity ^0.8.20;

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {MessagingFee, MessagingReceipt} from "src/vendor/layerzero/protocol/interfaces/ILayerZeroEndpointV2.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {IL2ExchangeRateProvider} from "src/vendor/layerzero/syncpools/interfaces/IL2ExchangeRateProvider.sol";
import {IL2SyncPool} from "src/vendor/layerzero/syncpools/interfaces/IL2SyncPool.sol";
import {IRateLimiter} from "src/vendor/layerzero/syncpools/interfaces/IRateLimiter.sol";
import {IBridgeQuoter} from "src/layer2/interfaces/IBridgeQuoter.sol";
import {Constants} from "src/layer2/libraries/Constants.sol";
import {Errors} from "src/layer2/libraries/Errors.sol";

/**
 * @title L2 Base Sync Pool
 * @dev Base contract for Layer 2 sync pools
 * A sync pool is an OApp that allows users to deposit tokens on Layer 2, and then sync them to Layer 1
 * The L2 sync pool takes care of deposits on the L2 and syncing to the L1 using the L1 sync pool.
 * Once enough tokens have been deposited, anyone can trigger a sync to Layer 1.
 */
abstract contract L2SyncPool is IL2SyncPool, OwnableUpgradeable {
    struct L2SyncPoolStorage {
        /**
         * @notice The address of the exchange rate provider contract.
         * @dev This variable holds the address of the exchange rate provider contract, which is used to get the conversion rate.
         */
        IL2ExchangeRateProvider l2ExchangeRateProvider;
        /**
         * @notice The address of the rate limiter contract.
         * @dev This variable holds the address of the rate limiter contract, which is used to limit mint and withdrawal.
         */
        IRateLimiter rateLimiter;
        /**
         * @notice The address of the bridge quoter contract.
         * @dev This variable holds the address of the bridge quoter contract, which is used to get the min amount receive when bridging to L1.
         */
        IBridgeQuoter bridgeQuoter;
        /**
         * @notice The token data.
         * @dev This mapping holds the token data, which includes the amount of tokens deposited and minted, and the minimum amount required to sync.
         */
        mapping(address => Token) tokens;
        /**
         * @notice The sync keeper.
         * @dev This mapping holds the sync keepers, which are allowed to trigger a sync to Layer 1.
         */
        mapping(address => bool) syncKeeper;
    }

    /**
     * @dev Token data
     * @param unsyncedAmountIn Amount of tokens deposited on Layer 2
     * @param unsyncedAmountOut Amount of tokens minted on Layer 2
     * @param minSyncAmount Minimum amount of tokens required to sync
     * @param maxSyncAmount Maximum amount of tokens required to sync
     * @param l1Address Address of the token on Layer 1, address(0) is unauthorized
     */
    struct Token {
        uint256 unsyncedAmountIn;
        uint256 unsyncedAmountOut;
        uint256 minSyncAmount;
        uint256 maxSyncAmount;
        address l1Address;
    }

    // keccak256(abi.encode(uint256(keccak256(syncpools.storage.l2syncpool)) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant L2SyncPoolStorageLocation =
        0xc064a301e926254981c9bd3b3225923d097271573deb3cc61ae7f6a144f10a00;

    function _getL2SyncPoolStorage()
        internal
        pure
        returns (L2SyncPoolStorage storage $)
    {
        assembly {
            $.slot := L2SyncPoolStorageLocation
        }
    }

    event L2ExchangeRateProviderSet(address l2ExchangeRateProvider);
    event RateLimiterSet(address rateLimiter);
    event MinSyncAmountSet(address tokenIn, uint256 minSyncAmount);
    event MaxSyncAmountSet(address tokenIn, uint256 maxSyncAmount);
    event L1TokenInSet(address tokenIn, address l1TokenIn);
    event Deposit(address indexed tokenIn, uint256 amountIn, uint256 amountOut);
    event Sync(address indexed tokenIn, uint256 amountIn, uint256 amountOut);
    event SyncKeeperSet(address syncKeeper, bool status);
    event BridgeQuoterSet(address bridgeQuoter);

    /**
     * @dev Modifier to allow only the sync keeper to call the function
     */
    modifier onlySyncKeeper() {
        if (!_getL2SyncPoolStorage().syncKeeper[msg.sender]) {
            revert Errors.UnauthorizedCaller();
        }
        _;
    }

    /**
     * @dev Initialize the L2 Base Sync Pool
     * @param l2ExchangeRateProvider Address of the exchange rate provider
     * @param rateLimiter Address of the rate limiter
     * @param bridgeQuoter Address of the bridge quoter
     */
    function __L2BaseSyncPool_init(
        address l2ExchangeRateProvider,
        address rateLimiter,
        address bridgeQuoter
    ) internal {
        __L2BaseSyncPool_init_unchained(
            l2ExchangeRateProvider,
            rateLimiter,
            bridgeQuoter
        );
    }

    function __L2BaseSyncPool_init_unchained(
        address l2ExchangeRateProvider,
        address rateLimiter,
        address bridgeQuoter
    ) internal {
        _setL2ExchangeRateProvider(l2ExchangeRateProvider);
        _setRateLimiter(rateLimiter);
        _setBridgeQuoter(bridgeQuoter);
    }

    /**
     * @dev Get the exchange rate provider
     * @return l2ExchangeRateProvider Address of the exchange rate provider
     */
    function getL2ExchangeRateProvider() public view virtual returns (address) {
        L2SyncPoolStorage storage $ = _getL2SyncPoolStorage();
        return address($.l2ExchangeRateProvider);
    }

    /**
     * @dev Get the rate limiter
     * @return rateLimiter Address of the rate limiter
     */
    function getRateLimiter() public view virtual returns (address) {
        L2SyncPoolStorage storage $ = _getL2SyncPoolStorage();
        return address($.rateLimiter);
    }

    /**
     * @dev Get token data
     * If the l1Address is address(0), the token is unauthorized
     * @param tokenIn Address of the token
     * @return token Token data
     */
    function getTokenData(
        address tokenIn
    ) public view virtual returns (Token memory) {
        L2SyncPoolStorage storage $ = _getL2SyncPoolStorage();
        return $.tokens[tokenIn];
    }

    /**
     * @dev Check if the address is a sync keeper
     * @param syncKeeper Address of the sync keeper
     * @return status True if the address is a sync keeper
     */
    function isSyncKeeper(
        address syncKeeper
    ) public view virtual returns (bool) {
        return _getL2SyncPoolStorage().syncKeeper[syncKeeper];
    }

    /**
     * @dev Deposit tokens on Layer 2
     * This will mint tokenOut on Layer 2 using the exchange rate for tokenIn to tokenOut.
     * The amount deposited and minted will be stored in the token data which can be synced to Layer 1.
     * Will revert if:
     * - The amountIn is zero
     * - The token is unauthorized (that is, the l1Address is address(0))
     * - The amountOut is less than the minAmountOut
     * @param tokenIn Address of the token
     * @param amountIn Amount of tokens to deposit
     * @param minAmountOut Minimum amount of tokens to mint on Layer 2
     * @return amountOut Amount of tokens minted on Layer 2
     */
    function deposit(
        address tokenIn,
        uint256 amountIn,
        uint256 minAmountOut
    ) public payable virtual override returns (uint256 amountOut) {
        if (amountIn == 0) revert Errors.ZeroAmount();

        L2SyncPoolStorage storage $ = _getL2SyncPoolStorage();

        Token storage token = $.tokens[tokenIn];
        if (token.l1Address == address(0)) revert Errors.UnauthorizedToken();

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

        _sendTokenOut(msg.sender, amountOut);

        return amountOut;
    }

    /**
     * @dev Sync tokens to Layer 1
     * This will send a message to the destination endpoint with the token data to
     * sync the tokens minted on Layer 2 to Layer 1.
     * Will revert if:
     * - The token is unauthorized (that is, the l1Address is address(0))
     * - The amount to sync is zero or less than the minSyncAmount
     * @dev It is very important to listen for the Sync event to know when and how much tokens were synced
     * especially if an action is required on another chain (for example, executing the message). If an action
     * was required but was not executed, the tokens won't be sent to the L1.
     * @param tokenIn Address of the token
     * @param extraOptions Extra options for the messaging protocol
     * @param fee Fast sync messaging fee, does not consider token bridge fees
     * @return unsyncedAmountIn Amount of tokens deposited on Layer 2
     * @return unsyncedAmountOut Amount of tokens minted on Layer 2
     */
    function sync(
        address tokenIn,
        bytes calldata extraOptions,
        MessagingFee calldata fee
    )
        public
        payable
        virtual
        override
        onlySyncKeeper
        returns (uint256 unsyncedAmountIn, uint256 unsyncedAmountOut)
    {
        L2SyncPoolStorage storage $ = _getL2SyncPoolStorage();
        Token storage token = $.tokens[tokenIn];

        address l1TokenIn = token.l1Address;
        if (l1TokenIn == address(0)) revert Errors.UnauthorizedToken();

        unsyncedAmountIn = token.unsyncedAmountIn;
        unsyncedAmountOut = token.unsyncedAmountOut;

        if (unsyncedAmountIn == 0 || unsyncedAmountIn < token.minSyncAmount) {
            revert Errors.InsufficientAmountToSync();
        }

        token.unsyncedAmountIn = 0;
        token.unsyncedAmountOut = 0;

        emit Sync(tokenIn, unsyncedAmountIn, unsyncedAmountOut);

        _sync(
            tokenIn,
            l1TokenIn,
            unsyncedAmountIn,
            unsyncedAmountOut,
            extraOptions,
            fee
        );

        return (unsyncedAmountIn, unsyncedAmountOut);
    }

    /**
     * @dev Set the exchange rate provider
     * @param l2ExchangeRateProvider Address of the exchange rate provider
     */
    function setL2ExchangeRateProvider(
        address l2ExchangeRateProvider
    ) public virtual onlyOwner {
        _setL2ExchangeRateProvider(l2ExchangeRateProvider);
    }

    /**
     * @dev Set the rate limiter
     * @param rateLimiter Address of the rate limiter
     */
    function setRateLimiter(address rateLimiter) public virtual onlyOwner {
        _setRateLimiter(rateLimiter);
    }

    /**
     * @dev Set the minimum amount of tokens required to sync
     * @param tokenIn Address of the token
     * @param minSyncAmount Minimum amount of tokens required to sync
     */
    function setMinSyncAmount(
        address tokenIn,
        uint256 minSyncAmount
    ) public virtual onlyOwner {
        _setMinSyncAmount(tokenIn, minSyncAmount);
    }

    /**
     * @dev Set the maximum amount of tokens to sync
     * @param tokenIn Address of the token
     * @param maxSyncAmount Maximum amount of tokens to sync
     */
    function setMaxSyncAmount(
        address tokenIn,
        uint256 maxSyncAmount
    ) public virtual onlyOwner {
        _setMaxSyncAmount(tokenIn, maxSyncAmount);
    }

    /**
     * @dev Set the Layer 1 address of the token
     * @param l2TokenIn Address of the token on Layer 2
     * @param l1TokenIn Address of the token on Layer 1
     */
    function setL1TokenIn(
        address l2TokenIn,
        address l1TokenIn
    ) public virtual onlyOwner {
        _setL1TokenIn(l2TokenIn, l1TokenIn);
    }

    /**
     * @dev Set the sync keeper
     * @param syncKeeper Address of the sync keeper
     * @param status True to set as a sync keeper
     */
    function setSyncKeeper(
        address syncKeeper,
        bool status
    ) public virtual onlyOwner {
        _setSyncKeeper(syncKeeper, status);
    }

    /**
     * @dev Set bridge quoter
     * @param bridgeQuoter Bridge quoter contract to get the min amount receive when bridging to L1
     */
    function setBridgeQuoter(address bridgeQuoter) public virtual onlyOwner {
        _setBridgeQuoter(bridgeQuoter);
    }

    /**
     * @dev Internal function to set bridge quoter
     * @param bridgeQuoter Bridge quoter contract
     */
    function _setBridgeQuoter(address bridgeQuoter) internal {
        _getL2SyncPoolStorage().bridgeQuoter = IBridgeQuoter(bridgeQuoter);

        emit BridgeQuoterSet(bridgeQuoter);
    }

    /**
     * @dev Internal function to set the sync keeper
     * @param syncKeeper Address of the sync keeper
     * @param status True to set as a sync keeper
     */
    function _setSyncKeeper(address syncKeeper, bool status) internal virtual {
        _getL2SyncPoolStorage().syncKeeper[syncKeeper] = status;

        emit SyncKeeperSet(syncKeeper, status);
    }

    /**
     * @dev Internal function to set the exchange rate provider
     * @param l2ExchangeRateProvider Address of the exchange rate provider
     */
    function _setL2ExchangeRateProvider(
        address l2ExchangeRateProvider
    ) internal virtual {
        if (l2ExchangeRateProvider == address(0)) revert Errors.ZeroAddress();

        L2SyncPoolStorage storage $ = _getL2SyncPoolStorage();
        $.l2ExchangeRateProvider = IL2ExchangeRateProvider(
            l2ExchangeRateProvider
        );

        emit L2ExchangeRateProviderSet(l2ExchangeRateProvider);
    }

    /**
     * @dev Internal function to set the rate limiter
     * @param rateLimiter Address of the rate limiter
     */
    function _setRateLimiter(address rateLimiter) internal virtual {
        if (rateLimiter == address(0)) revert Errors.ZeroAddress();

        L2SyncPoolStorage storage $ = _getL2SyncPoolStorage();
        $.rateLimiter = IRateLimiter(rateLimiter);

        emit RateLimiterSet(rateLimiter);
    }

    /**
     * @dev Internal function to set the minimum amount of tokens required to sync
     * @param tokenIn Address of the token
     * @param minSyncAmount Minimum amount of tokens required to sync
     */
    function _setMinSyncAmount(
        address tokenIn,
        uint256 minSyncAmount
    ) internal virtual {
        if (minSyncAmount == 0) revert Errors.ZeroAmount();

        L2SyncPoolStorage storage $ = _getL2SyncPoolStorage();
        $.tokens[tokenIn].minSyncAmount = minSyncAmount;

        emit MinSyncAmountSet(tokenIn, minSyncAmount);
    }

    /**
     * @dev Internal function to set the maximum amount of tokens to sync
     * @param tokenIn Address of the token
     * @param maxSyncAmount Maximum amount of tokens to sync
     */
    function _setMaxSyncAmount(
        address tokenIn,
        uint256 maxSyncAmount
    ) internal virtual {
        L2SyncPoolStorage storage $ = _getL2SyncPoolStorage();
        $.tokens[tokenIn].maxSyncAmount = maxSyncAmount;

        emit MaxSyncAmountSet(tokenIn, maxSyncAmount);
    }

    /**
     * @dev Internal function to set the Layer 1 address of the token
     * @param l2TokenIn Address of the token on Layer 2
     * @param l1TokenIn Address of the token on Layer 1
     */
    function _setL1TokenIn(
        address l2TokenIn,
        address l1TokenIn
    ) internal virtual {
        if (l1TokenIn == address(0)) revert Errors.ZeroAddress();

        L2SyncPoolStorage storage $ = _getL2SyncPoolStorage();
        $.tokens[l2TokenIn].l1Address = l1TokenIn;

        emit L1TokenInSet(l2TokenIn, l1TokenIn);
    }

    /**
     * @dev Internal function to receive tokens on Layer 2
     * @param tokenIn Address of the token
     * @param amountIn Amount of tokens to receive
     */
    function _receiveTokenIn(
        address tokenIn,
        uint256 amountIn
    ) internal virtual {
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
        }
    }

    /**
     * @dev Internal function to sync tokens to Layer 1
     * @param l2TokenIn Address of the token on Layer 2
     * @param l1TokenIn Address of the token on Layer 1
     * @param amountIn Amount of tokens deposited on Layer 2
     * @param amountOut Amount of tokens minted on Layer 2
     * @param extraOptions Extra options for the messaging protocol
     * @param fee Messaging fee
     * @return receipt Messaging receipt
     */
    function _sync(
        address l2TokenIn,
        address l1TokenIn,
        uint256 amountIn,
        uint256 amountOut,
        bytes calldata extraOptions,
        MessagingFee calldata fee
    ) internal virtual returns (MessagingReceipt memory);

    /**
     * @dev Internal function to send tokenOut to an account
     * @param account Address of the account
     * @param amount Amount of tokens to send
     */
    function _sendTokenOut(address account, uint256 amount) internal virtual;
}
