// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {ERC20PermitUpgradeable, Initializable} from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import {Errors} from "../libraries/Errors.sol";

/**
 * @title Interest-bearing ERC20-like token for L2LiquidStakingToken assets.
 *
 * This contract is abstract. To make the contract deployable override the
 * `_totalAssets` function. `L2LiquidStakingToken.sol` contract inherits DineroERC20Rebase and defines
 * the `_totalAssets` function.
 *
 * DineroERC20Rebase balances are dynamic and represent the holder's share in the total amount
 * of Pirex assets controlled by the protocol. Account shares aren't normalized, so the
 * contract also stores the sum of all shares to calculate each account's token balance
 * which equals to:
 *
 *   shares[account] * _totalAssets() / totalShares
 *
 * For example, assume that we have:
 *
 *   _totalAssets() -> 10 ETH
 *   sharesOf(user1) -> 100
 *   sharesOf(user2) -> 400
 *
 * Therefore:
 *
 *   balanceOf(user1) -> 2 tokens which corresponds 2 ETH
 *   balanceOf(user2) -> 8 tokens which corresponds 8 ETH
 *
 * Since balances of all token holders change when the amount of total pooled assets
 * changes, this token cannot fully implement ERC20 standard: it only emits `Transfer`
 * events upon explicit transfer between holders. In contrast, when total amount of
 * pooled assets increases, no `Transfer` events are generated: doing so would require
 * emitting an event for each token holder and thus running an unbounded loop.
 */
abstract contract DineroERC20RebaseUpgradeable is
    Initializable,
    ERC20PermitUpgradeable
{
    /**
     * @dev Library: FixedPointMathLib - Provides fixed-point arithmetic for uint256.
     */
    using FixedPointMathLib for uint256;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice An executed shares transfer from `sender` to `recipient`.
     *
     * @dev emitted in pair with an ERC20-defined `Transfer` event.
     */
    event TransferShares(
        address indexed from,
        address indexed to,
        uint256 sharesValue
    );

    /**
     * @notice An executed `burnShares` request
     *
     * @dev Reports simultaneously burnt shares amount
     * and corresponding DineroERC20Rebase amount.
     * The DineroERC20Rebase amount is calculated twice: before and after the burning incurred rebase.
     *
     * @param account holder of the burnt shares
     * @param preRebaseTokenAmount amount of DineroERC20Rebase the burnt shares corresponded to before the burn
     * @param postRebaseTokenAmount amount of DineroERC20Rebase the burnt shares corresponded to after the burn
     * @param sharesAmount amount of burnt shares
     */
    event SharesBurnt(
        address indexed account,
        uint256 preRebaseTokenAmount,
        uint256 postRebaseTokenAmount,
        uint256 sharesAmount
    );

    /*//////////////////////////////////////////////////////////////
                            ERC20 REBASE STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @custom:storage-location erc7201:redacted.storage.DineroERC20Rebase
    struct DineroERC20RebaseStorage {
        /**
         * @notice Total amount of shares in existence.
         *
         * @dev The sum of all accounts' shares can be an arbitrary number, therefore
         * it is necessary to store it in order to calculate each account's relative share.
         */
        uint256 totalShares;
        /**
         * @dev DineroERC20Rebase balances are dynamic and are calculated based on the accounts' shares
         * and the total amount of assets controlled by the protocol. Account shares aren't
         * normalized, so the contract also stores the sum of all shares to calculate
         * each account's token balance which equals to:
         *
         *   shares[account] * _totalAssets() / totalShares()
         */
        mapping(address => uint256) shares;
    }

    // keccak256(abi.encode(uint256(keccak256(redacted.storage.DineroERC20Rebase)) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant DineroERC20RebaseStorageLocation =
        0xddf967707f52bbdea6c202114c491d81e6de0cb9ded430e88a276a6f8d3e3800;

    function _getDineroERC20RebaseStorage()
        private
        pure
        returns (DineroERC20RebaseStorage storage $)
    {
        assembly {
            $.slot := DineroERC20RebaseStorageLocation
        }
    }

    /*//////////////////////////////////////////////////////////////
                               INITIALIZER
    //////////////////////////////////////////////////////////////*/

    function __DineroERC20Rebase_init(
        string memory name_,
        string memory symbol_
    ) internal onlyInitializing {
        // Set decoded values for name and symbol.
        __ERC20_init_unchained(name_, symbol_);

        // Set the name for EIP-712 signature.
        __ERC20Permit_init(name_);
    }

    /*//////////////////////////////////////////////////////////////
                               ERC20 OVERRIDES
    //////////////////////////////////////////////////////////////*/

    /**
     * @return the amount of tokens in existence.
     *
     * @dev Always equals to `_totalAssets()` since token amount
     * is pegged to the total amount of assets controlled by the protocol.
     */
    function totalSupply() public view override returns (uint256) {
        return _totalAssets();
    }

    /**
     * @return the amount of tokens owned by the `_account`.
     *
     * @dev Balances are dynamic and equal the `_account`'s share in the amount of the
     * total assets controlled by the protocol. See `sharesOf`.
     */
    function balanceOf(
        address _account
    ) public view override returns (uint256) {
        return convertToAssets(_sharesOf(_account), true);
    }

    /**
     * @notice Moves `_amount` tokens from `_sender` to `_recipient`.
     * Emits a `Transfer` event.
     * Emits a `TransferShares` event.
     */
    function _update(
        address _sender,
        address _recipient,
        uint256 _amount
    ) internal override {
        uint256 sharesToTransfer = convertToShares(_amount);

        if (sharesToTransfer == 0) revert Errors.InvalidAmount();

        _transferShares(_sender, _recipient, sharesToTransfer);
        _emitTransferEvents(_sender, _recipient, _amount, sharesToTransfer);
    }

    /*//////////////////////////////////////////////////////////////
                               ERC20 REBASE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Moves `_shares` token shares from the caller's account to the `_recipient` account.
     *
     * @return amount of transferred tokens.
     * Emits a `TransferShares` event.
     * Emits a `Transfer` event.
     *
     * Requirements:
     *
     * - `_recipient` cannot be the zero address.
     * - the caller must have at least `_shares` shares.
     * - the contract must not be paused.
     *
     * @dev The `_shares` argument is the amount of shares, not tokens.
     */
    function transferShares(
        address _recipient,
        uint256 _shares
    ) external returns (uint256) {
        _transferShares(msg.sender, _recipient, _shares);
        uint256 assets = convertToAssets(_shares, true);
        _emitTransferEvents(msg.sender, _recipient, assets, _shares);
        return assets;
    }

    /**
     * @notice Moves `_shares` token shares from the `_sender` account to the `_recipient` account.
     *
     * @return amount of transferred tokens.
     * Emits a `TransferShares` event.
     * Emits a `Transfer` event.
     *
     * Requirements:
     *
     * - `_sender` and `_recipient` cannot be the zero addresses.
     * - `_sender` must have at least `_shares` shares.
     * - the caller must have allowance for `_sender`'s tokens of at least `getPooledPxEthByShares(_shares)`.
     * - the contract must not be paused.
     *
     * @dev The `_shares` argument is the amount of shares, not tokens.
     */
    function transferSharesFrom(
        address _sender,
        address _recipient,
        uint256 _shares
    ) external returns (uint256) {
        uint256 assets = convertToAssets(_shares, false);
        _spendAllowance(_sender, msg.sender, assets);
        _transferShares(_sender, _recipient, _shares);
        _emitTransferEvents(_sender, _recipient, assets, _shares);
        return assets;
    }

    /**
     * @return the amount of shares owned by `_account`.
     */
    function getTotalShares() public view returns (uint256) {
        return _getDineroERC20RebaseStorage().totalShares;
    }

    /**
     * @return the amount of shares owned by `_account`.
     */
    function sharesOf(address _account) external view returns (uint256) {
        return _sharesOf(_account);
    }

    /**
     * @return the amount of assets that corresponds to `_shares` token shares.
     * @param floor if true, the result is rounded down, otherwise it's rounded up.
     */
    function convertToAssets(
        uint256 _shares,
        bool floor
    ) public view returns (uint256) {
        uint256 totalShares = _getDineroERC20RebaseStorage().totalShares;

        return
            totalShares == 0 ? 0 : floor
                ? _shares.mulDivDown(_totalAssets(), totalShares)
                : _shares.mulDivUp(_totalAssets(), totalShares);
    }

    /**
     * @return the amount of shares that corresponds to `_assets` (pxEth).
     */
    function convertToShares(uint256 _assets) public view returns (uint256) {
        return _convertToShares(_assets, true);
    }

    /**
     * @return the amount of shares that corresponds to `_assets` (pxEth) rounding up.
     */
    function previewWithdraw(uint256 _assets) public view returns (uint256) {
        return _convertToShares(_assets, false);
    }

    /*//////////////////////////////////////////////////////////////
                               INTERNAL LOGIC
    //////////////////////////////////////////////////////////////*/
    /**
     * @return the total amount (in wei) of Pirex assets controlled by the protocol.
     * @dev This is used for calculating tokens from shares and vice versa.
     * @dev This function is required to be implemented in a derived contract.
     */
    function _totalAssets() internal view virtual returns (uint256);

    /**
     * @return the amount of shares owned by `_account`.
     */
    function _sharesOf(address _account) internal view returns (uint256) {
        return _getDineroERC20RebaseStorage().shares[_account];
    }

    /**
     * @notice Moves `_shares` shares from `_sender` to `_recipient`.
     *
     * Requirements:
     *
     * - `_sender` cannot be the zero address.
     * - `_recipient` cannot be the zero address or the `DineroERC20Rebase` token contract itself
     * - `_sender` must hold at least `_shares` shares.
     * - the contract must not be paused.
     */
    function _transferShares(
        address _sender,
        address _recipient,
        uint256 _shares
    ) internal {
        if (_sender == address(0) || _recipient == address(0))
            revert Errors.ZeroAddress();
        if (_recipient == address(this) || _sender == _recipient)
            revert Errors.NotAllowed();

        DineroERC20RebaseStorage storage $ = _getDineroERC20RebaseStorage();

        uint256 currentSenderShares = $.shares[_sender];

        if (_shares > currentSenderShares) revert Errors.InvalidAmount();

        $.shares[_sender] = currentSenderShares - _shares;
        $.shares[_recipient] += _shares;
    }

    /**
     * @notice Creates `_shares` shares and assigns them to `_recipient`, increasing the total amount of shares.
     * @dev This doesn't increase the token total supply.
     *
     * NB: The method doesn't check protocol pause relying on the external enforcement.
     *
     * Requirements:
     *
     * - `_recipient` cannot be the zero address.
     * - the contract must not be paused.
     */
    function _mintShares(
        address _recipient,
        uint256 _shares
    ) internal returns (uint256) {
        if (_recipient == address(0)) revert Errors.ZeroAddress();

        DineroERC20RebaseStorage storage $ = _getDineroERC20RebaseStorage();

        $.totalShares += _shares;

        $.shares[_recipient] = $.shares[_recipient] + _shares;

        return $.totalShares;

        // Notice: we're not emitting a Transfer event from the zero address here since shares mint
        // works by taking the amount of tokens corresponding to the minted shares from all other
        // token holders, proportionally to their share. The total supply of the token doesn't change
        // as the result. This is equivalent to performing a send from each other token holder's
        // address to `address`, but we cannot reflect this as it would require sending an unbounded
        // number of events.
    }

    /**
     * @notice Destroys `_shares` shares from `_account`'s holdings, decreasing the total amount of shares.
     * @dev This doesn't decrease the token total supply.
     *
     * Requirements:
     *
     * - `_account` cannot be the zero address.
     * - `_account` must hold at least `_shares` shares.
     * - the contract must not be paused.
     */
    function _burnShares(
        address _account,
        uint256 _shares
    ) internal returns (uint256) {
        if (_account == address(0)) revert Errors.ZeroAddress();

        DineroERC20RebaseStorage storage $ = _getDineroERC20RebaseStorage();

        uint256 accountShares = $.shares[_account];
        if (_shares > accountShares) revert Errors.InvalidAmount();

        uint256 preRebaseTokenAmount = convertToAssets(_shares, true);

        $.totalShares -= _shares;

        $.shares[_account] = accountShares - _shares;

        uint256 postRebaseTokenAmount = convertToAssets(_shares, true);

        emit SharesBurnt(
            _account,
            preRebaseTokenAmount,
            postRebaseTokenAmount,
            _shares
        );

        return $.totalShares;

        // Notice: we're not emitting a Transfer event to the zero address here since shares burn
        // works by redistributing the amount of tokens corresponding to the burned shares between
        // all other token holders. The total supply of the token doesn't change as the result.
        // This is equivalent to performing a send from `address` to each other token holder address,
        // but we cannot reflect this as it would require sending an unbounded number of events.

        // We're emitting `SharesBurnt` event to provide an explicit rebase log record nonetheless.
    }

    /**
     * @dev Emits {Transfer} and {TransferShares} events
     */
    function _emitTransferEvents(
        address _from,
        address _to,
        uint256 _assets,
        uint256 _shares
    ) internal {
        emit Transfer(_from, _to, _assets);
        emit TransferShares(_from, _to, _shares);
    }

    /**
     * @dev Converts `_assets` (pxEth) to shares.
     *
     * @param _assets amount of assets to convert to shares.
     * @param floor if true, the result is rounded down, otherwise it's rounded up.
     */
    function _convertToShares(
        uint256 _assets,
        bool floor
    ) internal view returns (uint256) {
        uint256 totalShares = _getDineroERC20RebaseStorage().totalShares;
        uint256 totalPooledPxEth = _totalAssets();

        if (totalPooledPxEth == 0) return 0;

        return
            floor
                ? _assets.mulDivDown(totalShares, totalPooledPxEth)
                : _assets.mulDivUp(totalShares, totalPooledPxEth);
    }
}
