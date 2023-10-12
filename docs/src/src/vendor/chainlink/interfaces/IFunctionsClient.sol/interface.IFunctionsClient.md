# IFunctionsClient

## Functions
### getDONPublicKey

Returns the DON's secp256k1 public key used to encrypt secrets

*All Oracles nodes have the corresponding private key
needed to decrypt the secrets encrypted with the public key*


```solidity
function getDONPublicKey() external view returns (bytes memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes`|publicKey DON's public key|


### handleOracleFulfillment

Chainlink Functions response handler called by the designated transmitter node in an OCR round.


```solidity
function handleOracleFulfillment(bytes32 requestId, bytes memory response, bytes memory err) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`requestId`|`bytes32`|The requestId returned by FunctionsClient.sendRequest().|
|`response`|`bytes`|Aggregated response from the user code.|
|`err`|`bytes`|Aggregated error either from the user code or from the execution pipeline. Either response or error parameter will be set, but never both.|


