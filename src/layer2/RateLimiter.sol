// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IRateLimiter} from "./interfaces/IRateLimiter.sol";
import {Constants} from "./libraries/Constants.sol";
import {Errors} from "./libraries/Errors.sol";

/**
 * @title RateLimiter
 * @notice A contract for rate limiting the amount of tokens that can be withdrawn to L1
 * @author dinero.xyz
 */
contract RateLimiter is Ownable, IRateLimiter {
    /**
     * @notice Withdraw limit, used to limit the amount of tokens that can be withdrawn to L1
     * @dev This value increases on deposit messages received from L1 or when the sync pool is synced
     */
    uint256 public withdrawLimit;
    /**
     * @notice The Mode ETH contract address
     */
    address public l2Token;

    constructor() Ownable(msg.sender) {}

    modifier onlyL2Token() {
        if (msg.sender != l2Token) revert Errors.NotAllowed();
        _;
    }

    /**
     * @notice Update the rate limit
     * @param token The token address
     * @param amountIn The amount in
     * @param amountOut The amount out
     */
    function updateRateLimit(
        address,
        address token,
        uint256 amountIn,
        uint256 amountOut
    ) external override onlyL2Token {
        if (token == l2Token) {
            if (amountIn > 0) {
                withdrawLimit += amountIn;
            } else {
                if (withdrawLimit < amountOut) {
                    revert Errors.WithdrawLimitExceeded();
                }
                withdrawLimit -= amountOut;
            }
        } else if (token == Constants.ETH_ADDRESS && amountIn > 0) {
            withdrawLimit += amountIn;
        }
    }

    /**
     * @notice Set the Mode ETH contract address
     * @param _l2Token The Mode ETH contract address
     */
    function setToken(address _l2Token) external onlyOwner {
        l2Token = _l2Token;
    }
}
