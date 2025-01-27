// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title IDineroERC20
 * @dev Interface for the Dinero ERC20 token.
 * @author redactedcartel.finance
 */
interface IDineroERC20 {
    /**
     * @notice Mints tokens to an address.
     * @dev Only callable by minters.
     * @param _to      address  Address to mint tokens to.
     * @param _amount  uint256  Amount of tokens to mint.
     */
    function mint(address _to, uint256 _amount) external;

    /**
     * @notice Burns tokens from an address.
     * @dev Only callable by burners.
     * @param _from    address  Address to burn tokens from.
     * @param _amount  uint256  Amount of tokens to burn.
     */
    function burn(address _from, uint256 _amount) external;

    /**
     * @dev Sets a `value` amount of tokens as the allowance of `spender` over the caller's tokens.
     * @return a boolean value indicating whether the operation succeeded.
     */
    function approve(address spender, uint256 value) external returns (bool);

    /**
     * @return the value of tokens owned by `account`.
     */
    function balanceOf(address owner) external returns (uint256);

    /**
     * @dev Moves a `value` amount of tokens from the caller's account to `to`.
     *  @return a boolean value indicating whether the operation succeeded.
     */
    function transfer(address to, uint256 amount) external returns (bool);
}
