// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

library Errors {
    /**
     * @notice Zero address specified
     */
    error ZeroAddress();

    /**
     * @notice Zero amount specified
     */
    error ZeroAmount();

    /**
     * @notice Invalid fee specified
     */
    error InvalidFee();

    /**
     * @notice Invalid max fee specified
     */
    error InvalidMaxFee();

    /**
     * @notice Zero multiplier used
     */
    error ZeroMultiplier();

    /**
     * @notice ETH deposit is paused
     */
    error DepositingEtherPaused();

    /**
     * @notice ETH deposit is not paused
     */
    error DepositingEtherNotPaused();

    /**
     * @notice Contract is paused
     */
    error Paused();

    /**
     * @notice Contract is not paused
     */
    error NotPaused();

    /**
     * @notice Validator not yet dissolved
     */
    error NotDissolved();

    /**
     * @notice Validator not yet withdrawable
     */
    error NotWithdrawable();

    /**
     * @notice Validator has been previously used before
     */
    error NoUsedValidator();

    /**
     * @notice Not oracle adapter
     */
    error NotOracleAdapter();

    /**
     * @notice Not reward recipient
     */
    error NotRewardRecipient();

    /**
     * @notice Exceeding max value
     */
    error ExceedsMax();

    /**
     * @notice No rewards available
     */
    error NoRewards();

    /**
     * @notice Not PirexEth
     */
    error NotPirexEth();

    /**
     * @notice Not minter
     */
    error NotMinter();

    /**
     * @notice Not burner
     */
    error NotBurner();

    /**
     * @notice Empty string
     */
    error EmptyString();

    /**
     * @notice Validator is Not Staking
     */
    error ValidatorNotStaking();

    /**
     * @notice not enough buffer
     */
    error NotEnoughBuffer();

    /**
     * @notice validator queue empty
     */
    error ValidatorQueueEmpty();

    /**
     * @notice out of bounds
     */
    error OutOfBounds();

    /**
     * @notice cannot trigger validator exit
     */
    error NoValidatorExit();

    /**
     * @notice cannot initiate redemption partially
     */
    error NoPartialInitiateRedemption();

    /**
     * @notice not enough validators
     */
    error NotEnoughValidators();

    /**
     * @notice not enough ETH
     */
    error NotEnoughETH();

    /**
     * @notice max processed count is invalid (< 1)
     */
    error InvalidMaxProcessedCount();

    /**
     * @notice fromIndex and toIndex are invalid
     */
    error InvalidIndexRanges();

    /**
     * @notice ETH is not allowed
     */
    error NoETHAllowed();

    /**
     * @notice ETH is not passed
     */
    error NoETH();

    /**
     * @notice validator status is neither dissolved nor slashed
     */
    error StatusNotDissolvedOrSlashed();

    /**
     * @notice validator status is neither withdrawable nor staking
     */
    error StatusNotWithdrawableOrStaking();

    /**
     * @notice account is not approved
     */
    error AccountNotApproved();

    /**
     * @notice invalid token specified
     */
    error InvalidToken();

    /**
     * @notice not same as deposit size
     */
    error InvalidAmount();
}
