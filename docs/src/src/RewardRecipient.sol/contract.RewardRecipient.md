# RewardRecipient
## General Overview
- This contract is responsible for harvesting validators rewards, dissolving and slashing validators and setting protocol’s contracts addresses (OracleAdapter, PirexEth)
- The governance and keeper roles are responsible for managing various operations related to validators and their rewards.
## Technical Overview
**Inherits:**
AccessControlDefaultAdminRules

**Author:**
redactedcartel.finance


## State Variables
### KEEPER_ROLE

```solidity
bytes32 public constant KEEPER_ROLE = keccak256("KEEPER_ROLE");
```


### GOVERNANCE_ROLE

```solidity
bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");
```


### pirexEth

```solidity
IPirexEth public pirexEth;
```


### oracleAdapter

```solidity
IOracleAdapter public oracleAdapter;
```


## Functions
### onlyOracleAdapter


```solidity
modifier onlyOracleAdapter();
```

### constructor


```solidity
constructor(address _admin, uint48 _initialDelay) AccessControlDefaultAdminRules(_initialDelay, _admin);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_admin`|`address`|Admin address|
|`_initialDelay`|`uint48`|Delay required to schedule the acceptance of a access control transfer started|


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


### dissolveValidator

Dissolve validator


```solidity
function dissolveValidator(bytes calldata _pubKey, uint256 _amount) external onlyOracleAdapter;
```
**Parameters**

|Name|Type| Description |
|----|----|-----------|
|`_pubKey`|`bytes`|Public key |
|`_amount`|`uint256`|ETH amount |


### slashValidator

Slash validator


```solidity
function slashValidator(
    bytes calldata _pubKey,
    uint256 _removeIndex,
    uint256 _amount,
    bool _unordered,
    bool _useBuffer,
    DataTypes.BurnerAccount[] calldata _burnerAccounts
) external payable onlyRole(KEEPER_ROLE);
```
**Parameters**

|Name|Type| Description                                |
|----|----|--------------------------------------------|
|`_pubKey`|`bytes`|Public key                                  |
|`_removeIndex`|`uint256`|Validator public key index                  |
|`_amount`|`uint256`|ETH amount released from Beacon chain       |
|`_unordered`|`bool`|Removed in gas efficient way or not         |
|`_useBuffer`|`bool`|Whether to use buffer to compensate the penalty |
|`_burnerAccounts`|`DataTypes.BurnerAccount[]`|Burner accounts                             |


### harvest

Harvest and mint staking rewards


```solidity
function harvest(uint256 _amount, uint256 _endBlock) external onlyRole(KEEPER_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_amount`|`uint256`|Amount of ETH to be harvested|
|`_endBlock`|`uint256`|Block until which ETH rewards are computed|


### receive

Receive MEV rewards


```solidity
receive() external payable;
```

## Events
### SetContract

```solidity
event SetContract(DataTypes.Contract indexed c, address contractAddress);
```

