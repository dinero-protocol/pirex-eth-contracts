// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title IAutoPxEth.
 * @notice Interface for the AutoPxEth contract.
 * @dev This interface defines the methods for interacting with AutoPxEth.
 * @author redactedcartel.finance
 */
interface IAutoPxEth {
    /**
     * @notice Return the amount of assets per 1 (1e18) share.
     * @return uint256 Assets
     */
    function assetsPerShare() external view returns (uint256);

    /**
     * @notice Return the amount of shares owned by an account.
     * @return uint256 Shares
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @notice Deposit pxEth into the apxEth vault.
     * @param  assets    uint256  Assets amount
     * @param  receiver  address  Receiver address
     * @return shares    uint256  Shares
     */
    function deposit(
        uint256 assets,
        address receiver
    ) external returns (uint256 shares);

    /**
     * @notice Withdraw pxEth from the apxEth vault.
     * @param  assets    uint256  Assets amount
     * @param  receiver  address  Receiver address
     * @param  owner     address  Owner address
     * @return shares    uint256  Shares
     */
    function withdraw(
        uint256 assets,
        address receiver,
        address owner
    ) external returns (uint256 shares);

    /**
     * @notice Preview redemption assets amount using the specified shares (with fees)
     * @param  shares  uint256  Shares
     * @return         uint256  Assets
     */
    function previewRedeem(uint256 shares) external view returns (uint256);

    /**
     * @notice Get the amount of shares from the specified assets amount (no fees)
     * @param  assets  uint256  Assets
     * @return         uint256  Shares
     */
    function convertToShares(uint256 assets) external view returns (uint256);

    /**
     * @notice Get the amount of assets from the specified shares amount (no fees)
     * @param  shares  uint256  Shares
     * @return         uint256  Assets
     */
    function convertToAssets(uint256 shares) external view returns (uint256);

    /**
     * @notice Withdrawal penalty percentage.
     */
    function withdrawalPenalty() external view returns (uint256);
}
