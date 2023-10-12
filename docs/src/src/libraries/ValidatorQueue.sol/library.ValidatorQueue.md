# ValidatorQueue
## General Overview
- This library provides a way to manage a queue of validators.
- Validators can be added, swapped, removed, and retrieved from the queue based on specific requirements.
- The methods provided aim to facilitate efficient and organized management of the validator queue within the pxETH smart contract system.

## Technical Overview
## Functions
### add

Add synced validator in the FIFO queue to be ready for staking


```solidity
function add(
    DataTypes.ValidatorDeque storage deque,
    DataTypes.Validator memory validator,
    bytes memory withdrawalCredentials
) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`deque`|`DataTypes.ValidatorDeque`|Deque|
|`validator`|`DataTypes.Validator`|Validator|
|`withdrawalCredentials`|`bytes`|Credentials|


### swap

Swap the location of one validator with another


```solidity
function swap(DataTypes.ValidatorDeque storage deque, uint256 fromIndex, uint256 toIndex) public;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`deque`|`DataTypes.ValidatorDeque`|Deque|
|`fromIndex`|`uint256`|From index|
|`toIndex`|`uint256`|To index|


### pop

Remove validators from the end of queue, in case they were added in error


```solidity
function pop(DataTypes.ValidatorDeque storage deque, uint256 times)
    public
    returns (DataTypes.Validator memory validator);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`deque`|`DataTypes.ValidatorDeque`|Deque|
|`times`|`uint256`|Count of pop operations|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`validator`|`DataTypes.Validator`|Removed and returned validator|


### empty

Return whether the deque is empty


```solidity
function empty(DataTypes.ValidatorDeque storage deque) public view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`deque`|`DataTypes.ValidatorDeque`|Deque|

**Returns**

|Name|Type| Description                           |
|----|----|---------------------------------------|
|`<none>`|`bool`|Boolean for whether the queue is empty |


### removeOrdered

Remove a validator from the array by more gassy loop


```solidity
function removeOrdered(DataTypes.ValidatorDeque storage deque, uint256 removeIndex)
    external
    returns (bytes memory removedPubKey);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`deque`|`DataTypes.ValidatorDeque`|Deque|
|`removeIndex`|`uint256`|Remove index|

**Returns**

|Name|Type| Description |
|----|----|------------|
|`removedPubKey`|`bytes`|Public key  |


### removeUnordered

Remove a validator from the array by swap and pop


```solidity
function removeUnordered(DataTypes.ValidatorDeque storage deque, uint256 removeIndex)
    external
    returns (bytes memory removedPubkey);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`deque`|`DataTypes.ValidatorDeque`|Deque|
|`removeIndex`|`uint256`|Remove index|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`removedPubkey`|`bytes`|Public key|


### getNext

Remove the last validator from the validators array and return its information


```solidity
function getNext(DataTypes.ValidatorDeque storage deque, bytes memory _withdrawalCredentials)
    external
    returns (
        bytes memory pubKey,
        bytes memory withdrawalCredentials,
        bytes memory signature,
        bytes32 depositDataRoot,
        address receiver
    );
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`deque`|`DataTypes.ValidatorDeque`|Deque|
|`_withdrawalCredentials`|`bytes`|Credentials|

**Returns**

|Name|Type| Description         |
|----|----|---------------------|
|`pubKey`|`bytes`|Public key           |
|`withdrawalCredentials`|`bytes`|Credentials          |
|`signature`|`bytes`|Signature            |
|`depositDataRoot`|`bytes32`|Deposit data root    |
|`receiver`|`address`|Account to receive pxEth |


### get

Return the information of the i'th validator in the registry


```solidity
function get(DataTypes.ValidatorDeque storage deque, bytes memory _withdrawalCredentials, uint256 _index)
    external
    view
    returns (
        bytes memory pubKey,
        bytes memory withdrawalCredentials,
        bytes memory signature,
        bytes32 depositDataRoot,
        address receiver
    );
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`deque`|`DataTypes.ValidatorDeque`|Deque|
|`_withdrawalCredentials`|`bytes`|Credentials|
|`_index`|`uint256`|Index|

**Returns**

|Name|Type| Description          |
|----|----|----------------------|
|`pubKey`|`bytes`|Public key            |
|`withdrawalCredentials`|`bytes`|Credentials           |
|`signature`|`bytes`|Signature             |
|`depositDataRoot`|`bytes32`|Deposit data root     |
|`receiver`|`address`|Account to receive pxEth |


### clear

Empties the validator queue


```solidity
function clear(DataTypes.ValidatorDeque storage deque) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`deque`|`DataTypes.ValidatorDeque`|Deque|


### count

Returns the number of validators


```solidity
function count(DataTypes.ValidatorDeque storage deque) public view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`deque`|`DataTypes.ValidatorDeque`|Deque|

**Returns**

|Name|Type| Description             |
|----|----|-------------------------|
|`<none>`|`uint256`|The number of validators |


## Events
### ValidatorAdded

```solidity
event ValidatorAdded(bytes pubKey, bytes withdrawalCredential);
```

### ValidatorQueueCleared

```solidity
event ValidatorQueueCleared();
```

### ValidatorRemoved

```solidity
event ValidatorRemoved(bytes pubKey, uint256 removeIndex, bool unordered);
```

### ValidatorsPopped

```solidity
event ValidatorsPopped(uint256 times);
```

### ValidatorsSwapped

```solidity
event ValidatorsSwapped(bytes fromPubKey, bytes toPubKey, uint256 fromIndex, uint256 toIndex);
```

