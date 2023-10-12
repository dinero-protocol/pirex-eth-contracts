// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Ownable2Step} from "openzeppelin-contracts/contracts/access/Ownable2Step.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {DataTypes} from "./libraries/DataTypes.sol";
import {Errors} from "./libraries/Errors.sol";

/// @title  Handling protocol fees distributions
/// @author redactedcartel.finance
contract PirexFees is Ownable2Step {
    using SafeTransferLib for ERC20;

    // General constants
    uint8 public constant PERCENT_DENOMINATOR = 100;
    uint8 public constant MAX_TREASURY_FEE_PERCENT = 75;

    // Configurable fee recipient percent-share
    uint8 public treasuryPercent = MAX_TREASURY_FEE_PERCENT;

    // Configurable fee recipient addresses
    address public treasury;
    address public contributors;

    // Events
    event SetFeeRecipient(DataTypes.FeeRecipient f, address recipient);
    event SetTreasuryPercent(uint8 _treasuryPercent);
    event DistributeFees(address token, uint256 amount);

    /**
        @param  _treasury      address  Redacted treasury
        @param  _contributors  address  Pirex contributor multisig
     */
    constructor(address _treasury, address _contributors) {
        if (_treasury == address(0)) revert Errors.ZeroAddress();
        if (_contributors == address(0)) revert Errors.ZeroAddress();

        treasury = _treasury;
        contributors = _contributors;
    }

    /** 
        @notice Set a fee recipient address
        @param  f          enum     FeeRecipient enum
        @param  recipient  address  Fee recipient address
     */
    function setFeeRecipient(
        DataTypes.FeeRecipient f,
        address recipient
    ) external onlyOwner {
        if (recipient == address(0)) revert Errors.ZeroAddress();

        emit SetFeeRecipient(f, recipient);

        if (f == DataTypes.FeeRecipient.Treasury) {
            treasury = recipient;
            return;
        }

        contributors = recipient;
    }

    /** 
        @notice Set treasury fee percent
        @param  _treasuryPercent  uint8  Treasury fee percent
     */
    function setTreasuryPercent(uint8 _treasuryPercent) external onlyOwner {
        // Treasury fee percent should never exceed the pre-configured max value
        if (_treasuryPercent > MAX_TREASURY_FEE_PERCENT)
            revert Errors.InvalidFee();

        treasuryPercent = _treasuryPercent;

        emit SetTreasuryPercent(_treasuryPercent);
    }

    /** 
        @notice Distribute fees
        @param  from    address  Fee source
        @param  token   address  Fee token
        @param  amount  uint256  Fee token amount
     */
    function distributeFees(
        address from,
        address token,
        uint256 amount
    ) external {
        emit DistributeFees(token, amount);

        ERC20 t = ERC20(token);
        uint256 treasuryDistribution = (amount * treasuryPercent) /
            PERCENT_DENOMINATOR;

        // Favoring push over pull to reduce accounting complexity for different tokens
        t.safeTransferFrom(from, treasury, treasuryDistribution);
        t.safeTransferFrom(from, contributors, amount - treasuryDistribution);
    }
}
