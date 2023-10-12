# PxEth
## General Overview
- This contract represents the main token for the PirexEth system within the Dinero ecosystem.
    - Is a derivative of the DineroERC20 contract
- The contract introduces an OPERATOR_ROLE that allows certain addresses to perform specific actions - approve allowances between specified accounts.
## Technical Overview
**Inherits:**
[DineroERC20](/src/DineroERC20.sol/contract.DineroERC20.md)

**Author:**
redactedcartel.finance


## State Variables
### OPERATOR_ROLE

```solidity
bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
```


## Functions
### constructor


```solidity
constructor(address _admin, uint48 _initialDelay) DineroERC20("Pirex Ether", "pxETH", 18, _admin, _initialDelay);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_admin`|`address`|Admin address|
|`_initialDelay`|`uint48`|Delay required to schedule the acceptance of a access control transfer started|


### operatorApprove

Approve allowances by operator with specified accounts and amount


```solidity
function operatorApprove(address _from, address _to, uint256 _amount) external onlyRole(OPERATOR_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_from`|`address`|Owner of the tokens|
|`_to`|`address`|Account to be approved|
|`_amount`|`uint256`|Amount to be approved|


