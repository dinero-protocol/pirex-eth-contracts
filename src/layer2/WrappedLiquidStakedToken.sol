// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {ILiquidStakingToken} from "./interfaces/ILiquidStakingToken.sol";
import {ERC20PermitUpgradeable, Initializable} from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import {Errors} from "./libraries/Errors.sol";

/**
 * @title WrappedLiquidStakedToken
 * @notice Wraps the LiquidStakingToken contract.
 * @author redactedcartel.finance
 */
contract WrappedLiquidStakedToken is Initializable, ERC20PermitUpgradeable {
    /*//////////////////////////////////////////////////////////////
                            WLST STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @custom:storage-location erc7201:redacted.storage.WrappedLiquidStakedToken
    struct WLSTStorage {
        /**
         * @notice The LiquidStakingToken contract.
         * @dev This is the LiquidStakingToken contract that the WrappedLiquidStakedToken wraps.
         */
        ILiquidStakingToken lst;
    }

    // keccak256(abi.encode(uint256(keccak256(redacted.storage.WrappedLiquidStakedToken)) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant WLSTStorageLocation =
        0xddf967707f52bbdea6c202114c491d81e6de0cb9ded430e88a276a6f8d3e3800;

    function _getWrappedLiquidStakedTokenStorage()
        private
        pure
        returns (WLSTStorage storage $)
    {
        assembly {
            $.slot := WLSTStorageLocation
        }
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /*//////////////////////////////////////////////////////////////
                               INITIALIZER
    //////////////////////////////////////////////////////////////*/

    function initialize(
        address lst_,
        string memory name_,
        string memory symbol_
    ) external initializer {
        __WrappedLiquidStakedToken_init(lst_, name_, symbol_);
    }

    function __WrappedLiquidStakedToken_init(
        address lst_,
        string memory name_,
        string memory symbol_
    ) internal onlyInitializing {
        WLSTStorage storage wlst = _getWrappedLiquidStakedTokenStorage();
        wlst.lst = ILiquidStakingToken(lst_);

        // Set decoded values for name and symbol.
        __ERC20_init_unchained(name_, symbol_);

        // Set the name for EIP-712 signature.
        __ERC20Permit_init(name_);
    }

    /*//////////////////////////////////////////////////////////////
                               WRAPPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Wraps the LiquidStakingToken into WrappedLiquidStakedToken.
     * @param _amount The amount of LiquidStakingToken to wrap.
     * @return shares The amount of WrappedLiquidStakedToken shares minted.
     */
    function wrap(uint256 _amount) external returns (uint256) {
        if (_amount == 0) {
            revert Errors.ZeroAmount();
        }

        WLSTStorage storage $ = _getWrappedLiquidStakedTokenStorage();
        ILiquidStakingToken lst = $.lst;

        uint256 shares = lst.convertToShares(_amount);

        _mint(msg.sender, shares);

        lst.transferFrom(msg.sender, address(this), _amount);

        return shares;
    }

    /**
     * @notice Unwraps the WrappedLiquidStakedToken into LiquidStakingToken.
     * @param _amount The amount of WrappedLiquidStakedToken shares to unwrap.
     * @return assets The amount of LiquidStakingToken assets received.
     */
    function unwrap(uint256 _amount) external returns (uint256) {
        if (_amount == 0) {
            revert Errors.ZeroAmount();
        }

        WLSTStorage storage $ = _getWrappedLiquidStakedTokenStorage();
        ILiquidStakingToken lst = $.lst;

        uint256 assets = lst.convertToAssets(_amount, true);

        _burn(msg.sender, _amount);

        lst.transfer(msg.sender, assets);

        return assets;
    }

    /*//////////////////////////////////////////////////////////////
                               VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the amount of WrappedLiquidStakedToken shares that corresponds to `_lstAmount` LiquidStakingToken.
     * @param _lstAmount The amount of LiquidStakingToken.
     * @return shares The amount of WrappedLiquidStakedToken shares.
     */
    function getWrappedLSTAmount(
        uint256 _lstAmount
    ) external view returns (uint256) {
        return
            _getWrappedLiquidStakedTokenStorage().lst.convertToShares(
                _lstAmount
            );
    }

    /**
     * @notice Returns the amount of LiquidStakingToken assets that corresponds to `_wlstAmount` WrappedLiquidStakedToken shares.
     * @param _wlstAmount The amount of WrappedLiquidStakedToken shares.
     * @return assets The amount of LiquidStakingToken assets.
     */
    function getLSTAmount(uint256 _wlstAmount) external view returns (uint256) {
        return
            _getWrappedLiquidStakedTokenStorage().lst.convertToAssets(
                _wlstAmount,
                true
            );
    }

    /**
     * @notice Returns the amount of LiquidStakingToken assets that corresponds to 1 WrappedLiquidStakedToken share.
     * @return assets The amount of LiquidStakingToken assets.
     */
    function LSTPerToken() external view returns (uint256) {
        return
            _getWrappedLiquidStakedTokenStorage().lst.convertToAssets(
                1 ether,
                true
            );
    }

    /**
     * @notice Returns the amount of WrappedLiquidStakedToken shares that corresponds to 1 LiquidStakingToken asset.
     * @return shares The amount of WrappedLiquidStakedToken shares.
     */
    function tokensPerLST() external view returns (uint256) {
        return
            _getWrappedLiquidStakedTokenStorage().lst.convertToShares(1 ether);
    }

    /**
     * @notice Returns the LiquidStakingToken contract address.
     * @return lst The LiquidStakingToken contract address.
     */
    function getLSTAddress() external view returns (address) {
        return address(_getWrappedLiquidStakedTokenStorage().lst);
    }
}
