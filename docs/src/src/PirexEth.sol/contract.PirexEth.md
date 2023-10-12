# PirexEth
## General Overview
- Main contract for handling interactions with pxETH
- The contract allows depositing ETH to receive pxETH tokens and staking them in the autocompounding vault on behalf of the user.
- It allows pxETH holders to redeem pxETH for ETH or upxETH
- It manages fees for deposit ETH , redemption and instant redemption of pxEth.
## Technical Overview
**Inherits:**
[PirexEthValidators](/src/PirexEthValidators.sol/abstract.PirexEthValidators.md)

**Author:**
redactedcartel.finance


## State Variables
### pirexFees

```solidity
IPirexFees public immutable pirexFees;
```


### maxFees

```solidity
mapping(DataTypes.Fees => uint32) public maxFees;
```


### fees

```solidity
mapping(DataTypes.Fees => uint32) public fees;
```


### paused

```solidity
uint256 public paused;
```


## Functions
### whenNotPaused


```solidity
modifier whenNotPaused();
```

### constructor


```solidity
constructor(
    address _pxEth,
    address _admin,
    address _beaconChainDepositContract,
    address _upxEth,
    uint256 _depositSize,
    uint256 _preDepositAmount,
    address _pirexFees,
    uint48 _initialDelay
)
    PirexEthValidators(_pxEth, _admin, _beaconChainDepositContract, _upxEth, _depositSize, _preDepositAmount, _initialDelay);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_pxEth`|`address`|PxETH contract address|
|`_admin`|`address`|Admin address|
|`_beaconChainDepositContract`|`address`|The address of the beacon chain deposit contract|
|`_upxEth`|`address`|UpxETH address|
|`_depositSize`|`uint256`|Amount of eth to stake|
|`_preDepositAmount`|`uint256`|Amount of ETH for pre-deposit|
|`_pirexFees`|`address`|PirexFees contract address|
|`_initialDelay`|`uint48`|Delay required to schedule the acceptance of a access control transfer started|


### setFee

Set fee


```solidity
function setFee(DataTypes.Fees f, uint32 fee) external onlyRole(GOVERNANCE_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`f`|`DataTypes.Fees`|Fee|
|`fee`|`uint32`|Fee amount|


### setMaxFee

Set Max fee


```solidity
function setMaxFee(DataTypes.Fees f, uint32 maxFee) external onlyRole(GOVERNANCE_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`f`|`DataTypes.Fees`|Fee|
|`maxFee`|`uint32`|Max fee amount|


### togglePauseState

toggle the contract's pause state


```solidity
function togglePauseState() external onlyRole(GOVERNANCE_ROLE);
```

### emergencyWithdraw

Emergency withdrawal for all ERC20 tokens (except pxETH) and ETH

*This function should only be called under major emergency*


```solidity
function emergencyWithdraw(address receiver, address token, uint256 amount)
    external
    onlyRole(GOVERNANCE_ROLE)
    onlyWhenDepositEtherPaused;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`receiver`|`address`|Receiver address|
|`token`|`address`|Token address|
|`amount`|`uint256`|Token amount|


### deposit

Handle pxETH minting in return for ETH deposits


```solidity
function deposit(address receiver, bool shouldCompound)
    external
    payable
    whenNotPaused
    nonReentrant
    returns (uint256 postFeeAmount, uint256 feeAmount);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`receiver`|`address`|Receiver of the minted pxETH or apxEth|
|`shouldCompound`|`bool`|Whether to also compound into the vault|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`postFeeAmount`|`uint256`|pxETH minted for the receiver|
|`feeAmount`|`uint256`|pxETH distributed as fees|


### initiateRedemption

Initiate redemption by burning pxETH in return for upxETH


```solidity
function initiateRedemption(uint256 _assets, address _receiver, bool _shouldTriggerValidatorExit)
    external
    override
    whenNotPaused
    nonReentrant
    returns (uint256 postFeeAmount, uint256 feeAmount);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_assets`|`uint256`|If caller is AutoPxEth then apxETH; pxETH otherwise|
|`_receiver`|`address`|Receiver for upxETH|
|`_shouldTriggerValidatorExit`|`bool`|Whether the initiation should trigger voluntary exit|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`postFeeAmount`|`uint256`|pxETH burnt for the receiver|
|`feeAmount`|`uint256`|pxETH distributed as fees|


### redeemWithUpxEth

Redeem back ETH using upxEth


```solidity
function redeemWithUpxEth(uint256 _tokenId, uint256 _assets, address _receiver) external whenNotPaused nonReentrant;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_tokenId`|`uint256`|Redeem batch identifier|
|`_assets`|`uint256`|Amount of ETH to redeem|
|`_receiver`|`address`|Address of the ETH receiver|


### instantRedeemWithPxEth

Instant redeem back ETH using pxETH


```solidity
function instantRedeemWithPxEth(uint256 _assets, address _receiver)
    external
    whenNotPaused
    nonReentrant
    returns (uint256 postFeeAmount, uint256 feeAmount);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_assets`|`uint256`|Amount of pxETH to redeem|
|`_receiver`|`address`|Address of the ETH receiver|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`postFeeAmount`|`uint256`|Post-fee amount for the receiver|
|`feeAmount`|`uint256`|Fee amount sent to the PirexFees|


### _computeAssetAmounts

Compute post-fee asset and fee amounts from a fee type and total assets


```solidity
function _computeAssetAmounts(DataTypes.Fees f, uint256 assets)
    internal
    view
    returns (uint256 postFeeAmount, uint256 feeAmount);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`f`|`DataTypes.Fees`|Fee|
|`assets`|`uint256`|ETH or pxETH asset amount|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`postFeeAmount`|`uint256`|Post-fee asset amount (for mint/burn/claim/etc.)|
|`feeAmount`|`uint256`|Fee amount|


## Events
### Deposit

```solidity
event Deposit(
    address indexed caller,
    address indexed receiver,
    bool indexed shouldCompound,
    uint256 deposited,
    uint256 receivedAmount,
    uint256 feeAmount
);
```

### InitiateRedemption

```solidity
event InitiateRedemption(uint256 assets, uint256 postFeeAmount, address indexed receiver);
```

### RedeemWithUpxEth

```solidity
event RedeemWithUpxEth(uint256 tokenId, uint256 assets, address indexed receiver);
```

### RedeemWithPxEth

```solidity
event RedeemWithPxEth(uint256 assets, uint256 postFeeAmount, address indexed _receiver);
```

### SetFee

```solidity
event SetFee(DataTypes.Fees indexed f, uint32 fee);
```

### SetMaxFee

```solidity
event SetMaxFee(DataTypes.Fees indexed f, uint32 maxFee);
```

### SetPauseState

```solidity
event SetPauseState(address account, uint256 state);
```

### EmergencyWithdrawal

```solidity
event EmergencyWithdrawal(address indexed receiver, address indexed token, uint256 amount);
```

