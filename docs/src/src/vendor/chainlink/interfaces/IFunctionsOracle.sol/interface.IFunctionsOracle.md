# IFunctionsOracle

## Functions
### getRegistry

Gets the stored billing registry address


```solidity
function getRegistry() external view returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|registryAddress The address of Chainlink Functions billing registry contract|


### setRegistry

Sets the stored billing registry address


```solidity
function setRegistry(address registryAddress) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`registryAddress`|`address`|The new address of Chainlink Functions billing registry contract|


### getThresholdPublicKey

Returns the DON's threshold encryption public key used to encrypt secrets

*All nodes on the DON have separate key shares of the threshold decryption key
and nodes must participate in a threshold decryption OCR round to decrypt secrets*


```solidity
function getThresholdPublicKey() external view returns (bytes memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes`|thresholdPublicKey the DON's threshold encryption public key|


### setThresholdPublicKey

Sets the DON's threshold encryption public key used to encrypt secrets

*Used to rotate the key*


```solidity
function setThresholdPublicKey(bytes calldata thresholdPublicKey) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`thresholdPublicKey`|`bytes`|The new public key|


### getDONPublicKey

Returns the DON's secp256k1 public key that is used to encrypt secrets

*All nodes on the DON have the corresponding private key
needed to decrypt the secrets encrypted with the public key*


```solidity
function getDONPublicKey() external view returns (bytes memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes`|publicKey the DON's public key|


### setDONPublicKey

Sets DON's secp256k1 public key used to encrypt secrets

*Used to rotate the key*


```solidity
function setDONPublicKey(bytes calldata donPublicKey) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`donPublicKey`|`bytes`|The new public key|


### setNodePublicKey

Sets a per-node secp256k1 public key used to encrypt secrets for that node

*Callable only by contract owner and DON members*


```solidity
function setNodePublicKey(address node, bytes calldata publicKey) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`node`|`address`|node's address|
|`publicKey`|`bytes`|node's public key|


### deleteNodePublicKey

Deletes node's public key

*Callable only by contract owner or the node itself*


```solidity
function deleteNodePublicKey(address node) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`node`|`address`|node's address|


### getAllNodePublicKeys

Return two arrays of equal size containing DON members' addresses and their corresponding
public keys (or empty byte arrays if per-node key is not defined)


```solidity
function getAllNodePublicKeys() external view returns (address[] memory, bytes[] memory);
```

### getRequiredFee

Determine the fee charged by the DON that will be split between signing Node Operators for servicing the request


```solidity
function getRequiredFee(bytes calldata data, IFunctionsBillingRegistry.RequestBilling calldata billing)
    external
    view
    returns (uint96);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`data`|`bytes`|Encoded Chainlink Functions request data, use FunctionsClient API to encode a request|
|`billing`|`IFunctionsBillingRegistry.RequestBilling`|The request's billing configuration|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint96`|fee Cost in Juels (1e18) of LINK|


### estimateCost

Estimate the total cost that will be charged to a subscription to make a request: gas re-imbursement, plus DON fee, plus Registry fee


```solidity
function estimateCost(uint64 subscriptionId, bytes calldata data, uint32 gasLimit, uint256 gasPrice)
    external
    view
    returns (uint96);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`subscriptionId`|`uint64`|A unique subscription ID allocated by billing system, a client can make requests from different contracts referencing the same subscription|
|`data`|`bytes`|Encoded Chainlink Functions request data, use FunctionsClient API to encode a request|
|`gasLimit`|`uint32`|Gas limit for the fulfillment callback|
|`gasPrice`|`uint256`||

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint96`|billedCost Cost in Juels (1e18) of LINK|


### sendRequest

Sends a request (encoded as data) using the provided subscriptionId


```solidity
function sendRequest(uint64 subscriptionId, bytes calldata data, uint32 gasLimit) external returns (bytes32);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`subscriptionId`|`uint64`|A unique subscription ID allocated by billing system, a client can make requests from different contracts referencing the same subscription|
|`data`|`bytes`|Encoded Chainlink Functions request data, use FunctionsClient API to encode a request|
|`gasLimit`|`uint32`|Gas limit for the fulfillment callback|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32`|requestId A unique request identifier (unique per DON)|


