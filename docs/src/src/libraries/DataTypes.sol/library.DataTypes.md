# DataTypes
## General Overview
- This library defines various custom data structures and enums that can be used to represent different aspects of the pxETH system
- It provides a way to organize and store data related to validators, fees, contract types, statuses, and fee recipients.

## Technical Overview
## Structs
### Validator

```solidity
struct Validator {
    bytes pubKey;
    bytes signature;
    bytes32 depositDataRoot;
    address receiver;
}
```

### ValidatorDeque

```solidity
struct ValidatorDeque {
    int128 _begin;
    int128 _end;
    mapping(int128 => Validator) _validators;
}
```

### BurnerAccount

```solidity
struct BurnerAccount {
    address account;
    uint256 amount;
}
```

## Enums
### Fees

```solidity
enum Fees {
    Deposit,
    Redemption,
    InstantRedemption
}
```

### Contract

```solidity
enum Contract {
    PxEth,
    UpxEth,
    AutoPxEth,
    OracleAdapter,
    PirexEth,
    RewardRecipient
}
```

### ValidatorStatus

```solidity
enum ValidatorStatus {
    None,
    Staking,
    Withdrawable,
    Dissolved,
    Slashed
}
```

### FeeRecipient

```solidity
enum FeeRecipient {
    Treasury,
    Contributors
}
```

