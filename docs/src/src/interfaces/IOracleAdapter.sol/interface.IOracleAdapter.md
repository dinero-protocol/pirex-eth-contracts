# IOracleAdapter

## General Overview
- This interface provides a standardized way for contracts to interact with oracle adapters that manage the process of requesting voluntary exits for validators in the Ethereum 2.0 network.
- It enables the integration of off-chain data and interactions with the blockchain.

## Technical Overview
## Functions
### requestVoluntaryExit

Request voluntary exit


```solidity
function requestVoluntaryExit(bytes calldata _pubKey) external;
```
**Parameters**

|Name|Type|Description|
|----|----|--------|
|`_pubKey`|`bytes`|Key|


