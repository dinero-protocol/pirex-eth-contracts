// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {DineroERC20RebaseUpgradeable} from "./DineroERC20RebaseUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "openzeppelin-contracts-upgradeable/contracts/utils/ReentrancyGuardUpgradeable.sol";
import {PausableUpgradeable} from "openzeppelin-contracts-upgradeable/contracts/utils/PausableUpgradeable.sol";
import {OAppUpgradeable} from "src/vendor/layerzero-upgradeable/oapp/OAppUpgradeable.sol";
import {MessagingFee, MessagingReceipt} from "src/vendor/layerzero-upgradeable/oapp/OAppSenderUpgradeable.sol";
import {OAppOptionsType3Upgradeable} from "src/vendor/layerzero-upgradeable/oapp/libs/OAppOptionsType3Upgradeable.sol";
import {Origin} from "src/vendor/layerzero-upgradeable/oapp/interfaces/IOAppReceiver.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import {Constants} from "./libraries/Constants.sol";
import {Errors} from "./libraries/Errors.sol";
import {L2SyncPool} from "./L2SyncPool.sol";
import {BaseMessengerUpgradeable} from "src/vendor/layerzero/syncpools/utils/BaseMessengerUpgradeable.sol";
import {BaseReceiverUpgradeable} from "src/vendor/layerzero/syncpools/utils/BaseReceiverUpgradeable.sol";
import {IRateProvider} from "./interfaces/IRateProvider.sol";
import {IRateLimiter} from "src/vendor/layerzero/syncpools/interfaces/IRateLimiter.sol";
import {IWrappedLiquidStakedToken} from "./interfaces/IWrappedLiquidStakedToken.sol";

/**
 * @title  LiquidStakingToken
 * @notice An DineroERC20Rebase OApp contract for handling LST operations between L2 and mainnet.
 * @dev    This contract facilitates interactions between mainnet PirexEth contracts and the L2 system.
 * @author redactedcartel.finance
 */
abstract contract LiquidStakingToken is
    DineroERC20RebaseUpgradeable,
    L2SyncPool,
    BaseMessengerUpgradeable,
    BaseReceiverUpgradeable,
    OAppUpgradeable,
    OAppOptionsType3Upgradeable,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable
{
    /**
     * @dev Library: FixedPointMathLib - Provides fixed-point arithmetic for uint256.
     */
    using FixedPointMathLib for uint256;

    /**
     * @notice The endpoint ID for L1.
     * @dev This constant defines the source endpoint ID for the L1.
     */
    uint32 internal immutable L1_EID;

    /// @custom:storage-location erc7201:redacted.storage.LiquidStakingToken
    struct L2TokenStorage {
        /**
         * @notice Total assets actively staked in the vault.
         * @dev This variable holds the total assets actively staked, follows totalAssets in the mainnet lockbox.
         */
        uint256 totalStaked;
        /**
         * @notice The last assets per share value.
         * @dev This variable holds the last assets per share value received form deposit or rebase.
         */
        uint256 lastAssetsPerShare;
        /**
         * @notice The unsynced pending deposit amount.
         * @dev This variable holds the pending deposit amount that has not been synced and is not staked in the mainnet vault and will not be reabsed.
         */
        uint256 unsyncedPendingDeposit;
        /**
         * @notice The synced pending deposit amount.
         * @dev This variable holds the pending deposit amount that has been synced is not staked in the mainnet vault and will not be reabsed.
         */
        uint256 syncedPendingDeposit;
        /**
         * @notice The total unsynced shares.
         * @dev This variable holds the total unsynced shares.
         */
        uint256 unsyncedShares;
        /**
         * @notice The rebase fee that is charged on each rebase.
         * @dev This variable holds the rebase fee that is charged on each rebase.
         */
        uint256 rebaseFee;
        /**
         * @notice The sync deposit fee that is charged on each sync pool L2 deposit.
         * @dev This variable holds the sync deposit fee that is charged on each sync pool L2 deposit.
         */
        uint256 syncDepositFee;
        /**
         * @notice The treasury address that receives the treasury fee.
         * @dev This variable holds the address of the treasury, which receives the treasury fee when a rebase occurs.
         */
        address treasury;
        /**
         * @notice Last pending sync index.
         * @dev This variable holds the last pending sync index.
         */
        uint256 lastPendingSyncIndex;
        /**
         * @notice Last completed sync index.
         * @dev This variable holds the last completed sync index.
         */
        uint256 lastCompletedSyncIndex;
        /**
         * @notice Sync index to pending amount mapping.
         * @dev This mapping holds the sync index to pending amount mapping.
         */
        mapping(uint256 => uint256) syncIndexPendingAmount;
        /**
         * @notice Sync ID to index mapping.
         * @dev This mapping holds the sync ID to index mapping.
         */
        mapping(bytes32 => uint256) syncIdIndex;
        /**
         * @notice The nonce for the received messages.
         * @dev Mapping to track the maximum received nonce for each source endpoint and sender
         */
        mapping(uint32 eid => mapping(bytes32 sender => uint64 nonce)) receivedNonce;
        /**
         * @notice Mapping to track the accounts that can pause the contract.
         * @dev This mapping holds the accounts that can pause the contract.
         */
        mapping(address => bool) canPause;
        /**
         * @dev The address of the Wrapped Liquid Staked Token contract.
         * @dev This variable holds the address of the Wrapped Liquid Staked Token contract.
         */
        address wLST;
    }

    // keccak256(abi.encode(uint256(keccak256(redacted.storage.LiquidStakingToken)) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant LiquidStakingTokenStorageLocation =
        0xdd932cf12f0dd29482349e8f041f211cd1a01e556f17b4835472bd462fb09100;

    function _getLiquidStakingTokenStorage()
        internal
        pure
        returns (L2TokenStorage storage $)
    {
        assembly {
            $.slot := LiquidStakingTokenStorageLocation
        }
    }

    // Events

    /**
     * @notice Emitted on sending withdrawal message.
     * @param  guid         bytes32  GUID of the OFT message.
     * @param  fromAddress  address  Address of the sender on the src chain.
     * @param  toAddress    address  Address of the recipient on the src chain.
     * @param  amount       uint256  Withdrawal amount (in LiquidStakingToken).
     */
    event Withdrawal(
        bytes32 indexed guid,
        address indexed fromAddress,
        address indexed toAddress,
        uint256 amount
    );

    /**
     * @notice Emitted on receiving the deposit message.
     * @param  guid         bytes32  GUID of the OFT message.
     * @param  toAddress    address  Address of the recipient on L2.
     * @param  shares       uint256  Deposit amount (in shares).
     * @param  amount       uint256  Deposit amount (in LiquidStakingToken).
     */
    event Deposit(
        bytes32 indexed guid,
        address indexed toAddress,
        uint256 shares,
        uint256 amount
    );

    /**
     * @notice Emitted on minting tokens from SyncPool.
     * @param  toAddress    address  Address of the recipient on L2.
     * @param  shares       uint256  Deposit amount (in shares).
     * @param  amount       uint256  Deposit amount (in LiquidStakingToken).
     */
    event Mint(address indexed toAddress, uint256 shares, uint256 amount);

    /**
     * @notice Emitted on receiving rebase message.
     * @param  guid             bytes32  GUID of the OFT message.
     * @param  treasury         address  Address of the treasury.
     * @param  assetsPerShare   uint256  The current assets per share.
     * @param  amount           uint256  Deposit amount (in LiquidStakingToken).
     * @param  fee              uint256  Fee amount (in LiquidStakingToken).
     * @param  feeShares        uint256  Fee amount (in shares).
     */
    event Rebase(
        bytes32 indexed guid,
        address indexed treasury,
        uint256 assetsPerShare,
        uint256 amount,
        uint256 fee,
        uint256 feeShares
    );

    /**
     * @notice Emitted when the pause is set.
     * @param  account  address  The account that can pause the contract.
     * @param  allowed  bool     The allowed status.
     */
    event canPauseSet(address indexed account, bool allowed);

    /**
     * @notice Contract constructor to initialize LiquidStakingTokenVault with necessary parameters and configurations.
     * @dev    This constructor sets up the LiquidStakingTokenVault contract, configuring key parameters and initializing state variables.
     * @param  _endpoint   address  The address of the LOCAL LayerZero endpoint.
     * @param  _srcEid     uint32   The source endpoint ID.
     */
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address _endpoint, uint32 _srcEid) OAppUpgradeable(_endpoint) {
        L1_EID = _srcEid;
        _disableInitializers();
    }

    /**
     * @dev modifier to allow only the owner or the canPause address to pause the contract
     */
    modifier onlyCanPause() {
        if (!_canPause(_msgSender())) revert Errors.NotAllowed();
        _;
    }

    /**
     * @notice Initialize the LiquidStakingToken contract.
     * @param _delegate address The delegate capable of making OApp configurations inside of the endpoint.
     * @param _owner    address The owner of the contract.
     * @param _treasury address The treasury address.
     * @param _l2ExchangeRateProvider Address of the exchange rate provider
     * @param _rateLimiter address The rate limiter address.
     * @param _messenger Address of the messenger contract (most of the time, the L2 native bridge address)
     * @param _receiver Address of the receiver contract (most of the time, the L1 receiver contract)
     * @param _bridgeQuoter Address of the bridge quoter contract
     * @param _name     string  The name of the token.
     * @param _symbol   string  The symbol of the token.
     */
    function initialize(
        address _delegate,
        address _owner,
        address _treasury,
        address _l2ExchangeRateProvider,
        address _rateLimiter,
        address _messenger,
        address _receiver,
        address _bridgeQuoter,
        string memory _name,
        string memory _symbol
    ) external initializer {
        __LiquidStakingToken_init(_delegate, _owner, _treasury, _name, _symbol);
        __L2BaseSyncPool_init(
            _l2ExchangeRateProvider,
            _rateLimiter,
            _bridgeQuoter
        );
        __BaseMessenger_init(_messenger);
        __BaseReceiver_init(_receiver);
    }

    function __LiquidStakingToken_init(
        address _delegate,
        address _owner,
        address _treasury,
        string memory _name,
        string memory _symbol
    ) internal onlyInitializing {
        __ReentrancyGuard_init();
        __Pausable_init();
        __Ownable_init(_owner);
        __OAppCore_init(_delegate);
        __DineroERC20Rebase_init(_name, _symbol);

        _setTreasury(_treasury);
    }

    /**
     * @notice Handler for processing layerzero messages from L2.
     * @dev    Only accept and handle the deposit and rebase  messages from mainnet, which mints and stakes LiquidStakingToken.
     * @dev    _origin   Origin   The origin information containing the source endpoint and sender address.
     * @dev    _guid     bytes32  The unique identifier for the received LayerZero message.
     * @param  _message  bytes    The payload of the received message.
     * @dev              address  The address of the executor for the received message.
     * @dev              bytes    Additional arbitrary data provided by the corresponding executor.
     */
    function _lzReceive(
        Origin calldata _origin,
        bytes32 _guid,
        bytes calldata _message,
        address,
        bytes calldata
    ) internal virtual override nonReentrant {
        _acceptNonce(_origin.srcEid, _origin.sender, _origin.nonce);

        _handleMessageReceived(_guid, _message);
    }

    /**
     * @notice Handler for processing layerzero messages.
     * @dev    Only accept and handle the deposit and rebase  messages from mainnet, which mints and stakes LiquidStakingToken.
     * @dev    _guid     bytes32  The unique identifier for the received LayerZero message.
     * @param  _message  bytes    The payload of the received message.
     * @dev              address  The address of the executor for the received message.
     * @dev              bytes    Additional arbitrary data provided by the corresponding executor.
     */
    function _handleMessageReceived(
        bytes32 _guid,
        bytes calldata _message
    ) internal virtual returns (uint256 amountReceived) {
        (
            uint256 _messageType,
            uint256 _amount,
            uint256 _assetsPerShare,
            address _receiver,
            bytes32[] memory _syncedIds
        ) = _decodeReceivedMessage(_message);

        L2TokenStorage storage $ = _getLiquidStakingTokenStorage();

        if (
            _messageType == Constants.MESSAGE_TYPE_DEPOSIT ||
            _messageType == Constants.MESSAGE_TYPE_DEPOSIT_WRAP
        ) {
            _updateTotalStaked(0, _assetsPerShare);

            uint256 shares = getTotalShares() == 0
                ? _amount
                : convertToShares(_amount);

            if (_messageType == Constants.MESSAGE_TYPE_DEPOSIT_WRAP) {
                _mintShares(address(this), shares);
                $.totalStaked += _amount;

                uint256 amount = convertToAssets(shares, true);
                _approve(address(this), $.wLST, amount, false);
                uint256 wAmount = IWrappedLiquidStakedToken($.wLST).wrap(
                    amount
                );
                IWrappedLiquidStakedToken($.wLST).transfer(_receiver, wAmount);
            } else {
                _mintShares(_receiver, shares);
                $.totalStaked += _amount;
            }

            IRateLimiter(getRateLimiter()).updateRateLimit(
                address(this),
                address(this),
                shares,
                0
            );

            emit Deposit(_guid, _receiver, shares, _amount);
        } else if (_messageType == Constants.MESSAGE_TYPE_REBASE) {
            _updateTotalStaked(0, _assetsPerShare);

            uint256 fee = _amount.mulDivDown(
                $.rebaseFee,
                Constants.FEE_DENOMINATOR
            );

            uint256 shares;
            if (fee > 0 && _totalAssets() > fee) {
                shares = fee.mulDivDown(getTotalShares(), _totalAssets() - fee);

                _mintShares($.treasury, shares);

                IRateLimiter(getRateLimiter()).updateRateLimit(
                    address(this),
                    address(this),
                    shares,
                    0
                );
            } else {
                fee = 0;
            }

            emit Rebase(
                _guid,
                $.treasury,
                _assetsPerShare,
                _amount,
                fee,
                shares
            );
        } else {
            revert Errors.NotAllowed();
        }

        if (_syncedIds.length > 0) {
            uint256 staked = _updateSyncQueue(_syncedIds);
            if (staked > 0) {
                $.totalStaked += staked;
                $.syncedPendingDeposit -= staked;
            }
        }

        // update last assets per share
        $.lastAssetsPerShare = _assetsPerShare;

        return _amount;
    }

    /**
     * @dev Decode the received message.
     * @param _message bytes The message to decode.
     * @return messageType uint256 The message type.
     * @return amount uint256 The amount.
     * @return assetsPerShare uint256 The assets per share.
     * @return receiver address The receiver address.
     * @return syncedIds bytes32[] The synced IDs.
     */
    function _decodeReceivedMessage(
        bytes calldata _message
    )
        internal
        pure
        virtual
        returns (
            uint256 messageType,
            uint256 amount,
            uint256 assetsPerShare,
            address receiver,
            bytes32[] memory syncedIds
        )
    {
        return
            abi.decode(
                _message,
                (uint256, uint256, uint256, address, bytes32[])
            );
    }

    /**
     * @notice Mint LiquidStakingToken tokens to the recipient.
     * @dev    Only the Sync Pool contract can mint LiquidStakingToken tokens.
     * @param _to               address The recipient of the minted tokens.
     * @param _assetsPerShare   uint256 The assets per share value.
     * @param _amount           uint256 The amount of assets to mint.
     */
    function _mint(
        address _to,
        uint256 _assetsPerShare,
        uint256 _amount
    ) internal {
        L2TokenStorage storage $ = _getLiquidStakingTokenStorage();

        if ($.lastAssetsPerShare < _assetsPerShare)
            _updateTotalStaked(0, _assetsPerShare);

        uint256 _totalShares = getTotalShares();
        uint256 shares = _totalShares == 0 ? _amount : convertToShares(_amount);
        uint256 depositFee = $.syncDepositFee;

        if (depositFee > 0) {
            uint256 feeShares = shares.mulDivDown(
                depositFee,
                Constants.FEE_DENOMINATOR
            );

            _mintShares($.treasury, feeShares);
            $.unsyncedShares += feeShares;

            shares -= feeShares;
        }

        _mintShares(_to, shares);

        $.unsyncedShares += shares;
        $.unsyncedPendingDeposit += _amount;
        $.lastAssetsPerShare = _assetsPerShare;

        emit Mint(_to, shares, _amount);
    }

    /**
     * @dev Add msg id to sync queue.
     * @param _msgReceipt bytes32  The unique identifier for the message.
     */
    function _addToSyncQueue(MessagingReceipt memory _msgReceipt) internal {
        // add to sync queue
        L2TokenStorage storage $ = _getLiquidStakingTokenStorage();

        $.lastPendingSyncIndex += 1;

        uint256 id = $.lastPendingSyncIndex;
        uint256 unsynced = $.unsyncedPendingDeposit;

        $.syncIdIndex[_msgReceipt.guid] = id;
        $.syncIndexPendingAmount[id] = unsynced;
        $.syncedPendingDeposit += unsynced;
        $.unsyncedPendingDeposit = 0;
    }

    /**
     * @notice Perform withdraw and burn of LiquidStakingToken tokens relaying the withdrawal message to Mainnet.
     * @param _receiver address  The recipient of the withdrawal on Mainnet.
     * @param _refundAddress The address to receive any excess funds sent to layer zero.
     * @param _amount   uint256  Withdrawal amount (in assets).
     * @param _options  bytes    Additional options for the message.
     */
    function withdraw(
        address _receiver,
        address _refundAddress,
        uint256 _amount,
        bytes calldata _options
    ) external payable virtual nonReentrant whenNotPaused {
        if (_receiver == address(0)) revert Errors.ZeroAddress();
        if (_amount == 0) revert Errors.ZeroAmount();

        L2TokenStorage storage $ = _getLiquidStakingTokenStorage();

        uint256 shares = previewWithdraw(_amount);

        IRateLimiter(getRateLimiter()).updateRateLimit(
            address(this),
            address(this),
            0,
            shares
        );

        _burnShares(msg.sender, shares);

        bytes memory payload = abi.encode(
            Constants.MESSAGE_TYPE_WITHDRAW,
            _amount,
            _receiver
        );

        bytes memory combinedOptions = combineOptions(L1_EID, 0, _options);

        uint256 synced = $.syncedPendingDeposit;

        if (synced > 0) {
            uint256 remaining = _withdrawPendingDeposit(_amount);
            if (remaining > 0) {
                $.totalStaked -= remaining;
            }
        } else {
            $.totalStaked -= _amount;
        }

        MessagingReceipt memory msgReceipt = _lzSend(
            L1_EID,
            payload,
            combinedOptions,
            MessagingFee(msg.value, 0),
            payable(_refundAddress)
        );

        emit Withdrawal(msgReceipt.guid, msg.sender, _receiver, _amount);
    }

    /**
     * @notice Deposit tokens on Layer 2
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
    )
        public
        payable
        virtual
        override
        nonReentrant
        whenNotPaused
        returns (uint256)
    {
        return super.deposit(tokenIn, amountIn, minAmountOut);
    }

    /**
     * @notice Deposit tokens on Layer 2 and wrap them
     * This will mint tokenOut on Layer 2 using the exchange rate for tokenIn to tokenOut.
     * The amount deposited and minted will be stored in the token data which can be synced to Layer 1.
     * The minted tokens will be wrapped and sent to the sender.
     * @param tokenIn Address of the token
     * @param amountIn Amount of tokens to deposit
     * @param minAmountOut Minimum amount of tokens to mint on Layer 2
     * @return amountOut Amount of tokens minted on Layer 2
     */
    function depositAndWrap(
        address tokenIn,
        uint256 amountIn,
        uint256 minAmountOut
    )
        public
        payable
        virtual
        override
        nonReentrant
        whenNotPaused
        returns (uint256)
    {
        return super.depositAndWrap(tokenIn, amountIn, minAmountOut);
    }

    /**
     * @notice Quote gas cost for withdrawal messages
     * @param  _receiver  address  The recipient of the withdrawal on Mainnet.
     * @param  _amount    uint256  The withdrawal amount.
     * @param  _options   bytes    Additional options for the message.
     */
    function quoteWithdraw(
        address _receiver,
        uint256 _amount,
        bytes calldata _options
    ) external view virtual returns (MessagingFee memory msgFee) {
        bytes memory _payload = abi.encode(
            Constants.MESSAGE_TYPE_WITHDRAW,
            _amount,
            _receiver
        );

        bytes memory _combinedOptions = combineOptions(L1_EID, 0, _options);

        return _quote(L1_EID, _payload, _combinedOptions, false);
    }

    /**
     * @dev Quote the messaging fee for a sync
     * @param  _tokenIn  address  Address of the input token
     * @param  _options   bytes    Additional options for the message.
     */
    function quoteSync(
        address _tokenIn,
        bytes calldata _options
    ) external view virtual returns (MessagingFee memory msgFee) {
        Token storage token = _getL2SyncPoolStorage().tokens[_tokenIn];

        bytes memory _payload = abi.encode(
            Constants.MESSAGE_TYPE_SYNC,
            _tokenIn,
            token.unsyncedAmountIn,
            token.unsyncedAmountOut
        );

        bytes memory _combinedOptions = combineOptions(L1_EID, 0, _options);

        return _quote(L1_EID, _payload, _combinedOptions, false);
    }

    /**
     * @notice Internal function to set the canPause address.
     * @param _address the address to check if it can pause the contract.
     */
    function _canPause(address _address) internal view returns (bool) {
        return
            _getLiquidStakingTokenStorage().canPause[_address] ||
            _address == owner();
    }

    /**
     * @notice Function to set the canPause address.
     * @param _address the address to check if it can pause the contract.
     */
    function setCanPause(address _address, bool _allowed) external onlyOwner {
        _getLiquidStakingTokenStorage().canPause[_address] = _allowed;
    }

    /**
     * @notice Check if an address can pause the contract.
     * @param _address the address to check if it can pause the contract.
     */
    function canPause(address _address) external view returns (bool) {
        return _canPause(_address);
    }

    /**
     * @notice Pause SyncPool deposits and withdrawals.
     */
    function pause() external onlyCanPause {
        _pause();
    }

    /**
     * @notice Unpause SyncPool deposits and withdrawals.
     */
    function unpause() external onlyCanPause {
        _unpause();
    }

    /**
     * @notice Set the rebase fee.
     * @param _rebaseFee uint256 Rebase fee.
     */
    function setRebaseFee(uint256 _rebaseFee) external onlyOwner {
        if (_rebaseFee > Constants.MAX_REBASE_FEE) revert Errors.InvalidFee();

        _getLiquidStakingTokenStorage().rebaseFee = _rebaseFee;
    }

    /**
     * @notice Set the rebase fee.
     * @param _syncDepositFee uint256 Rebase fee.
     */
    function setSyncDepositFee(uint256 _syncDepositFee) external onlyOwner {
        if (_syncDepositFee > Constants.MAX_DEPOSIT_FEE)
            revert Errors.InvalidFee();

        _getLiquidStakingTokenStorage().syncDepositFee = _syncDepositFee;
    }

    /**
     * @notice Set the treasury address.
     * @param _treasury address Treasury address.
     */
    function setTreasury(address _treasury) external onlyOwner {
        _setTreasury(_treasury);
    }

    /**
     * @notice Set the Wrapped Liquid Staked Token address.
     * @param _wLST address Wrapped Liquid Staked Token address.
     */
    function setWrappedLST(address _wLST) external onlyOwner {
        if (_wLST == address(0)) revert Errors.ZeroAddress();

        _getLiquidStakingTokenStorage().wLST = _wLST;
    }

    /**
     * @return the total amount (in wei) of Pirex Ether controlled by the protocol.
     */
    function totalAssets() public view returns (uint256) {
        return _totalAssets();
    }

    /**
     * @return The treasury address that receives the treasury fee.
     */
    function treasury() public view returns (address) {
        return _getLiquidStakingTokenStorage().treasury;
    }

    /**
     * @return The rebase fee that is charged on each rebase.
     */
    function rebaseFee() public view returns (uint256) {
        return _getLiquidStakingTokenStorage().rebaseFee;
    }

    /**
     * @return The sync deposit fee that is charged on each sync pool L2 deposit.
     */
    function syncDepositFee() public view returns (uint256) {
        return _getLiquidStakingTokenStorage().syncDepositFee;
    }

    /**
     * @return The last assets per share value.
     */
    function lastAssetsPerShare() public view returns (uint256) {
        return _getLiquidStakingTokenStorage().lastAssetsPerShare;
    }

    /**
     * @param  idx  uint256  Sync index
     * @return Pending amount.
     */
    function syncIndexPendingAmount(
        uint256 idx
    ) external view returns (uint256) {
        return _getLiquidStakingTokenStorage().syncIndexPendingAmount[idx];
    }

    /**
     * @return The last pending sync index.
     */
    function lastPendingSyncIndex() external view returns (uint256) {
        return _getLiquidStakingTokenStorage().lastPendingSyncIndex;
    }

    /**
     * @return The last completed sync index.
     */
    function lastCompletedSyncIndex() external view returns (uint256) {
        return _getLiquidStakingTokenStorage().lastCompletedSyncIndex;
    }

    /**
     * @return The total staked amount.
     */
    function totalStaked() external view returns (uint256) {
        return _getLiquidStakingTokenStorage().totalStaked;
    }

    /**
     * @param includeUnsynced bool Include unsynced pending deposit.
     * @return The total amount (in wei) of pending deposit.
     */
    function pendingDeposit(
        bool includeUnsynced
    ) public view returns (uint256) {
        L2TokenStorage storage $ = _getLiquidStakingTokenStorage();

        return
            $.syncedPendingDeposit +
            (includeUnsynced ? $.unsyncedPendingDeposit : 0);
    }

    /**
     * @return the total amount (in wei) of Pirex Ether controlled by the protocol.
     */
    function _totalAssets() internal view override returns (uint256) {
        L2TokenStorage storage $ = _getLiquidStakingTokenStorage();

        return
            $.totalStaked + $.unsyncedPendingDeposit + $.syncedPendingDeposit;
    }

    /**
     * @notice Set the treasury address.
     * @param _treasury address Treasury address.
     */
    function _setTreasury(address _treasury) internal {
        if (_treasury == address(0)) revert Errors.ZeroAddress();

        _getLiquidStakingTokenStorage().treasury = _treasury;
    }

    /**
     * @notice Update the total staked amount.
     * @param _amount          uint256 The amount to update.
     * @param _assetsPerShare  uint256 The assets per share value.
     */
    function _updateTotalStaked(
        uint256 _amount,
        uint256 _assetsPerShare
    ) internal {
        L2TokenStorage storage $ = _getLiquidStakingTokenStorage();

        uint256 _lastAssetsPerShare = $.lastAssetsPerShare;
        uint256 _totalStaked = $.totalStaked;

        _lastAssetsPerShare == 0
            ? $.totalStaked = _totalStaked + _amount
            : $.totalStaked =
            _totalStaked.mulDivDown(_assetsPerShare, _lastAssetsPerShare) +
            _amount;
    }

    /**
     * @notice Withdraw from the pending deposit.
     * @param _withdrawAmount uint256 The amount to withdraw.
     * @return The remaining amount to withdraw from total staked.
     */
    function _withdrawPendingDeposit(
        uint256 _withdrawAmount
    ) internal returns (uint256) {
        L2TokenStorage storage $ = _getLiquidStakingTokenStorage();

        uint256 lastPendingIndex = $.lastPendingSyncIndex;
        uint256 lastCompletedIndex = $.lastCompletedSyncIndex;
        uint256 remaining = _withdrawAmount;

        for (uint256 i = lastCompletedIndex + 1; i <= lastPendingIndex; i++) {
            uint256 pendingAmount = $.syncIndexPendingAmount[i];

            if (pendingAmount > remaining) {
                $.syncIndexPendingAmount[i] -= remaining;
                remaining = 0;
                break;
            }

            remaining -= pendingAmount;
            $.syncIndexPendingAmount[i] = 0;
            $.lastCompletedSyncIndex++;
        }

        $.syncedPendingDeposit -= (_withdrawAmount - remaining);

        return remaining;
    }

    /**
     * @notice Update the sync queue.
     * @param _syncedIds bytes The last synced ids.
     * @return The staked amount.
     */
    function _updateSyncQueue(
        bytes32[] memory _syncedIds
    ) internal returns (uint256) {
        L2TokenStorage storage $ = _getLiquidStakingTokenStorage();

        uint256 staked;
        uint256 index;
        uint256 pendingAmount;
        uint256 syncIdsLen = _syncedIds.length;
        uint256 lastPendingIndex = $.lastPendingSyncIndex;
        uint256 lastCompletedIndex = $.lastCompletedSyncIndex;

        for (uint256 i; i < syncIdsLen; i++) {
            index = $.syncIdIndex[_syncedIds[i]];
            pendingAmount = $.syncIndexPendingAmount[index];

            if (pendingAmount > 0) {
                $.syncIndexPendingAmount[index] = 0;
                staked += pendingAmount;
            }
        }

        // update last completed index
        uint256 startIndex = lastCompletedIndex + 1;
        uint256 maxSyncIndex = syncIdsLen + lastCompletedIndex >
            lastPendingIndex
            ? lastPendingIndex
            : syncIdsLen + lastCompletedIndex;
        for (uint256 i = startIndex; i <= maxSyncIndex; i++) {
            if ($.syncIndexPendingAmount[i] > 0) {
                $.lastCompletedSyncIndex = i - 1;
                break;
            }

            if (i == maxSyncIndex && $.syncIndexPendingAmount[i] == 0) {
                $.lastCompletedSyncIndex = i;
            }
        }

        return staked;
    }

    /**
     * @dev Internal function to sync tokens to L1
     * This will send an additional message to the messenger contract after the LZ message
     * This message will contain the ETH that the LZ message anticipates to receive
     * @param _l2TokenIn Address of the token on Layer 2
     * @param _l1TokenIn Address of the token on Layer 1
     * @param _amountIn Amount of tokens deposited on Layer 2
     * @param _amountOut Amount of tokens minted on Layer 2
     * @param _extraOptions Extra options for the messaging protocol
     * @param _fee Messaging fee
     * @return receipt Messaging receipt
     */
    function _sync(
        address _l2TokenIn,
        address _l1TokenIn,
        uint256 _amountIn,
        uint256 _amountOut,
        bytes calldata _extraOptions,
        MessagingFee calldata _fee
    )
        internal
        virtual
        override
        nonReentrant
        whenNotPaused
        returns (MessagingReceipt memory)
    {
        // send fast sync message
        MessagingReceipt memory receipt = _lzSend(
            L1_EID,
            abi.encode(
                Constants.MESSAGE_TYPE_SYNC,
                _l1TokenIn,
                _amountIn,
                _amountOut
            ),
            combineOptions(L1_EID, 0, _extraOptions),
            MessagingFee(_fee.nativeFee, 0),
            payable(msg.sender)
        );

        _addToSyncQueue(receipt);

        bytes memory data = abi.encode(
            endpoint.eid(),
            receipt.guid,
            _l1TokenIn,
            _amountIn,
            _amountOut
        );

        // send slow sync message
        _sendSlowSyncMessage(_l2TokenIn, _amountIn, _fee.nativeFee, data);

        L2TokenStorage storage $ = _getLiquidStakingTokenStorage();

        IRateLimiter(getRateLimiter()).updateRateLimit(
            address(this),
            Constants.ETH_ADDRESS,
            $.unsyncedShares,
            0
        );
        $.unsyncedShares = 0;

        return receipt;
    }

    /**
     * @dev Internal function to send tokenOut to an account
     * @param _account Address of the account
     * @param _amount Amount of tokens to send
     * @param shouldWrap bool Whether to wrap the tokens before sending
     */
    function _sendTokenOut(
        address _account,
        uint256 _amount,
        bool shouldWrap
    ) internal override {
        L2TokenStorage storage $ = _getLiquidStakingTokenStorage();

        uint256 assetsPerShare = IRateProvider(getL2ExchangeRateProvider())
            .getAssetsPerShare();

        if (shouldWrap) {
            _mint(address(this), assetsPerShare, _amount);
            _approve(address(this), $.wLST, _amount, false);
            uint256 wAmount = IWrappedLiquidStakedToken($.wLST).wrap(_amount);
            IWrappedLiquidStakedToken($.wLST).transfer(_account, wAmount);
        } else {
            _mint(_account, assetsPerShare, _amount);
        }
    }

    /**
     * @dev Internal function to send a slow sync message
     * This function should be overridden to send a slow sync message to the L1 receiver contract
     * @param _l2TokenIn Address of the token on Layer 2
     * @param _amountIn Amount of tokens deposited on Layer 2
     * @param _fastSyncNativeFee The amount of ETH already used as native fee in the fast sync
     * @param _message Message to send
     */
    function _sendSlowSyncMessage(
        address _l2TokenIn,
        uint256 _amountIn,
        uint256 _fastSyncNativeFee,
        bytes memory _message
    ) internal virtual;

    /**
     * @dev Internal function to get the minimum gas limit
     * This function should be overridden to set a minimum gas limit to forward during the execution of the message
     * by the L1 receiver contract. This is mostly needed if the underlying contract have some try/catch mechanism
     * as this could be abused by gas-griefing attacks.
     * @return minGasLimit Minimum gas limit
     */
    function _minGasLimit() internal view virtual returns (uint32) {
        return 0;
    }

    /**
     * @notice Set the last received nonce for the specified source endpoint and sender.
     * @dev this should be used to fix the nonce if there's a problem in the execution of a particular message.
     * @param _srcEid Source endpoint ID.
     * @param _sender Sender's address in bytes32 format.
     * @param _nonce The nonce to be set.
     */
    function setNonce(
        uint32 _srcEid,
        bytes32 _sender,
        uint64 _nonce
    ) external onlyOwner {
        _getLiquidStakingTokenStorage().receivedNonce[_srcEid][
            _sender
        ] = _nonce;
    }

    /**
     * @dev Public function to get the next expected nonce for a given source endpoint and sender.
     * @param _srcEid Source endpoint ID.
     * @param _sender Sender's address in bytes32 format.
     * @return uint64 Next expected nonce.
     */
    function nextNonce(
        uint32 _srcEid,
        bytes32 _sender
    ) public view override returns (uint64) {
        return
            _getLiquidStakingTokenStorage().receivedNonce[_srcEid][_sender] + 1;
    }

    /**
     * @dev Internal function to accept nonce from the specified source endpoint and sender.
     * @param _srcEid Source endpoint ID.
     * @param _sender Sender's address in bytes32 format.
     * @param _nonce The nonce to be accepted.
     */
    function _acceptNonce(
        uint32 _srcEid,
        bytes32 _sender,
        uint64 _nonce
    ) internal {
        L2TokenStorage storage $ = _getLiquidStakingTokenStorage();

        if (_nonce != $.receivedNonce[_srcEid][_sender] + 1)
            revert Errors.InvalidNonce();

        $.receivedNonce[_srcEid][_sender] += 1;
    }
}
