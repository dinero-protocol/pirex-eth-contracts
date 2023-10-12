# DineroERC20
## General Overview
- This contract extends the ERC20 standard by adding permissioned minting and burning capabilities
- It implements access control mechanisms to restrict who can perform these actions.
- It defines the **`MINTER_ROLE`** and **`BURNER_ROLE`** roles, and only accounts with these roles are allowed to mint and burn tokens, respectively.
- The access control mechanisms are facilitated through the use of OpenZeppelin's AccessControlDefaultAdminRules contract.

## Technical Overview
**Inherits:**
ERC20, AccessControlDefaultAdminRules

**Author:**
redactedcartel.finance


## State Variables
### MINTER_ROLE

```solidity
bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
```


### BURNER_ROLE

```solidity
bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");
```


## Functions
### constructor


```solidity
constructor(string memory _name, string memory _symbol, uint8 _decimals, address _admin, uint48 _initialDelay)
    AccessControlDefaultAdminRules(_initialDelay, _admin)
    ERC20(_name, _symbol, _decimals);
```
**Parameters**

|Name|Type|Description|
|----|----|----------|
|`_name`|`string`|Token name|
|`_symbol`|`string`|Token symbol|
|`_decimals`|`uint8`|Token decimals|
|`_admin`|`address`|Admin address|
|`_initialDelay`|`uint48`|Delay required to schedule the acceptance of a access control transfer started|


### mint

Mints tokens to an address

*Only callable by minters*


```solidity
function mint(address _to, uint256 _amount) external onlyRole(MINTER_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_to`|`address`|Address to mint tokens to|
|`_amount`|`uint256`|Amount of tokens to mint|


### burn

Burns tokens from an address

*Only callable by burners*


```solidity
function burn(address _from, uint256 _amount) external onlyRole(BURNER_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_from`|`address`|Address to burn tokens from|
|`_amount`|`uint256`|Amount of tokens to burn|


