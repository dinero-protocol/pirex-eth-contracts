# ERC1155Solmate
## General Overview
- The contract for ERC1155 Solmate token (https://github.com/transmissions11/solmate)

## Technical Overview
**Inherits:**
AccessControlDefaultAdminRules, ERC1155

*{ERC1155} token, including:
- ability to check the total supply for a token id
- ability for holders to burn (destroy) their tokens
- a minter role that allows for token minting (creation)
This contract uses {AccessControl} to lock permissioned functions using the
different roles - head to its documentation for details.
The account that deploys the contract will be granted the default admin role,
which will let it grant both minter and burner roles to other accounts.
_Deprecated in favor of https://wizard.openzeppelin.com/[Contracts Wizard]._*


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
constructor(uint48 _initialDelay) AccessControlDefaultAdminRules(_initialDelay, msg.sender);
```

### grantMinterRole

Grant the minter role to an address


```solidity
function grantMinterRole(address minter) external onlyRole(DEFAULT_ADMIN_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`minter`|`address`|Address to grant the minter role|


### revokeMinterRole

Revoke the minter role from an address


```solidity
function revokeMinterRole(address minter) external onlyRole(DEFAULT_ADMIN_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`minter`|`address`|Address to revoke the minter role|


### grantBurnerRole

Grant the burner role to an address


```solidity
function grantBurnerRole(address burner) external onlyRole(DEFAULT_ADMIN_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`burner`|`address`|Address to grant the burner role|


### revokeBurnerRole

Revoke the burner role from an address


```solidity
function revokeBurnerRole(address burner) external onlyRole(DEFAULT_ADMIN_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`burner`|`address`|Address to revoke the burner role|


### mint

*Creates `amount` new tokens for `to`, of token type `id`.
See {ERC1155-_mint}.
Requirements:*
- *the caller must have the `MINTER_ROLE`.*


```solidity
function mint(address to, uint256 id, uint256 amount, bytes calldata data) external onlyRole(MINTER_ROLE);
```

### mintBatch


```solidity
function mintBatch(address to, uint256[] calldata ids, uint256[] calldata amounts, bytes calldata data)
    external
    onlyRole(MINTER_ROLE);
```

### burnBatch


```solidity
function burnBatch(address from, uint256[] calldata ids, uint256[] calldata amounts) external onlyRole(BURNER_ROLE);
```

### burn


```solidity
function burn(address from, uint256 id, uint256 amount) external onlyRole(BURNER_ROLE);
```

### uri


```solidity
function uri(uint256 id) public view override returns (string memory);
```

### supportsInterface


```solidity
function supportsInterface(bytes4 interfaceId)
    public
    pure
    override(AccessControlDefaultAdminRules, ERC1155)
    returns (bool);
```

