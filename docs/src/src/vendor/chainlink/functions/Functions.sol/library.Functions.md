# Functions

## State Variables
### DEFAULT_BUFFER_SIZE

```solidity
uint256 internal constant DEFAULT_BUFFER_SIZE = 256;
```


## Functions
### encodeCBOR

Encodes a Request to CBOR encoded bytes


```solidity
function encodeCBOR(Request memory self) internal pure returns (bytes memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`self`|`Request`|The request to encode|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes`|CBOR encoded bytes|


### initializeRequest

Initializes a Chainlink Functions Request

*Sets the codeLocation and code on the request*


```solidity
function initializeRequest(Request memory self, Location location, CodeLanguage language, string memory source)
    internal
    pure;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`self`|`Request`|The uninitialized request|
|`location`|`Location`|The user provided source code location|
|`language`|`CodeLanguage`|The programming language of the user code|
|`source`|`string`|The user provided source code or a url|


### initializeRequestForInlineJavaScript

Initializes a Chainlink Functions Request

*Simplified version of initializeRequest for PoC*


```solidity
function initializeRequestForInlineJavaScript(Request memory self, string memory javaScriptSource) internal pure;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`self`|`Request`|The uninitialized request|
|`javaScriptSource`|`string`|The user provided JS code (must not be empty)|


### addRemoteSecrets

Adds Remote user encrypted secrets to a Request


```solidity
function addRemoteSecrets(Request memory self, bytes memory encryptedSecretsURLs) internal pure;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`self`|`Request`|The initialized request|
|`encryptedSecretsURLs`|`bytes`|Encrypted comma-separated string of URLs pointing to off-chain secrets|


### addArgs

Adds args for the user run function


```solidity
function addArgs(Request memory self, string[] memory args) internal pure;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`self`|`Request`|The initialized request|
|`args`|`string[]`|The array of args (must not be empty)|


## Errors
### EmptySource

```solidity
error EmptySource();
```

### EmptyUrl

```solidity
error EmptyUrl();
```

### EmptySecrets

```solidity
error EmptySecrets();
```

### EmptyArgs

```solidity
error EmptyArgs();
```

### NoInlineSecrets

```solidity
error NoInlineSecrets();
```

## Structs
### Request

```solidity
struct Request {
    Location codeLocation;
    Location secretsLocation;
    CodeLanguage language;
    string source;
    bytes secrets;
    string[] args;
}
```

## Enums
### Location

```solidity
enum Location {
    Inline,
    Remote
}
```

### CodeLanguage

```solidity
enum CodeLanguage {JavaScript}
```

