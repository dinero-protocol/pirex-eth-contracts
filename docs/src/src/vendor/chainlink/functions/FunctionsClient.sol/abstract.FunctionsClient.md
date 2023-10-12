# FunctionsClient
**Inherits:**
[IFunctionsClient](/src/vendor/chainlink/interfaces/IFunctionsClient.sol/interface.IFunctionsClient.md)

Contract writers can inherit this contract in order to create Chainlink Functions requests


## State Variables
### s_oracle

```solidity
IFunctionsOracle internal s_oracle;
```


### s_pendingRequests

```solidity
mapping(bytes32 => address) internal s_pendingRequests;
```


## Functions
### constructor


```solidity
constructor(address oracle);
```

### getDONPublicKey

Returns the DON's secp256k1 public key used to encrypt secrets

*All Oracles nodes have the corresponding private key
needed to decrypt the secrets encrypted with the public key*


```solidity
function getDONPublicKey() external view override returns (bytes memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes`|publicKey DON's public key|


### estimateCost

Estimate the total cost that will be charged to a subscription to make a request: gas re-imbursement, plus DON fee, plus Registry fee


```solidity
function estimateCost(Functions.Request memory req, uint64 subscriptionId, uint32 gasLimit, uint256 gasPrice)
    public
    view
    returns (uint96);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`req`|`Functions.Request`|The initialized Functions.Request|
|`subscriptionId`|`uint64`|The subscription ID|
|`gasLimit`|`uint32`|gas limit for the fulfillment callback|
|`gasPrice`|`uint256`||

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint96`|billedCost Cost in Juels (1e18) of LINK|


### sendRequest

Sends a Chainlink Functions request to the stored oracle address


```solidity
function sendRequest(Functions.Request memory req, uint64 subscriptionId, uint32 gasLimit) internal returns (bytes32);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`req`|`Functions.Request`|The initialized Functions.Request|
|`subscriptionId`|`uint64`|The subscription ID|
|`gasLimit`|`uint32`|gas limit for the fulfillment callback|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32`|requestId The generated request ID|


### fulfillRequest

User defined function to handle a response


```solidity
function fulfillRequest(bytes32 requestId, bytes memory response, bytes memory err) internal virtual;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`requestId`|`bytes32`|The request ID, returned by sendRequest()|
|`response`|`bytes`|Aggregated response from the user code|
|`err`|`bytes`|Aggregated error from the user code or from the execution pipeline Either response or error parameter will be set, but never both|


### handleOracleFulfillment

Chainlink Functions response handler called by the designated transmitter node in an OCR round.


```solidity
function handleOracleFulfillment(bytes32 requestId, bytes memory response, bytes memory err)
    external
    override
    recordChainlinkFulfillment(requestId);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`requestId`|`bytes32`|The requestId returned by FunctionsClient.sendRequest().|
|`response`|`bytes`|Aggregated response from the user code.|
|`err`|`bytes`|Aggregated error either from the user code or from the execution pipeline. Either response or error parameter will be set, but never both.|


### setOracle

Sets the stored Oracle address


```solidity
function setOracle(address oracle) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`oracle`|`address`|The address of Functions Oracle contract|


### getChainlinkOracleAddress

Gets the stored address of the oracle contract


```solidity
function getChainlinkOracleAddress() internal view returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|The address of the oracle contract|


### addExternalRequest

Allows for a request which was created on another contract to be fulfilled
on this contract


```solidity
function addExternalRequest(address oracleAddress, bytes32 requestId) internal notPendingRequest(requestId);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`oracleAddress`|`address`|The address of the oracle contract that will fulfill the request|
|`requestId`|`bytes32`|The request ID used for the response|


### recordChainlinkFulfillment

*Reverts if the sender is not the oracle that serviced the request.
Emits RequestFulfilled event.*


```solidity
modifier recordChainlinkFulfillment(bytes32 requestId);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`requestId`|`bytes32`|The request ID for fulfillment|


### notPendingRequest

*Reverts if the request is already pending*


```solidity
modifier notPendingRequest(bytes32 requestId);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`requestId`|`bytes32`|The request ID for fulfillment|


## Events
### RequestSent

```solidity
event RequestSent(bytes32 indexed id);
```

### RequestFulfilled

```solidity
event RequestFulfilled(bytes32 indexed id);
```

## Errors
### SenderIsNotRegistry

```solidity
error SenderIsNotRegistry();
```

### RequestIsAlreadyPending

```solidity
error RequestIsAlreadyPending();
```

### RequestIsNotPending

```solidity
error RequestIsNotPending();
```

