# IPirexFees

## General Overview
- This interface provides a standardized way for contracts to interact with the fee distribution functionality of the pxETH system.
- It allows for the organized distribution of fees among different participants in a consistent manner.

## Technical Overview
## Functions
### distributeFees

Distribute fees


```solidity
function distributeFees(address from, address token, uint256 amount) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`from`|`address`|Fee source|
|`token`|`address`|Fee token|
|`amount`|`uint256`|Fee token amount|


