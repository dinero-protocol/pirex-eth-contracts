# IRewardRecipient
## General Overview
- This interface provides a standardized way for contracts to interact with reward recipient actions within a staking or reward-based protocol.
- Contracts implementing this interface can integrate these actions into their operations, allowing for the proper handling of validator dissolution and slashing while ensuring rewards are sent to the appropriate recipients.

## Technical Overview

## Functions
### dissolveValidator

Dissolve validator


```solidity
function dissolveValidator(bytes calldata _pubKey, uint256 _amount) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_pubKey`|`bytes`|Key|
|`_amount`|`uint256`|ETH amount|


### slashValidator

Slash validator


```solidity
function slashValidator(
    bytes calldata _pubKey,
    uint256 _removeIndex,
    uint256 _amount,
    bool _unordered,
    DataTypes.BurnerAccount[] calldata _burnerAccounts
) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_pubKey`|`bytes`|Key|
|`_removeIndex`|`uint256`|Validator public key index|
|`_amount`|`uint256`|ETH amount|
|`_unordered`|`bool`|Removed in gas efficient way or not|
|`_burnerAccounts`|`DataTypes.BurnerAccount[]`|Burner accounts|


