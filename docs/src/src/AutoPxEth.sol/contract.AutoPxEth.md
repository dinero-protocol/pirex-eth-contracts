# AutoPxEth
## General Overview
- Autocompounding vault for (staked) pxETH, adapted from pxCVX vault system
- The contract provides a mechanism for users to stake and unstake pxETH tokens.
    - Accepts pxETH deposits, and issues share tokens (apxEth) against them
- It compounds pxEth rewards into more pxEth by harvesting ETH rewards (MEV, Consensus layer and Execution layer).
    - Rewards are streamed over time based on a set rewards rate and duration.
    - Harvesting of rewards is done by the contract, and a platform fee is deducted before rewards are compounded.
- Provides a series of permissioned methods that enables the Pirex multisig to configure platform(vault's fees recipient), PirexEth contract, withdraw penalty and platformFee.
- Modifies transfer and transferFrom method to initiateRedemption if apxEth are transferred to PirexEth.

## Technical Overview
**Inherits:**
Ownable2Step, ERC4626

**Author:**
redactedcartel.finance


## State Variables
### MAX_WITHDRAWAL_PENALTY

```solidity
uint256 public constant MAX_WITHDRAWAL_PENALTY = 50_000;
```


### MAX_PLATFORM_FEE

```solidity
uint256 public constant MAX_PLATFORM_FEE = 200_000;
```


### FEE_DENOMINATOR

```solidity
uint256 public constant FEE_DENOMINATOR = 1_000_000;
```


### REWARDS_DURATION

```solidity
uint256 public constant REWARDS_DURATION = 7 days;
```


### pirexEth

```solidity
IPirexEth public pirexEth;
```


### periodFinish

```solidity
uint256 public periodFinish;
```


### rewardRate

```solidity
uint256 public rewardRate;
```


### lastUpdateTime

```solidity
uint256 public lastUpdateTime;
```


### rewardPerTokenStored

```solidity
uint256 public rewardPerTokenStored;
```


### rewardPerTokenPaid

```solidity
uint256 public rewardPerTokenPaid;
```


### rewards

```solidity
uint256 public rewards;
```


### totalStaked

```solidity
uint256 public totalStaked;
```


### withdrawalPenalty

```solidity
uint256 public withdrawalPenalty = 30_000;
```


### platformFee

```solidity
uint256 public platformFee = 100_000;
```


### platform

```solidity
address public platform;
```


## Functions
### updateReward

Update reward states


```solidity
modifier updateReward(bool updateEarned);
```
**Parameters**

|Name|Type| Description                           |
|----|----|---------------------------------------|
|`updateEarned`|`bool`|Whether to update earned amount so far |


### constructor


```solidity
constructor(address _asset, address _platform) ERC4626(ERC20(_asset), "Autocompounding Pirex Ether", "apxETH");
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_asset`|`address`|Asset contract address|
|`_platform`|`address`|Platform address|


### setPirexEth

Set the PirexEth contract address


```solidity
function setPirexEth(address _pirexEth) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_pirexEth`|`address`|PirexEth contract address|


### setWithdrawalPenalty

Set the withdrawal penalty


```solidity
function setWithdrawalPenalty(uint256 penalty) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`penalty`|`uint256`|Withdrawal penalty|


### setPlatformFee

Set the platform fee


```solidity
function setPlatformFee(uint256 fee) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`fee`|`uint256`|Platform fee|


### setPlatform

Set the platform


```solidity
function setPlatform(address _platform) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|----------|
|`_platform`|`address`|Platform|


### notifyRewardAmount

Notify and sync the newly added rewards to be streamed over time

*Rewards are streamed following the duration set in REWARDS_DURATION*


```solidity
function notifyRewardAmount() external updateReward(false);
```

### totalAssets

Get the amount of available pxETH in the contract

*Rewards are streamed for the duration set in REWARDS_DURATION*


```solidity
function totalAssets() public view override returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|----------|
|`<none>`|`uint256`|Assets|


### lastTimeRewardApplicable

Returns the last effective timestamp of the current reward period


```solidity
function lastTimeRewardApplicable() public view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|----------|
|`<none>`|`uint256`|Timestamp|


### rewardPerToken

Returns the amount of rewards per staked token/asset


```solidity
function rewardPerToken() public view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Rewards amount|


### earned

Returns the earned rewards amount so far


```solidity
function earned() public view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Rewards amount|


### assetsPerShare

Return the amount of assets per 1 (1e18) share


```solidity
function assetsPerShare() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|----------|
|`<none>`|`uint256`|Assets|


### _stake

Intenal method to keep track of the total amount of staked token/asset on deposit/mint


```solidity
function _stake(uint256 amount) internal updateReward(true);
```

### _withdraw

Intenal method to keep track of the total amount of staked token/asset on withdrawal/redeem


```solidity
function _withdraw(uint256 amount) internal updateReward(true);
```

### beforeWithdraw

Deduct the specified amount of assets from totalStaked to prepare for transfer to user


```solidity
function beforeWithdraw(uint256 assets, uint256) internal override;
```
**Parameters**

|Name|Type| Description                  |
|----|----|------------------------------|
|`assets`|`uint256`|Assets                        |
|`<none>`|`uint256`|Override-Required-Placeholder |


### afterDeposit

Include the new assets in totalStaked so that rewards can be properly distributed


```solidity
function afterDeposit(uint256 assets, uint256) internal override;
```
**Parameters**

|Name|Type|Description|
|----|----|---------|
|`assets`|`uint256`|Assets|
|`<none>`|`uint256`|Override-Required-Placeholder|


### previewRedeem

Preview the amount of assets a user would receive from redeeming shares


```solidity
function previewRedeem(uint256 shares) public view override returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|---------|
|`shares`|`uint256`|Shares|

**Returns**

|Name|Type|Description|
|----|----|----------|
|`<none>`|`uint256`|Assets|


### previewWithdraw

Preview the amount of shares a user would need to redeem the specified asset amount

This modified version takes into consideration the withdrawal fee


```solidity
function previewWithdraw(uint256 assets) public view override returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|---------|
|`assets`|`uint256`|Assets|

**Returns**

|Name|Type|Description|
|----|----|----------|
|`<none>`|`uint256`|Shares|


### harvest

Harvest and stake available rewards after distributing fees to platform


```solidity
function harvest() public updateReward(true);
```

### transfer

Override transfer logic for direct `initiateRedemption` trigger


```solidity
function transfer(address to, uint256 amount) public override returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|----------|
|`to`|`address`|Transfer destination|
|`amount`|`uint256`|Amount|

**Returns**

|Name|Type| Description |
|----|----|-------------|
|`<none>`|`bool`|Success flag |


### transferFrom

Override transferFrom logic for direct `initiateRedemption` trigger


```solidity
function transferFrom(address from, address to, uint256 amount) public override returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|----------|
|`from`|`address`|Transfer origin|
|`to`|`address`|Transfer destination|
|`amount`|`uint256`|Amount|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|Success flag |


## Events
### Harvest

```solidity
event Harvest(address indexed caller, uint256 value);
```

### WithdrawalPenaltyUpdated

```solidity
event WithdrawalPenaltyUpdated(uint256 penalty);
```

### PlatformFeeUpdated

```solidity
event PlatformFeeUpdated(uint256 fee);
```

### PlatformUpdated

```solidity
event PlatformUpdated(address _platform);
```

### RewardAdded

```solidity
event RewardAdded(uint256 reward);
```

### SetPirexEth

```solidity
event SetPirexEth(address _pirexEth);
```

