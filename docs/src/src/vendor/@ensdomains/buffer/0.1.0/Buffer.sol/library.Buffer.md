# Buffer
*A library for working with mutable byte buffers in Solidity.
Byte buffers are mutable and expandable, and provide a variety of primitives
for appending to them. At any time you can fetch a bytes object containing the
current contents of the buffer. The bytes object should not be stored between
operations, as it may change due to resizing of the buffer.*


## Functions
### init

*Initializes a buffer with an initial capacity.*


```solidity
function init(buffer memory buf, uint256 capacity) internal pure returns (buffer memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`buf`|`buffer`|The buffer to initialize.|
|`capacity`|`uint256`|The number of bytes of space to allocate the buffer.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`buffer`|The buffer, for chaining.|


### fromBytes

*Initializes a new buffer from an existing bytes object.
Changes to the buffer may mutate the original value.*


```solidity
function fromBytes(bytes memory b) internal pure returns (buffer memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`b`|`bytes`|The bytes object to initialize the buffer with.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`buffer`|A new buffer.|


### resize


```solidity
function resize(buffer memory buf, uint256 capacity) private pure;
```

### truncate

*Sets buffer length to 0.*


```solidity
function truncate(buffer memory buf) internal pure returns (buffer memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`buf`|`buffer`|The buffer to truncate.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`buffer`|The original buffer, for chaining..|


### append

*Appends len bytes of a byte string to a buffer. Resizes if doing so would exceed
the capacity of the buffer.*


```solidity
function append(buffer memory buf, bytes memory data, uint256 len) internal pure returns (buffer memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`buf`|`buffer`|The buffer to append to.|
|`data`|`bytes`|The data to append.|
|`len`|`uint256`|The number of bytes to copy.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`buffer`|The original buffer, for chaining.|


### append

*Appends a byte string to a buffer. Resizes if doing so would exceed
the capacity of the buffer.*


```solidity
function append(buffer memory buf, bytes memory data) internal pure returns (buffer memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`buf`|`buffer`|The buffer to append to.|
|`data`|`bytes`|The data to append.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`buffer`|The original buffer, for chaining.|


### appendUint8

*Appends a byte to the buffer. Resizes if doing so would exceed the
capacity of the buffer.*


```solidity
function appendUint8(buffer memory buf, uint8 data) internal pure returns (buffer memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`buf`|`buffer`|The buffer to append to.|
|`data`|`uint8`|The data to append.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`buffer`|The original buffer, for chaining.|


### append

*Appends len bytes of bytes32 to a buffer. Resizes if doing so would
exceed the capacity of the buffer.*


```solidity
function append(buffer memory buf, bytes32 data, uint256 len) private pure returns (buffer memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`buf`|`buffer`|The buffer to append to.|
|`data`|`bytes32`|The data to append.|
|`len`|`uint256`|The number of bytes to write (left-aligned).|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`buffer`|The original buffer, for chaining.|


### appendBytes20

*Appends a bytes20 to the buffer. Resizes if doing so would exceed
the capacity of the buffer.*


```solidity
function appendBytes20(buffer memory buf, bytes20 data) internal pure returns (buffer memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`buf`|`buffer`|The buffer to append to.|
|`data`|`bytes20`|The data to append.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`buffer`|The original buffer, for chhaining.|


### appendBytes32

*Appends a bytes32 to the buffer. Resizes if doing so would exceed
the capacity of the buffer.*


```solidity
function appendBytes32(buffer memory buf, bytes32 data) internal pure returns (buffer memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`buf`|`buffer`|The buffer to append to.|
|`data`|`bytes32`|The data to append.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`buffer`|The original buffer, for chaining.|


### appendInt

*Appends a byte to the end of the buffer. Resizes if doing so would
exceed the capacity of the buffer.*


```solidity
function appendInt(buffer memory buf, uint256 data, uint256 len) internal pure returns (buffer memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`buf`|`buffer`|The buffer to append to.|
|`data`|`uint256`|The data to append.|
|`len`|`uint256`|The number of bytes to write (right-aligned).|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`buffer`|The original buffer.|


## Structs
### buffer
*Represents a mutable buffer. Buffers have a current value (buf) and
a capacity. The capacity may be longer than the current value, in
which case it can be extended without the need to allocate more memory.*


```solidity
struct buffer {
    bytes buf;
    uint256 capacity;
}
```

