<img width="100%" alt="image" src="https://github.com/user-attachments/assets/bf998d9e-fa14-4221-9c94-a2c3818fb41b">

# L2 Branded ETH
`brandedETH` is a rebasing Ethereum liquid staking token used within a Layer 2 ecosystem. Branded ETH benefits from `apxETH` yield and maintains an 1:1 redemption rate with `pxETH`.

## Overview
The `LiquidStakingToken` contract is the extension of the `PirexETH` protocol on a Layer 2 (L2) ecosystem. Instead of holding the `AutoPxEth` vault shares on Layer 1 (L1), users can hold the liquid staking token (LST) on L2 and benefit from the `apxETH` yield. 

The LST can be obtained by performing a deposit on either L1 or L2. On L1, the accepted tokens include Ether, `pxETH`, and `apxETH`, while on L2, whitelisted token such as `ETH` and `WETH` are accepted. Unlike deposits, the withdrawals can be initiated exclusively from the L2 side. In exchange for the LST, users receive the same amount of `pxETH`, in a 1:1 ratio. The `pxETH` can be redeemed for Ether at any time, and the redemption rate is always 1:1.

## Architecture
The following sections delve into the system’s components and their interactions. The diagram below showcases a high-level view of the system’s architecture.

<img width="100%" alt="image" src="https://github.com/user-attachments/assets/7e3c6900-8299-4294-8b3f-b8c2ae298061">

Fig. 1: L2 `brandedETH` architecture

### Deposit
**Layer 1 deposits** are facilitated through the `LiquidStakingTokenLockbox` contract. The Lockbox is responsible for handling the Ether, `pxETH`, and `apxETH` token deposits into the `PirexETH` protocol. Communication between L1 and L2 is done with the LayerZero messaging system. During the deposit, the Lockbox sends the LayerZero message to the L2 chain containing the deposit amount, current `assetsPerShare`, receiver address and the lastest fully synced batches. The `LiquidStakingToken` contract that receives this message on L2 can use the provided information to mint an appropriate amount of LST shares as well as perform a rebase using the new `assetsPerShare` ratio from the `AutoPxEth` vault.

<img width="100%" alt="image" src="https://github.com/user-attachments/assets/5502bb51-946f-4f26-bbac-5d263178a173">

Fig. 2: Mainnet Deposit flow

**Layer 2 deposits** are facilitated through the `LiquidStakingToken` contract using the logic of `L2SyncPool` contract. Since the L2 Ether cannot immediately be used for staking in the `PirexETH` protocol, it must be first bridged to the L1 Ether via the native Layer 2 bridge. The L2 deposits are batched together and sent to L1 during the cross-chain syncing process. The synchronization mechanism itself is explained in greater detail in the Synchronization section. Once Ether is released from the L1 native bridge, it is deposited into the `PirexETH` protocol to start the Ether staking process. The validator staking rewards generate the yield for the LST and `apxETH` token holders.

<img width="70%" alt="image" src="https://github.com/user-attachments/assets/8c025a0d-966b-4a0b-9730-46af71063a69">

Fig. 3: Layer 2 Deposit flow

### Rebase
Whenever new rewards are distributed into the `AutoPxEth` vault through the Harvest process, the price of an individual `apxETH` share increases. Since LST shares are L2 representations of the `apxETH` shares, this share price increase must also be reflected on the Layer 2 chain. The rebase mechanism informs the L2 about the newest `assetsPerShare` ratio from the `AutoPxEth` vault. The current L1 share price is used to update the internal accounting on L2. Similarly to the synchronization mechanism, calling `LiquidStakingTokenLockbox.rebase(...)` is permissionless but will be regularly called by the Keeper.

<img width="85%" alt="image" src="https://github.com/user-attachments/assets/2f3bcda0-ad49-418d-b981-dcc42af7a66e">

Fig. 4: Rebase flow

### Synchronization
The L1 chain is unaware of the user deposits on L2 until the two chains are synchronized. The syncing process can be done by calling the `LiquidStakingToken.sync(...)` function. To keep the chain states up to date, the off-chain keeper will trigger the synchronization regularly. This action is permissionless, meaning that anyone can call the sync(...) function once a certain threshold of deposits is reached (`minSyncAmount`).
The synchronization mechanism is split into two parts: the slow sync and the fast sync. 

<img width="100%" alt="image" src="https://github.com/user-attachments/assets/7a57cd37-139f-4197-9280-5cd75750b25c">

Fig. 5: Sync flow

**The slow sync** process sends the native Layer 2 Ether or `WETH` to Layer 1 over the native bridge. Due to the nature of optimistic rollups and the design of the fault-proof system, this process can take up to 7 days to finalize (for OP Stack-based rollups). The message won’t be relayed during that time, and the Ether won’t be released on L1. To mitigate this limitation the message is sent via LayerZero omnichain messaging protocol to inform the L1 about the deposit on L2, this process is called fast sync.

**The fast sync** The `LiquidStakingTokenLockbox` contract receives this message and mints `pxETH` tokens in anticipation of the Ether that is yet to be released from the bridge. The newly minted `pxETH` tokens stay in the contract, where they wait for the slow sync process to finish. If, during the waiting period, users request withdrawals on L2, whenever possible, they will be provided with the `pxETH` tokens from the Lockbox first instead of withdrawing funds from the `AutoPxEth` vault. The fast sync mechanism enables immediate liquidity for the L2 users without affecting the existing `AutoPxEth` deposits before the actual Ether arrives from the bridge.

### Withdraw
Unlike deposits, withdrawals can only be initiated on the L2 side. Users can call the `LiquidStakingToken.withdraw(...)` function and specify the amount of assets that they want to withdraw. Their LST shares will be burned on L2, and a withdrawal message will be sent to L1 via LayerZero. Once the `LiquidStakingTokenLockbox` contract receives the message, it will transfer the `pxETH` tokens to the user on L1. As mentioned in the previous section, the Lockbox will first attempt to use all the `pxETH` that it currently holds, and only after that will it start withdrawing additional `pxETH` tokens from the vault.

<img width="100%" alt="image" src="https://github.com/user-attachments/assets/6a60d845-447a-4023-b832-5198f3ce1624">

Fig. 6: Withdraw flow

## Known Issues
### Pirex ETH Liquidity
While `brandedETH` is immediately minted on the L2 network, the actual `ETH` is batched and sent over the native bridge. This means there is a period where `pxETH` is minted, but the `ETH` is not yet available in the `PirexETH` contract. Although users should receive the full withdrawal in `pxETH` at all times, attempts to redeem `pxETH` for `ETH` before the `ETH` is available may fail. This will depend on the redemption size and the amount of `ETH` deposited into the `PirexETH` validators.

### L2 `ETH` Yield Dilution
`brandedETH` users' balances are adjusted according to the yield accrued in the `apxETH` vault, which is determined by `ETH` rewards from `PirexETH` validators that increase the vault's `assetsPerShare` ratio. From the perspective of `brandedETH` users, yield can start accruing immediately after a deposit through a rebase. However, since the `ETH` deposited direclty on L2 is not immediately available to stake due to the native bridge delay, the yield gets diluted. This dilution issue is constrained to `brandedETH` users because the deposit into the `apxETH` vault is delayed until `ETH` reaches L1, and the `assetsPerShare` ratio synced between L1 and L2 considers balances in `apxETH` and `pxETH` held by the lockbox.

### Out of Gas During Withdrawal
Pending sync batches amounts are consumed during the withdrawal through the `syncIndexPendingAmount` array. If there are many pending syncs, A large withdrawal would cause iterating over many items of the array, which would cost much gas, and could block users from withdrawing due to out-of-gas error. The likelihood of this scenario happening is directly correlated with the `minSyncAmount` set by the protocol team. The protocol team should set the `minSyncAmount` and monitor L2 deposits to ensure the system can handle large withdrawal amounts.

### Oracle Dependency
Users are dependent on the `L2ExchangeRateProvider` contract `assetsPerShare` ratio of the `AutoPxEth` vault at the time of the deposit. If the oracle fails to provide the correct data, the system may not function as expected. The protocol team should monitor the oracle and ensure that it is functioning correctly.

### Delayed Rebase
If the rebase is not called for a long time, the `assetsPerShare` ratio on L2 will be outdated. This could lead to a discrepancy between the actual `AutoPxEth` vault yield and the yield accrued by the `brandedETH` holders, affecting negatively users' yield. The protocol team should monitor the rebase calls and ensure that they are called regularly and close to Harvest events.

### PirexETH Deposit Fee Increase
Increase in the `PirexETH` deposit fee, while there are `ETH` pending deposits in the native bridge, could lead to unbacked `pxETH` tokens. The tokens can be minted if the deposit fee (on PirexEth) is increased between the delivery of fast and slow sync messages. This would happen because the amount of `pxETH` minted after the fast message is received would be higher than the amount of `pxETH` burned when the slow message is received. While `PirexETH` team does not plan to increase the deposit fee, the protocol team should monitor the deposit fee and ensure that it is not increased while there are pending deposits in the native bridge.