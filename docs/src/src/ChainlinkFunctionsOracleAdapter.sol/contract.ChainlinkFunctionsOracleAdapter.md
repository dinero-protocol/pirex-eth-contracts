# ChainlinkFunctionsOracleAdapter
## General Overview
- This contract acts as an intermediary between the Chainlink oracle and the PirexEth system.
- The contract follows the adapter design pattern.
- It can initiate a request for a validator exit using requestVoluntaryExit.
- Chainlink oracle responses are used to dissolve validators in the PirexEth contract.

## Technical Overview
**Inherits:**
[IOracleAdapter](/src/interfaces/IOracleAdapter.sol/interface.IOracleAdapter.md), [FunctionsClient](/src/vendor/chainlink/functions/FunctionsClient.sol/abstract.FunctionsClient.md), AccessControl


## State Variables
### pirexEth

```solidity
IPirexEth public pirexEth;
```


### subscriptionId

```solidity
uint64 public subscriptionId;
```


### gasLimit

```solidity
uint32 public gasLimit;
```


### requestIdToValidatorPubKey

```solidity
mapping(bytes32 => bytes) public requestIdToValidatorPubKey;
```


### source

```solidity
string public source;
```


## Functions
### constructor


```solidity
constructor(address oracle) FunctionsClient(oracle);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`oracle`|`address`|Oracle address|


### setSourceCode

Set source code


```solidity
function setSourceCode(string calldata _source) external onlyRole(DEFAULT_ADMIN_ROLE);
```
**Parameters**

|Name|Type| Description |
|----|----|------------|
|`_source`|`string`|Source code |


### setSubscriptionId

Set subscription identifier


```solidity
function setSubscriptionId(uint64 _subscriptionId) external onlyRole(DEFAULT_ADMIN_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_subscriptionId`|`uint64`|Subscription identifier|


### setGasLimit

Set gas limit


```solidity
function setGasLimit(uint32 _gasLimit) external onlyRole(DEFAULT_ADMIN_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|---------|
|`_gasLimit`|`uint32`|Gas limit|


### requestVoluntaryExit

Send the request for voluntary exit


```solidity
function requestVoluntaryExit(bytes calldata _pubKey) external override;
```
**Parameters**

|Name|Type|Description|
|----|----|--------|
|`_pubKey`|`bytes`|Key|


### fulfillRequest

Fullfil request


```solidity
function fulfillRequest(bytes32 requestId, bytes memory response, bytes memory) internal override;
```
**Parameters**

|Name|Type|Description|
|----|----|--------|
|`requestId`|`bytes32`|Request identifier|
|`response`|`bytes`|Response|
|`<none>`|`bytes`|Override-Required-Placeholder|


### setPirexEth

Set the PirexEth contract address


```solidity
function setPirexEth(address _pirexEth) external onlyRole(DEFAULT_ADMIN_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_pirexEth`|`address`|PirexEth contract address|


## Events
### SetPirexEth

```solidity
event SetPirexEth(address _pirexEth);
```

### RequestValidatorExit

```solidity
event RequestValidatorExit(bytes validatorPubKey);
```

