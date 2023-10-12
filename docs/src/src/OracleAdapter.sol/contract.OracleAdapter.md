# OracleAdapter
## General Overview
- The contract acts as an intermediary between different contract components, facilitates setting contract addresses, managing access control roles, and handling interactions related to validator exits and dissolution.
- It has permission to interact with PirexEth for notifying validator to voluntary exit.
- It has permission to interact with PirexEth when validator is dissolved.
- ```ORACLE_ROLE``` - permission to update the state of the validator when it is dissolved.

## Technical Overview
**Inherits:**
[IOracleAdapter](/src/interfaces/IOracleAdapter.sol/interface.IOracleAdapter.md), AccessControlDefaultAdminRules


## State Variables
### pirexEth

```solidity
IPirexEth public pirexEth;
```


### rewardRecipient

```solidity
IRewardRecipient public rewardRecipient;
```


### ORACLE_ROLE

```solidity
bytes32 public constant ORACLE_ROLE = keccak256("ORACLE_ROLE");
```


### GOVERNANCE_ROLE

```solidity
bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");
```


## Functions
### constructor


```solidity
constructor(uint48 _initialDelay) AccessControlDefaultAdminRules(_initialDelay, msg.sender);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_initialDelay`|`uint48`|Delay required to schedule the acceptance|


### setContract

Set a contract address


```solidity
function setContract(DataTypes.Contract c, address contractAddress) external onlyRole(GOVERNANCE_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`c`|`DataTypes.Contract`|Contract|
|`contractAddress`|`address`|Contract address|


### requestVoluntaryExit

Send the request for voluntary exit


```solidity
function requestVoluntaryExit(bytes calldata _pubKey) external override;
```
**Parameters**

|Name|Type| Description |
|----|----|------------|
|`_pubKey`|`bytes`|Public key  |


### dissolveValidator

Dissolve validator


```solidity
function dissolveValidator(bytes calldata _pubKey, uint256 _amount) external onlyRole(ORACLE_ROLE);
```
**Parameters**

|Name|Type| Description |
|----|----|-----------|
|`_pubKey`|`bytes`|Public key |
|`_amount`|`uint256`|ETH amount |


## Events
### SetContract

```solidity
event SetContract(DataTypes.Contract indexed c, address contractAddress);
```

### RequestValidatorExit

```solidity
event RequestValidatorExit(bytes pubKey);
```

### SetPirexEth

```solidity
event SetPirexEth(address _pirexEth);
```

