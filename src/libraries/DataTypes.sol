// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

library DataTypes {
    // Validator struct type
    struct Validator {
        bytes pubKey;
        bytes signature;
        bytes32 depositDataRoot;
        address receiver;
    }

    // ValidatorDeque struct type
    struct ValidatorDeque {
        int128 _begin;
        int128 _end;
        mapping(int128 => Validator) _validators;
    }

    // Burner Account Type
    struct BurnerAccount {
        address account;
        uint256 amount;
    }

    // Configurable fees
    enum Fees {
        Deposit,
        Redemption,
        InstantRedemption
    }

    // Configurable contracts
    enum Contract {
        PxEth,
        UpxEth,
        AutoPxEth,
        OracleAdapter,
        PirexEth,
        RewardRecipient
    }

    // Validator statuses
    enum ValidatorStatus {
        // The validator is not staking and has no defined status.
        None,
        // The validator is actively participating in the staking process.
        // It could be in one of the following states: pending_initialized, pending_queued, or active_ongoing.
        Staking,
        // The validator has proceed with the withdrawal process.
        // It represents a meta state for active_exiting, exited_unslashed, and the withdrawal process being possible.
        Withdrawable,
        // The validator's status indicating that ETH is released to the pirexEthValidators
        // It represents the withdrawal_done status.
        Dissolved,
        // The validator's status indicating that it has been slashed due to misbehavior.
        // It serves as a meta state encompassing active_slashed, exited_slashed,
        // and the possibility of starting the withdrawal process (withdrawal_possible) or already completed (withdrawal_done)
        // with the release of ETH, subject to a penalty for the misbehavior.
        Slashed
    }

    // Types of fee recipients
    enum FeeRecipient {
        Treasury,
        Contributors
    }
}
