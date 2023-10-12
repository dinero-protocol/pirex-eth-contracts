# PirexEthValidators
## General Overview
- This contract manages validators and deposits for the Eth2.0 (Beacon chain) deposit contract.
    - It allows governance to set contract addresses, manage validator queues, trigger deposits, manage rewards, handle slashing and top-up operations, and more.
    - Validators are managed through various queues and can be added, swapped, popped, removed, or cleared.
    - Validators can be slashed, dissolved, and topped up based on different conditions.
    - Validators can be redeemed and rewarded with upxEth tokens.
- Handles the MEV, Execution layer and Consensus layer rewards.
- Keeps the status of validators in sync via that on consensus layer.
- ```GOVERNANCE_ROLE``` - manages validator queue, set fee params, pausing deposits to beacon chain deposit contract
- ```KEEPER_ROLE``` - harvest rewards. Update status when a validator is slashed , top up the validator stake when active balance goes below effective balance
- ```DEFAULT_ADMIN_ROLE``` - set the external contract addresses
## Technical Overview
**Inherits:**
ReentrancyGuard, AccessControlDefaultAdminRules, [IPirexEth](/src/interfaces/IPirexEth.sol/interface.IPirexEth.md)

**Author:**
redactedcartel.finance


## State Variables
### DENOMINATOR

```solidity
uint256 public constant DENOMINATOR = 1_000_000;
```


### KEEPER_ROLE

```solidity
bytes32 public constant KEEPER_ROLE = keccak256("KEEPER_ROLE");
```


### GOVERNANCE_ROLE

```solidity
bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");
```


### _NOT_PAUSED

```solidity
uint256 internal constant _NOT_PAUSED = 1;
```


### _PAUSED

```solidity
uint256 internal constant _PAUSED = 2;
```


### beaconChainDepositContract

```solidity
address public immutable beaconChainDepositContract;
```


### preDepositAmount

```solidity
uint256 public immutable preDepositAmount;
```


### DEPOSIT_SIZE

```solidity
uint256 public immutable DEPOSIT_SIZE;
```


### withdrawalCredentials

```solidity
bytes public withdrawalCredentials;
```


### buffer

```solidity
uint256 public buffer;
```


### maxBufferSize

```solidity
uint256 public maxBufferSize;
```


### maxBufferSizePct

```solidity
uint256 public maxBufferSizePct;
```


### maxProcessedValidatorCount

```solidity
uint256 public maxProcessedValidatorCount = 20;
```


### upxEth

```solidity
ERC1155Solmate public upxEth;
```


### pxEth

```solidity
PxEth public pxEth;
```


### autoPxEth

```solidity
AutoPxEth public autoPxEth;
```


### oracleAdapter

```solidity
IOracleAdapter public oracleAdapter;
```


### rewardRecipient

```solidity
address public rewardRecipient;
```


### depositEtherPaused

```solidity
uint256 public depositEtherPaused;
```


### pendingDeposit

```solidity
uint256 public pendingDeposit;
```


### _initializedValidators

```solidity
DataTypes.ValidatorDeque internal _initializedValidators;
```


### _stakingValidators

```solidity
DataTypes.ValidatorDeque internal _stakingValidators;
```


### pendingWithdrawal

```solidity
uint256 public pendingWithdrawal;
```


### outstandingRedemptions

```solidity
uint256 public outstandingRedemptions;
```


### batchId

```solidity
uint256 public batchId;
```


### endBlock

```solidity
uint256 public endBlock;
```


### status

```solidity
mapping(bytes => DataTypes.ValidatorStatus) public status;
```


### batchIdToValidator

```solidity
mapping(uint256 => bytes) public batchIdToValidator;
```


### burnerAccounts

```solidity
mapping(address => bool) public burnerAccounts;
```


## Functions
### onlyRewardRecipient


```solidity
modifier onlyRewardRecipient();
```

### onlyWhenDepositEtherPaused


```solidity
modifier onlyWhenDepositEtherPaused();
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
    uint48 _initialDelay
) AccessControlDefaultAdminRules(_initialDelay, _admin);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_pxEth`|`address`|PxETH contract address|
|`_admin`|`address`|Admin address|
|`_beaconChainDepositContract`|`address`|The address of the deposit precompile|
|`_upxEth`|`address`|UpxETH address|
|`_depositSize`|`uint256`|Amount of ETH to stake|
|`_preDepositAmount`|`uint256`|Amount of ETH for pre-deposit|
|`_initialDelay`|`uint48`|Delay required to schedule the acceptance of a access control transfer started|


### getInitializedValidatorCount

Get the number of initialized validators


```solidity
function getInitializedValidatorCount() external view returns (uint256);
```
**Returns**

|Name|Type| Description                     |
|----|----|---------------------------------|
|`<none>`|`uint256`|Number of initialised validators |


### getStakingValidatorCount

Get the number of staking validators


```solidity
function getStakingValidatorCount() public view returns (uint256);
```
**Returns**

|Name|Type| Description                 |
|----|----|-----------------------------|
|`<none>`|`uint256`|Number of staking validators |


### getInitializedValidatorAt

Get the initialized validator info at the specified index


```solidity
function getInitializedValidatorAt(uint256 _i)
    external
    view
    returns (bytes memory, bytes memory, bytes memory, bytes32, address);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_i`|`uint256`|Index|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes`|Public key|
|`<none>`|`bytes`|Withdrawal credentials|
|`<none>`|`bytes`|Signature|
|`<none>`|`bytes32`|Deposit data root hash|
|`<none>`|`address`|pxETH receiver|


### getStakingValidatorAt

Get the staking validator info at the specified index


```solidity
function getStakingValidatorAt(uint256 _i)
    external
    view
    returns (bytes memory, bytes memory, bytes memory, bytes32, address);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_i`|`uint256`|Index|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes`|Public key|
|`<none>`|`bytes`|Withdrawal credentials|
|`<none>`|`bytes`|Signature|
|`<none>`|`bytes32`|Deposit data root hash|
|`<none>`|`address`|pxETH receiver|


### setContract

Set a contract address


```solidity
function setContract(DataTypes.Contract c, address contractAddress) external onlyRole(GOVERNANCE_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`c`|`DataTypes.Contract`|Contract|
|`contractAddress`|`address`|Contract address|


### setMaxBufferSizePct

Set the percentage that will be applied to
total supply of pxEth to determine maxBufferSize


```solidity
function setMaxBufferSizePct(uint256 _pct) external onlyRole(GOVERNANCE_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_pct`|`uint256`|Max buffer size percentage|


### setMaxProcessedValidatorCount

Set maximum count of processed validator in a _deposit call


```solidity
function setMaxProcessedValidatorCount(uint256 _count) external onlyRole(GOVERNANCE_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_count`|`uint256`|Max processed count|


### togglePauseDepositEther

Toggle allowing depositing ETH to validators


```solidity
function togglePauseDepositEther() external onlyRole(GOVERNANCE_ROLE);
```

### toggleBurnerAccounts

Approve/revoke addresses as burner accounts


```solidity
function toggleBurnerAccounts(address[] calldata _accounts, bool _state) external onlyRole(GOVERNANCE_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_accounts`|`address[]`|Addresses|
|`_state`|`bool`|Burner acount state|


### dissolveValidator

Update validator to Dissolve once Oracle updates on ETH being released


```solidity
function dissolveValidator(bytes calldata _pubKey) external payable override onlyRewardRecipient;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_pubKey`|`bytes`|Public key of the validator|


### slashValidator

Update validator state to be slashed


```solidity
function slashValidator(
    bytes calldata _pubKey,
    uint256 _removeIndex,
    uint256 _amount,
    bool _unordered,
    bool _useBuffer,
    DataTypes.BurnerAccount[] calldata _burnerAccounts
) external payable override onlyRewardRecipient;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_pubKey`|`bytes`|Public key of the validator|
|`_removeIndex`|`uint256`|Index of validator to be slashed|
|`_amount`|`uint256`|ETH amount released from Beacon chain|
|`_unordered`|`bool`|Whether remove from staking validator queue in order or not|
|`_useBuffer`|`bool`|whether to use buffer to compensate the loss|
|`_burnerAccounts`|`DataTypes.BurnerAccount[]`|Burner accounts|


### addInitializedValidators

Add multiple synced validators in the queue to be ready for staking


```solidity
function addInitializedValidators(DataTypes.Validator[] memory _validators)
    external
    onlyWhenDepositEtherPaused
    onlyRole(GOVERNANCE_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_validators`|`DataTypes.Validator[]`|Validators details|


### swapInitializedValidator

Swap initialized validators specified by the indexes


```solidity
function swapInitializedValidator(uint256 _fromIndex, uint256 _toIndex)
    external
    onlyWhenDepositEtherPaused
    onlyRole(GOVERNANCE_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_fromIndex`|`uint256`|From index|
|`_toIndex`|`uint256`|To index|


### popInitializedValidator

Pop initialized validators


```solidity
function popInitializedValidator(uint256 _times) external onlyWhenDepositEtherPaused onlyRole(GOVERNANCE_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_times`|`uint256`|Count of pop operations|


### removeInitializedValidator

Remove initialized validators


```solidity
function removeInitializedValidator(bytes calldata _pubKey, uint256 _removeIndex, bool _unordered)
    external
    onlyWhenDepositEtherPaused
    onlyRole(GOVERNANCE_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_pubKey`|`bytes`||
|`_removeIndex`|`uint256`|Remove index|
|`_unordered`|`bool`|Whether unordered or ordered|


### clearInitializedValidator

Clear initialized validators


```solidity
function clearInitializedValidator() external onlyWhenDepositEtherPaused onlyRole(GOVERNANCE_ROLE);
```

### depositPrivileged

Trigger deposit to the ETH 2.0 deposit contract when allowed


```solidity
function depositPrivileged() external nonReentrant onlyRole(KEEPER_ROLE);
```

### topUpStake

Topup ETH to the validator if current balance drops below effective balance


```solidity
function topUpStake(
    bytes calldata _pubKey,
    bytes calldata _signature,
    bytes32 _depositDataRoot,
    uint256 _topUpAmount,
    bool _useBuffer,
    DataTypes.BurnerAccount[] calldata _burnerAccounts
) external payable nonReentrant onlyRole(KEEPER_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_pubKey`|`bytes`|Validator public key|
|`_signature`|`bytes`|A BLS12-381 signature|
|`_depositDataRoot`|`bytes32`|The SHA-256 hash of the SSZ-encoded DepositData object.|
|`_topUpAmount`|`uint256`|Top-up amount|
|`_useBuffer`|`bool`|Whether to use buffer|
|`_burnerAccounts`|`DataTypes.BurnerAccount[]`|Burner accounts|


### harvest

Harvest and mint staking rewards when available


```solidity
function harvest(uint256 _endBlock) external payable override onlyRewardRecipient;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_endBlock`|`uint256`|Block until which ETH rewards is computed|


### _mintPxEth

Internal method for minting pxETH


```solidity
function _mintPxEth(address _account, uint256 _amount) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_account`|`address`|Account|
|`_amount`|`uint256`|Amount|


### _burnPxEth

Internal method for burning pxETH


```solidity
function _burnPxEth(address _account, uint256 _amount) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_account`|`address`|Account|
|`_amount`|`uint256`|Amount|


### _deposit

Spin up validator if sufficient ETH is available


```solidity
function _deposit() internal;
```

### _addPendingDeposit

Add pending deposit and spin up validator if required ETH available


```solidity
function _addPendingDeposit(uint256 _amount) internal virtual;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_amount`|`uint256`|ETH asset amount|


### _initiateRedemption

Internal handler for validator related logic on redemption


```solidity
function _initiateRedemption(uint256 _pxEthAmount, address _receiver, bool _shouldTriggerValidatorExit) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_pxEthAmount`|`uint256`|Amount of pxETH|
|`_receiver`|`address`|Receiver for upxETH|
|`_shouldTriggerValidatorExit`|`bool`|Whether initiate partial redemption with validator exit or not|


### _updateBuffer


```solidity
function _updateBuffer(uint256 _amount, DataTypes.BurnerAccount[] calldata _burnerAccounts) private;
```

## Events
### ValidatorDeposit

```solidity
event ValidatorDeposit(bytes pubKey);
```

### SetContract

```solidity
event SetContract(DataTypes.Contract indexed c, address contractAddress);
```

### DepositEtherPaused

```solidity
event DepositEtherPaused(uint256 newStatus);
```

### Harvest

```solidity
event Harvest(uint256 amount, uint256 endBlock);
```

### SetMaxBufferSizePct

```solidity
event SetMaxBufferSizePct(uint256 pct);
```

### ApproveBurnerAccount

```solidity
event ApproveBurnerAccount(address indexed account);
```

### RevokeBurnerAccount

```solidity
event RevokeBurnerAccount(address indexed account);
```

### DissolveValidator

```solidity
event DissolveValidator(bytes pubKey);
```

### SlashValidator

```solidity
event SlashValidator(bytes pubKey, bool useBuffer, uint256 releasedAmount, uint256 penalty);
```

### TopUp

```solidity
event TopUp(bytes pubKey, bool useBuffer, uint256 topUpAmount);
```

### SetMaxProcessedValidatorCount

```solidity
event SetMaxProcessedValidatorCount(uint256 count);
```

### UpdateMaxBufferSize

```solidity
event UpdateMaxBufferSize(uint256 maxBufferSize);
```

### SetWithdrawCredentials

```solidity
event SetWithdrawCredentials(bytes withdrawalCredentials);
```

