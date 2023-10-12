# IPirexEth

## General Overview
- This interface outlines several functions that can be implemented by contracts to interact with a contract related to the pxETH system.

## Technical Overview
## Functions
### initiateRedemption

Initiate redemption by burning pxETH in return for upxETH


```solidity
function initiateRedemption(uint256 _assets, address _receiver, bool _shouldTriggerValidatorExit)
    external
    returns (uint256 postFeeAmount, uint256 feeAmount);
```
**Parameters**

|Name|Type| Description                                                  |
|----|----|--------------------------------------------------------------|
|`_assets`|`uint256`|If caller is AutoPxEth then apxETH; pxETH otherwise           |
|`_receiver`|`address`|Receiver for upxETH                                 |
|`_shouldTriggerValidatorExit`|`bool`|Whether the initiation should trigger voluntary exit |

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`postFeeAmount`|`uint256`|pxETH burnt for the receiver|
|`feeAmount`|`uint256`|pxETH distributed as fees|


### dissolveValidator

Dissolve validator


```solidity
function dissolveValidator(bytes calldata _pubKey) external payable;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_pubKey`|`bytes`|Key|


### slashValidator

Update validator state to be slashed


```solidity
function slashValidator(
    bytes calldata _pubKey,
    uint256 _removeIndex,
    uint256 _amount,
    bool _unordered,
    bool _useBuffer,
    DataTypes.BurnerAccount[] calldata _burnerAccounts
) external payable;
```
**Parameters**

|Name|Type| Description                                             |
|----|----|---------------------------------------------------------|
|`_pubKey`|`bytes`|Public key of the validator                              |
|`_removeIndex`|`uint256`|Index of validator to be slashed                         |
|`_amount`|`uint256`|ETH amount released from Beacon chain                    |
|`_unordered`|`bool`|Whether remove from staking validator queue in order or not |
|`_useBuffer`|`bool`|Whether to use buffer to compensate the loss             |
|`_burnerAccounts`|`DataTypes.BurnerAccount[]`|Burner accounts               |


### harvest

Harvest and mint staking rewards when available


```solidity
function harvest(uint256 _endBlock) external payable;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_endBlock`|`uint256`|Block until which ETH rewards is computed|


