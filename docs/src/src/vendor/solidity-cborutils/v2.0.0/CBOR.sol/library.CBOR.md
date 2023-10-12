# CBOR
*A library for populating CBOR encoded payload in Solidity.
https://datatracker.ietf.org/doc/html/rfc7049
The library offers various write* and start* methods to encode values of different types.
The resulted buffer can be obtained with data() method.
Encoding of primitive types is staightforward, whereas encoding of sequences can result
in an invalid CBOR if start/write/end flow is violated.
For the purpose of gas saving, the library does not verify start/write/end flow internally,
except for nested start/end pairs.*


## State Variables
### MAJOR_TYPE_INT

```solidity
uint8 private constant MAJOR_TYPE_INT = 0;
```


### MAJOR_TYPE_NEGATIVE_INT

```solidity
uint8 private constant MAJOR_TYPE_NEGATIVE_INT = 1;
```


### MAJOR_TYPE_BYTES

```solidity
uint8 private constant MAJOR_TYPE_BYTES = 2;
```


### MAJOR_TYPE_STRING

```solidity
uint8 private constant MAJOR_TYPE_STRING = 3;
```


### MAJOR_TYPE_ARRAY

```solidity
uint8 private constant MAJOR_TYPE_ARRAY = 4;
```


### MAJOR_TYPE_MAP

```solidity
uint8 private constant MAJOR_TYPE_MAP = 5;
```


### MAJOR_TYPE_TAG

```solidity
uint8 private constant MAJOR_TYPE_TAG = 6;
```


### MAJOR_TYPE_CONTENT_FREE

```solidity
uint8 private constant MAJOR_TYPE_CONTENT_FREE = 7;
```


### TAG_TYPE_BIGNUM

```solidity
uint8 private constant TAG_TYPE_BIGNUM = 2;
```


### TAG_TYPE_NEGATIVE_BIGNUM

```solidity
uint8 private constant TAG_TYPE_NEGATIVE_BIGNUM = 3;
```


### CBOR_FALSE

```solidity
uint8 private constant CBOR_FALSE = 20;
```


### CBOR_TRUE

```solidity
uint8 private constant CBOR_TRUE = 21;
```


### CBOR_NULL

```solidity
uint8 private constant CBOR_NULL = 22;
```


### CBOR_UNDEFINED

```solidity
uint8 private constant CBOR_UNDEFINED = 23;
```


## Functions
### create


```solidity
function create(uint256 capacity) internal pure returns (CBORBuffer memory cbor);
```

### data


```solidity
function data(CBORBuffer memory buf) internal pure returns (bytes memory);
```

### writeUInt256


```solidity
function writeUInt256(CBORBuffer memory buf, uint256 value) internal pure;
```

### writeInt256


```solidity
function writeInt256(CBORBuffer memory buf, int256 value) internal pure;
```

### writeUInt64


```solidity
function writeUInt64(CBORBuffer memory buf, uint64 value) internal pure;
```

### writeInt64


```solidity
function writeInt64(CBORBuffer memory buf, int64 value) internal pure;
```

### writeBytes


```solidity
function writeBytes(CBORBuffer memory buf, bytes memory value) internal pure;
```

### writeString


```solidity
function writeString(CBORBuffer memory buf, string memory value) internal pure;
```

### writeBool


```solidity
function writeBool(CBORBuffer memory buf, bool value) internal pure;
```

### writeNull


```solidity
function writeNull(CBORBuffer memory buf) internal pure;
```

### writeUndefined


```solidity
function writeUndefined(CBORBuffer memory buf) internal pure;
```

### startArray


```solidity
function startArray(CBORBuffer memory buf) internal pure;
```

### startFixedArray


```solidity
function startFixedArray(CBORBuffer memory buf, uint64 length) internal pure;
```

### startMap


```solidity
function startMap(CBORBuffer memory buf) internal pure;
```

### startFixedMap


```solidity
function startFixedMap(CBORBuffer memory buf, uint64 length) internal pure;
```

### endSequence


```solidity
function endSequence(CBORBuffer memory buf) internal pure;
```

### writeKVString


```solidity
function writeKVString(CBORBuffer memory buf, string memory key, string memory value) internal pure;
```

### writeKVBytes


```solidity
function writeKVBytes(CBORBuffer memory buf, string memory key, bytes memory value) internal pure;
```

### writeKVUInt256


```solidity
function writeKVUInt256(CBORBuffer memory buf, string memory key, uint256 value) internal pure;
```

### writeKVInt256


```solidity
function writeKVInt256(CBORBuffer memory buf, string memory key, int256 value) internal pure;
```

### writeKVUInt64


```solidity
function writeKVUInt64(CBORBuffer memory buf, string memory key, uint64 value) internal pure;
```

### writeKVInt64


```solidity
function writeKVInt64(CBORBuffer memory buf, string memory key, int64 value) internal pure;
```

### writeKVBool


```solidity
function writeKVBool(CBORBuffer memory buf, string memory key, bool value) internal pure;
```

### writeKVNull


```solidity
function writeKVNull(CBORBuffer memory buf, string memory key) internal pure;
```

### writeKVUndefined


```solidity
function writeKVUndefined(CBORBuffer memory buf, string memory key) internal pure;
```

### writeKVMap


```solidity
function writeKVMap(CBORBuffer memory buf, string memory key) internal pure;
```

### writeKVArray


```solidity
function writeKVArray(CBORBuffer memory buf, string memory key) internal pure;
```

### writeFixedNumeric


```solidity
function writeFixedNumeric(CBORBuffer memory buf, uint8 major, uint64 value) private pure;
```

### writeIndefiniteLengthType


```solidity
function writeIndefiniteLengthType(CBORBuffer memory buf, uint8 major) private pure;
```

### writeDefiniteLengthType


```solidity
function writeDefiniteLengthType(CBORBuffer memory buf, uint8 major, uint64 length) private pure;
```

### writeContentFree


```solidity
function writeContentFree(CBORBuffer memory buf, uint8 value) private pure;
```

## Structs
### CBORBuffer

```solidity
struct CBORBuffer {
    Buffer.buffer buf;
    uint256 depth;
}
```

