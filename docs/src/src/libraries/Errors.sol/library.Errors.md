# Errors
## General Overview
- This library defines various custom error messages to be more descriptive of a scenario and the code conditions.

## Technical Overview
## Errors
### ZeroAddress
Zero address specified


```solidity
error ZeroAddress();
```

### ZeroAmount
Zero amount specified


```solidity
error ZeroAmount();
```

### InvalidFee
Invalid fee specified


```solidity
error InvalidFee();
```

### InvalidMaxFee
Invalid max fee specified


```solidity
error InvalidMaxFee();
```

### ZeroMultiplier
Zero multiplier used


```solidity
error ZeroMultiplier();
```

### DepositingEtherPaused
ETH deposit is paused


```solidity
error DepositingEtherPaused();
```

### DepositingEtherNotPaused
ETH deposit is not paused


```solidity
error DepositingEtherNotPaused();
```

### Paused
Contract is paused


```solidity
error Paused();
```

### NotPaused
Contract is not paused


```solidity
error NotPaused();
```

### NotDissolved
Validator not yet dissolved


```solidity
error NotDissolved();
```

### NotWithdrawable
Validator not yet withdrawable


```solidity
error NotWithdrawable();
```

### NoUsedValidator
Validator has been previously used before


```solidity
error NoUsedValidator();
```

### NotOracleAdapter
Not oracle adapter


```solidity
error NotOracleAdapter();
```

### NotRewardRecipient
Not reward recipient


```solidity
error NotRewardRecipient();
```

### ExceedsMax
Exceeding max value


```solidity
error ExceedsMax();
```

### NoRewards
No rewards available


```solidity
error NoRewards();
```

### NotPirexEth
Not PirexEth


```solidity
error NotPirexEth();
```

### NotMinter
Not minter


```solidity
error NotMinter();
```

### NotBurner
Not burner


```solidity
error NotBurner();
```

### EmptyString
Empty string


```solidity
error EmptyString();
```

### ValidatorNotStaking
Validator is Not Staking


```solidity
error ValidatorNotStaking();
```

### NotEnoughBuffer
not enough buffer


```solidity
error NotEnoughBuffer();
```

### ValidatorQueueEmpty
validator queue empty


```solidity
error ValidatorQueueEmpty();
```

### OutOfBounds
out of bounds


```solidity
error OutOfBounds();
```

### NoValidatorExit
cannot trigger validator exit


```solidity
error NoValidatorExit();
```

### NoPartialInitiateRedemption
cannot initiate redemption partially


```solidity
error NoPartialInitiateRedemption();
```

### NotEnoughValidators
not enough validators


```solidity
error NotEnoughValidators();
```

### NotEnoughETH
not enough ETH


```solidity
error NotEnoughETH();
```

### InvalidMaxProcessedCount
max processed count is invalid (< 1)


```solidity
error InvalidMaxProcessedCount();
```

### InvalidIndexRanges
fromIndex and toIndex are invalid


```solidity
error InvalidIndexRanges();
```

### NoETHAllowed
ETH is not allowed


```solidity
error NoETHAllowed();
```

### NoETH
ETH is not passed


```solidity
error NoETH();
```

### StatusNotDissolvedOrSlashed
validator status is neither dissolved nor slashed


```solidity
error StatusNotDissolvedOrSlashed();
```

### StatusNotWithdrawableOrStaking
validator status is neither withdrawable nor staking


```solidity
error StatusNotWithdrawableOrStaking();
```

### AccountNotApproved
account is not approved


```solidity
error AccountNotApproved();
```

### InvalidToken
invalid token specified


```solidity
error InvalidToken();
```

### InvalidAmount
not same as deposit size


```solidity
error InvalidAmount();
```

