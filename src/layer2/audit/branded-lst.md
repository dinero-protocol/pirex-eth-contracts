# Dinero Bounty Details - Branded LST

(This is a product-specific subpage, for financial aspect of this bug bounty, navigate to main.md)

## Publicly Known Issues

- All issues submitted via wardens and the Blue Team during this Code4rena Blue engagement will be added to this [project list]() weekly.

- **Centralization Risks**: Some methods (specially `upgradeAndCall`) are only accessible by the Dinero DAO multisig, which is the sole owner of the contracts. This is acceptable as the multisig is controlled by the Dinero DAO, which is a decentralized organization. These methods would only be used for emergency purposes, such as in the event of a critical bug or a hack.

- **Pirex ETH Liquidity**: While `brandedETH` is immediately minted on the L2 network, the actual `ETH` is batched and sent over the native bridge. This means there is a period where `pxETH` is minted, but the `ETH` is not yet available in the `PirexETH` contract. Although users should receive the full withdrawal in `pxETH` at all times, attempts to redeem `pxETH` for `ETH` before the `ETH` is available may fail. This will depend on the redemption size and the amount of `ETH` deposited into the `PirexETH` validators.

- **Branded LST Yield Dilution**: `brandedETH` users' balances are adjusted according to the yield accrued in the `apxETH` vault, which is determined by `ETH` rewards from `PirexETH` validators that increase the vault's `assetsPerShare` ratio. From the perspective of `brandedETH` users, yield can start accruing immediately after a deposit through a rebase. However, since the `ETH` deposited direclty on L2 is not immediately available to stake due to the native bridge delay, the yield gets diluted. This dilution issue is constrained to `brandedETH` users because the deposit into the `apxETH` vault is delayed until `ETH` reaches L1, and the `assetsPerShare` ratio synced between L1 and L2 considers balances in `apxETH` and `pxETH` held by the lockbox.

- **Out of Gas During Withdrawal**: Pending sync batches amounts are consumed during the withdrawal through the `syncIndexPendingAmount` array. If there are many pending syncs, A large withdrawal would cause iterating over many items of the array, which would cost much gas, and could block users from withdrawing due to out-of-gas error. The likelihood of this scenario happening is directly correlated with the `minSyncAmount` set by the protocol team. The protocol team should set the `minSyncAmount` and monitor L2 deposits to ensure the system can handle large withdrawal amounts.

- **Oracle Dependency**: Users rely on the `L2ExchangeRateProvider` contract to fetch the `assetsPerShare` ratio of the AutoPxEth vault during deposits. If the oracle fails to provide accurate data, it could severely impact both users and the protocol. Potential consequences include discrepancies in asset valuation or unbacked Branded LST tokens. The protocol team must monitor the oracle closely to ensure its accuracy and reliability, as failures could compromise the system's integrity and user trust.

- **Delayed Rebase**: If the rebase is not called for a long time, the `assetsPerShare` ratio on L2 will be outdated. This could lead to a discrepancy between the actual `AutoPxEth` vault yield and the yield accrued by the `brandedETH` holders, affecting negatively users' yield. The protocol team should monitor the rebase calls and ensure that they are called regularly and close to Harvest events.

- **PirexETH Deposit Fee Increase**: Increase in the `PirexETH` deposit fee, while there are `ETH` pending deposits in the native bridge, could lead to unbacked `pxETH` tokens. The tokens can be minted if the deposit fee (on PirexEth) is increased between the delivery of fast and slow sync messages. This would happen because the amount of `pxETH` minted after the fast message is received would be higher than the amount of `pxETH` burned when the slow message is received. While `PirexETH` team does not plan to increase the deposit fee, the protocol team should monitor the deposit fee and ensure that it is not increased while there are pending deposits in the native bridge.

> Note: We have acknowledged all findings in referenced [Audits](branded-lst.md#L58
) and have either fixed them or have mitigated them. These functions are required for the protocol to work as intended.

# Branded LST Overview

The Branded LST is an extension of the `PirexETH` protocol on a Layer 2 (L2) ecosystem. Instead of holding the `AutoPxEth` vault shares on Layer 1 (L1), users can hold the liquid staking token (LST) on L2 and benefit from the `apxETH` yield. 

The LST can be obtained by performing a deposit on either L1 or L2. On L1, the accepted tokens include Ether, `pxETH`, and `apxETH`, while on L2, whitelisted token such as Ether and `WETH` are accepted. Unlike deposits, the withdrawals can be initiated exclusively from the L2 side. In exchange for the LST, users receive the same amount of `pxETH`, in a 1:1 ratio. The `pxETH` can be redeemed for Ether at any time, and the redemption rate is always 1:1 on Pirex ETH protocol.

### Tokenization

- **brandedLST** is a rebasing Ethereum liquid staking token native to a Layer 2 ecosystem. Branded ETH benefits from `apxETH` yield and maintains an 1:1 redemption rate with `pxETH`. Rebases are permissionless and triggered on mainnet to adjust the `assetsPerShare` ratio on L2.

- **wBrandedLST** is a wrapped version of brandedLST that can be used in DeFi applications. It is minted by depositing brandedLST into the `WrappedLiquidStakedToken` contract. The minted wBrandedLST can be used in DeFi applications, such as lending, borrowing, and trading.

- **Branded LST OFT** is the 1:1 representation of wBrandedLST on another L2 chain. It is minted by depositing wBrandedLST into the `OFTLockbox` contract. The minted Branded LST OFT can be used in DeFi applications on the other L2 chain.

## Architecture
The following sections delve into the system’s components and their interactions. The diagram below showcases a high-level view of the system’s architecture.

<img width="100%" alt="image" src="https://github.com/user-attachments/assets/cf37d8d8-1660-4ac5-9a74-04b70e85ba71">

Fig. 1: L2 `brandedETH` architecture

### Deposit
**Layer 1 deposits** are facilitated through the `LiquidStakingTokenLockbox` contract. The Lockbox is responsible for handling the Ether, `pxETH`, and `apxETH` token deposits into the `PirexETH` protocol. Communication between L1 and L2 is done with the LayerZero messaging system. During the deposit, the Lockbox sends the LayerZero message to the L2 chain containing the deposit amount, current `assetsPerShare`, receiver address and the lastest fully synced batches. The `LiquidStakingToken` contract that receives this message on L2 can use the provided information to mint an appropriate amount of LST shares as well as perform a rebase using the new `assetsPerShare` ratio from the `AutoPxEth` vault.

<img width="100%" alt="image" src="https://github.com/user-attachments/assets/1648793f-6909-48d5-809c-c009c24899e4">

Fig. 2: Mainnet Deposit flow

**Layer 2 deposits** are facilitated through the `LiquidStakingToken` contract using the logic of `L2SyncPool` contract. Since the L2 Ether cannot immediately be used for staking in the `PirexETH` protocol, it must be first bridged to the L1 Ether via the native Layer 2 bridge. The L2 deposits are batched together and sent to L1 during the cross-chain syncing process. The synchronization mechanism itself is explained in greater detail in the Synchronization section. Once Ether is released from the L1 native bridge, it is deposited into the `PirexETH` protocol to start the Ether staking process. The validator staking rewards generate the yield for the LST and `apxETH` token holders.

<img width="70%" alt="image" src="https://github.com/user-attachments/assets/59d7154c-56d0-4894-94e4-a6045a6a2733">

Fig. 3: Layer 2 Deposit flow

**Side Layer 2 deposits** are facilitated through the `OFTMinter` contract. The `OFTMinter` contract is responsible for handling the deposits of LiquidStakingTokens between Layer 2s. The `OFTMinter` contract receives a deposit and fowards to the Layer 2. After receiving tha message back from the base Layer 2 the OFTs tokens are minted on the destination chain.

<img width="70%" alt="image" src="https://github.com/user-attachments/assets/353653f7-2874-4468-b056-5e4f362a024d">

Fig. 4: Side Layer 2 Deposit flow

### Rebase
Whenever new rewards are distributed into the `AutoPxEth` vault through the Harvest process, the price of an individual `apxETH` share increases. Since LST shares are L2 representations of the `apxETH` shares, this share price increase must also be reflected on the Layer 2 chain. The rebase mechanism informs the L2 about the newest `assetsPerShare` ratio from the `AutoPxEth` vault. The current L1 share price is used to update the internal accounting on L2. Similarly to the synchronization mechanism, calling `LiquidStakingTokenLockbox.rebase(...)` is permissionless but will be regularly called by the Keeper.

<img width="85%" alt="image" src="https://github.com/user-attachments/assets/77cc6684-eba4-4513-bb34-079b97de5f0d">

Fig. 4: Rebase flow

### Synchronization
The L1 chain is unaware of the user deposits on L2 until the two chains are synchronized. The syncing process can be done by calling the `LiquidStakingToken.sync(...)` function. To keep the chain states up to date, the off-chain keeper will trigger the synchronization regularly. This action is permissionless, meaning that anyone can call the sync(...) function once a certain threshold of deposits is reached (`minSyncAmount`).
The synchronization mechanism is split into two parts: the slow sync and the fast sync. 

<img width="100%" alt="image" src="https://github.com/user-attachments/assets/3f3f7185-635b-460c-96f5-c1e1d3393bd4">

Fig. 5: Sync flow

**The slow sync** process sends the native Layer 2 Ether or `WETH` to Layer 1 over the native bridge. Due to the nature of optimistic rollups and the design of the fault-proof system, this process can take up to 7 days to finalize (for OP Stack-based rollups). The message won’t be relayed during that time, and the Ether won’t be released on L1. To mitigate this limitation the message is sent via LayerZero omnichain messaging protocol to inform the L1 about the deposit on L2, this process is called fast sync.

**The fast sync** The `LiquidStakingTokenLockbox` contract receives this message and mints `pxETH` tokens in anticipation of the Ether that is yet to be released from the bridge. The newly minted `pxETH` tokens stay in the contract, where they wait for the slow sync process to finish. If, during the waiting period, users request withdrawals on L2, whenever possible, they will be provided with the `pxETH` tokens from the Lockbox first instead of withdrawing funds from the `AutoPxEth` vault. The fast sync mechanism enables immediate liquidity for the L2 users without affecting the existing `AutoPxEth` deposits before the actual Ether arrives from the bridge.

### Withdraw
Unlike deposits, withdrawals can only be initiated on the L2 side. Users can call the `LiquidStakingToken.withdraw(...)` function and specify the amount of assets that they want to withdraw. Their LST shares will be burned on L2, and a withdrawal message will be sent to L1 via LayerZero. Once the `LiquidStakingTokenLockbox` contract receives the message, it will transfer the `pxETH` tokens to the user on L1. As mentioned in the previous section, the Lockbox will first attempt to use all the `pxETH` that it currently holds, and only after that will it start withdrawing additional `pxETH` tokens from the vault.

<img width="100%" alt="image" src="https://github.com/user-attachments/assets/c960316c-1253-4e85-a611-e35573e20ab2">

Fig. 6: Withdraw flow

## Links
- **Previous audits:**
  - [Spearbit - PirexETH](https://github.com/dinero-protocol/audits/blob/master/dinero-pirex-eth/pirex-eth/spearbit.pdf) ([@spearbitdao](https://twitter.com/spearbitdao))
  - [Pashov - PirexETH](https://github.com/dinero-protocol/audits/blob/master/dinero-pirex-eth/pirex-eth/pashov.pdf) ([@pashovkrum](https://twitter.com/pashovkrum))
- **Documentation:**
  - [PirexETH & Dinero Documentation](https://dinero.xyz/docs)
  - [PirexETH Whitepaper](https://dinero.xyz/whitepaper)
  - [Dinero Litepaper](https://github.com/dinero-protocol/dinero-litepaper)
- **Website:** https://dinero.xyz
- **Twitter:** ([@dinero_xyz](https://twitter.com/dinero_xyz))
- **Discord:** https://discord.gg/dineroxyz

# Scope

This is the complete list of what's in scope for this contest:

| File                                               | nSLOC | Purpose                                                                                                                                                                                                                                                             | Capabilities | External Libraries                          |
|----------------------------------------------------|-------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|--------------|--------------------------------------------------|
| src/layer2/DineroERC20RebaseUpgradeable.sol        | 131   | Interest-bearing ERC20-like token for LiquidStakingToken assets. DineroERC20Rebase balances are dynamic and represent the holder's share in the total amount of pxETH assets controlled by the brandedLST.                                                        | 🖥            | openzeppelin-contracts-upgradeable, solmate      |
| src/layer2/L1SyncPool.sol                          | 113   | Base contract for Layer 1 sync pools, Inherited by a lockbox contract that will handle the sync of balances from Layer 2 to Layer 1 anticipating the deposit of tokens during the fast sync and finalizing sync by depositing ETH to Pirex ETH during the slow sync | 🖥💰📤          | openzeppelin                                     |
| src/layer2/L2ExchangeRateProvider.sol              | 44    | Layer 2 contract for exchange rate (assetsPerShare) and fee calculation                                                                                                                                                                                             |              | openzeppelin                                     |
| src/layer2/L2SyncPool.sol                          | 207   | Base contract for Layer 2 sync pools, allows users to deposit tokens on Layer 2, and then sync them to Layer 1. Once enough tokens have been deposited, anyone can trigger a sync to Layer 1.                                                                       | 🖥💰           | openzeppelin                                     |
| src/layer2/LiquidStakingTokenCompose.sol           | 46    | An DineroERC20Rebase OApp contract for handling LST operations between Layer 2 and mainnet. It can send compose calls to allow composability with other Layer 2s.                                                                                                   |              |                                                  |
| src/layer2/LiquidStakingTokenLockbox.sol           | 429   | An OApp contract for handling LST operations between mainnet and Layer 2. It holds pxETH and apxETH shares to enable withdraw of branded LST.                                                                                                                       | 🖥💰           | openzeppelin-contracts-upgradeable, openzeppelin |
| src/layer2/LiquidStakingTokenLockboxCompose.sol    | 494   | An OApp contract for handling LST operations between mainnet and Layer 2. It holds pxETH and apxETH shares to enable withdraw of branded LST. Enables sending compose calls.                                                                                        | 🖥💰           | openzeppelin-contracts-upgradeable, openzeppelin |
| src/layer2/MultichainLockbox.sol                   | 184   | An OApp contract for handling LST operations between mainnet and Layer 2. This contract is responsible for handling deposits of LiquidStakingTokens between mainnet and Layer 2s.                                                                                   | 🖥💰           |                                                  |
| src/layer2/oft/OFTLockbox.sol                      | 96    | The OFTLockbox contract is responsible to hold wLST tokens and mint wLST OFTs on the destination chain.                                                                                                                                                             | 🖥💰           | openzeppelin                                     |
| src/layer2/oft/OFTMinter.sol                       | 76    | A contract for minting OFT tokens on the destination chain.                                                                                                                                                                                                         | 💰            | openzeppelin                                     |
| src/layer2/RateLimiter.sol                         | 31    | A contract for rate limiting the amount of tokens that can be withdrawn to Layer 1                                                                                                                                                                                  |              | openzeppelin                                     |
| src/layer2/receivers/L1ArbReceiverETH.sol          | 36    | This contract receives messages from the Arbitrum based Layer 2 messenger and forwards them to the Layer 1 sync pool                                                                                                                                                | 💰            |                                                  |
| src/layer2/receivers/L1OPReceiverETH.sol           | 35    | This contract receives messages from the Optimism based Layer 2 messenger and forwards them to the Layer 1 sync pool                                                                                                                                                | 💰            |                                                  |
| src/layer2/receivers/L1StargateReceiverETH.sol     | 74    | This contract receives WETH from the stargate bridge, unwraps and forwards them to the Layer 1 sync pool                                                                                                                                                            | 🖥💰           |                                                  |
| src/layer2/receivers/L1ZkReceiverETH.sol           | 123   | This contract receives messages from the ZKSync based Layer 2 messenger and forwards them to the Layer 1 sync pool                                                                                                                                                  | 🖥💰           |                                                  |
| src/layer2/receivers/L2OrbitReceiver.sol           | 76    | This contract receives messages from the Orbit based Layer 3 messenger and forwards them to the Layer 2 Arbitrum receiver                                                                                                                                           | 🖥💰           |                                                  |
| src/layer2/tokens/LiquidStakingTokenArb.sol        | 20    | Inherits LiquidStakingToken to enable sending ETH through Arbitrum native bridge to Layer 1                                                                                                                                                                         |              |                                                  |
| src/layer2/tokens/LiquidStakingTokenNonNative.sol  | 34    | Inherits LiquidStakingToken to enable sending ETH through a bridge adapter (e.g. Stargate) native bridge to Layer 1                                                                                                                                                 |              | openzeppelin                                     |
| src/layer2/tokens/LiquidStakingTokenOP.sol         | 24    | Inherits LiquidStakingToken to enable sending ETH through Optimism native bridge to Layer 1                                                                                                                                                                         |              |                                                  |
| src/layer2/tokens/LiquidStakingTokenOrbit.sol      | 104   | Inherits LiquidStakingToken to enable sending ETH through Orbit chain native bridge to Arbitrum                                                                                                                                                                     |              | openzeppelin                                     |
| src/layer2/tokens/OrbitLST.sol                     | 20    | Inherits LiquidStakingTokenCompose to enable sending ETH through Arbitrum native bridge to Layer 1                                                                                                                                                                  |              |                                                  |
| src/layer2/tokens/SuperLST.sol                     | 24    | Inherits LiquidStakingTokenCompose to enable sending ETH through Optimism native bridge to Layer 1                                                                                                                                                                  |              |                                                  |
| src/layer2/tokens/ZKSyncLST.sol                    | 20    | Inherits LiquidStakingTokenCompose to enable sending ETH through ZKSync native bridge to Layer 1.                                                                                                                                                                   |              |                                                  |
| src/layer2/utils/Oracle.sol                        | 33    | Oracle contract for providing assetPerShare feeds.                                                                                                                                                                                                                  | 🧮            | openzeppelin                                     |
| src/layer2/utils/stargate/StargateAdapter.sol      | 162   | Bridge adapter to send ETH to mainnet using Stargate bridge.                                                                                                                                                                                                        | 💰            | openzeppelin                                     |
| src/layer2/utils/stargate/StargateBridgeQuoter.sol | 63    | Bridge quoter to get the stargate quote for bridging, used to get the correct amount to deposit.                                                                                                                                                                    |              | openzeppelin, solmate                            |
| src/layer2/WrappedLiquidStakedToken.sol            | 77    | Wraps the LiquidStakingToken contract.                                                                                                                                                                                                                              | 🖥📤           | openzeppelin-contracts-upgradeable               |



This is a list of mainnet contract deployments:
**Plume Staked Ether (pETH)**
| Contract                                    | Deployment                                                                                                                                                | Network          |
|---------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------|------------------|
| src/layer2/LiquidStakingTokenLockbox.sol    | [0x043eF1DC118b5039203AECfAc680CEA4E58b0eBb](https://etherscan.io/address/0x043ef1dc118b5039203aecfac680cea4e58b0ebb)                                     | Ethereum Mainnet |
| src/layer2/receivers/L1ArbReceiverETH.sol   | [0x3dCee1719844bdeBb1536Cf77A3017670AFDF0c5](https://etherscan.io/address/0x3dCee1719844bdeBb1536Cf77A3017670AFDF0c5)                                     | Ethereum Mainnet |
| src/layer2/tokens/LiquidStakingTokenArb.sol | [0xcab283e4bb527Aa9b157Bae7180FeF19E2aaa71a](https://explorer-plume-mainnet-0.t.conduit.xyz/address/0xcab283e4bb527Aa9b157Bae7180FeF19E2aaa71a)           | Plume Mainnet    |
| src/layer2/WrappedLiquidStakedToken.sol     | [0xD630fb6A07c9c723cf709d2DaA9B63325d0E0B73](https://phoenix-explorer.plumenetwork.xyz/address/0xD630fb6A07c9c723cf709d2DaA9B63325d0E0B73?tab=read_proxy) | Plume Mainnet    |
| src/layer2/L2ExchangeRateProvider.sol       | [0x4aC328C4708DbBDbE42E4BB8602e76B6F4dEE34C](https://explorer-plume-mainnet-0.t.conduit.xyz/address/0x4aC328C4708DbBDbE42E4BB8602e76B6F4dEE34C)           | Plume Mainnet    |
| src/layer2/RateLimiter.sol                  | [0x77Cf899591d3258AbC5cFb4Ec3c2b37D4507b0fE](https://explorer-plume-mainnet-0.t.conduit.xyz/address/0x77Cf899591d3258AbC5cFb4Ec3c2b37D4507b0fE)           | Plume Mainnet    |
| src/layer2/utils/Oracle.sol                 | [0x7D7A470b57C7098DB6F95ab3963cE0A85f64b7c7](https://explorer-plume-mainnet-0.t.conduit.xyz/address/0x7D7A470b57C7098DB6F95ab3963cE0A85f64b7c7)           | Plume Mainnet    |

**Ink Staked Ether (iETH)**
| Contract                                   | Deployment                                                                                                                       | Network          |
|--------------------------------------------|----------------------------------------------------------------------------------------------------------------------------------|------------------|
| src/layer2/LiquidStakingTokenLockbox.sol   | [0xf2B2BBdC9975cF680324De62A30a31BC3AB8A4d5](https://etherscan.io/address/0xf2b2bbdc9975cf680324de62a30a31bc3ab8a4d5)            | Ethereum Mainnet |
| src/layer2/receivers/L1OPReceiverETH.sol   | [0x8a6e8E584b415352f7aAef2304945E1772f80378](https://etherscan.io/address/0x8a6e8E584b415352f7aAef2304945E1772f80378)            | Ethereum Mainnet |
| src/layer2/tokens/LiquidStakingTokenOP.sol | [0xcab283e4bb527Aa9b157Bae7180FeF19E2aaa71a](https://explorer.inkonchain.com/address/0xcab283e4bb527Aa9b157Bae7180FeF19E2aaa71a) | Ink Mainnet      |
| src/layer2/WrappedLiquidStakedToken.sol    | [0x11476323D8DFCBAFac942588E2f38823d2Dd308e](https://explorer.inkonchain.com/address/0x11476323D8DFCBAFac942588E2f38823d2Dd308e) | Ink Mainnet      |
| src/layer2/L2ExchangeRateProvider.sol      | [0x4aC328C4708DbBDbE42E4BB8602e76B6F4dEE34C](https://explorer.inkonchain.com/address/0x4aC328C4708DbBDbE42E4BB8602e76B6F4dEE34C) | Ink Mainnet      |
| src/layer2/RateLimiter.sol                 | [0x77Cf899591d3258AbC5cFb4Ec3c2b37D4507b0fE](https://explorer.inkonchain.com/address/0x77Cf899591d3258AbC5cFb4Ec3c2b37D4507b0fE) | Ink Mainnet      |
| src/layer2/utils/Oracle.sol                | [0x7D7A470b57C7098DB6F95ab3963cE0A85f64b7c7](https://explorer.inkonchain.com/address/0x7D7A470b57C7098DB6F95ab3963cE0A85f64b7c7) | Ink Mainnet      |

**ZKSync Staked Ether (zkETH)**
| Contract                                 | Deployment                                                                                                                  | Network          |
|------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------|------------------|
| src/layer2/MultichainLockbox.sol         | [0x96B6AAE5Cdc5B6d2e1aC2EFc46162402F5a868B1](https://etherscan.io/address/0x96B6AAE5Cdc5B6d2e1aC2EFc46162402F5a868B1)       | Ethereum Mainnet |
| src/layer2/receivers/L1ZkReceiverETH.sol | [0x3Be5A22B1B7eBadb8b582Db444cE9e6402E39570](https://etherscan.io/address/0x3Be5A22B1B7eBadb8b582Db444cE9e6402E39570)       | Ethereum Mainnet |
| src/layer2/tokens/ZKSyncLST.sol          | [0x8b73bB0557C151Daa39b6ff556e281e445b296D5](https://explorer.zksync.io/address/0x8b73bB0557C151Daa39b6ff556e281e445b296D5) | ZKSync Era       |
| src/layer2/WrappedLiquidStakedToken.sol  | [0xb72207E1FB50f341415999732A20B6D25d8127aa](https://explorer.zksync.io/address/0xb72207E1FB50f341415999732A20B6D25d8127aa) | ZKSync Era       |
| src/layer2/L2ExchangeRateProvider.sol    | [0x587fA3e78E5de3ae78524Bd3b3A3763e50e50BA9](https://explorer.zksync.io/address/0x587fA3e78E5de3ae78524Bd3b3A3763e50e50BA9) | ZKSync Era       |
| src/layer2/RateLimiter.sol               | [0xC5608A932658b23cA2803e9579ba3577B2B90159](https://explorer.zksync.io/address/0xC5608A932658b23cA2803e9579ba3577B2B90159) | ZKSync Era       |
| src/layer2/utils/Oracle.sol              | [0xEf2cb49a39650E58fc0A2EFe379EA619e47BD052](https://explorer.zksync.io/address/0xEf2cb49a39650E58fc0A2EFe379EA619e47BD052) | ZKSync Era       |

**Flare Staked Ether (flrETH)**
| Contract                                              | Deployment                                                                                                             | Network          |
|-------------------------------------------------------|------------------------------------------------------------------------------------------------------------------------|------------------|
| src/layer2/old/LiquidStakingTokenLockbox.sol          | [0xaAA55490721b72A3112323FC274e9798796CcE85](https://etherscan.io/address/0xaAA55490721b72A3112323FC274e9798796CcE85)  | Ethereum Mainnet |
| src/layer2/receivers/L1StargateReceiverETH.sol        | [0xc8479412404258054bea08ea2E3855C7Ba3b9434](https://etherscan.io/address/0xc8479412404258054bea08ea2E3855C7Ba3b9434)  | Ethereum Mainnet |
| src/layer2/tokens/old/LiquidStakingTokenNonNative.sol | [0x61Ef2d1d8637Dc24e19c2C9dA8f58f6F06C3D31E](https://flarescan.com/address/0x61Ef2d1d8637Dc24e19c2C9dA8f58f6F06C3D31E) | Flare Mainnet    |
| src/layer2/WrappedLiquidStakedToken.sol               | [0x26A1faB310bd080542DC864647d05985360B16A5](https://flarescan.com/address/0x26A1faB310bd080542DC864647d05985360B16A5) | Flare Mainnet    |
| src/layer2/L2ExchangeRateProvider.sol                 | [0xADC20fb7Bc72243675C7cE72cCe8A1B20e2B0E82](https://flarescan.com/address/0xADC20fb7Bc72243675C7cE72cCe8A1B20e2B0E82) | Flare Mainnet    |
| src/layer2/RateLimiter.sol                            | [0xaAA55490721b72A3112323FC274e9798796CcE85](https://flarescan.com/address/0xaAA55490721b72A3112323FC274e9798796CcE85) | Flare Mainnet    |
| src/layer2/utils/Oracle.sol                           | [0xc8479412404258054bea08ea2E3855C7Ba3b9434](https://flarescan.com/address/0xc8479412404258054bea08ea2E3855C7Ba3b9434) | Flare Mainnet    |
| src/layer2/utils/stargate/StargateAdapter.sol         | [0x7D7A470b57C7098DB6F95ab3963cE0A85f64b7c7](https://flarescan.com/address/0x7D7A470b57C7098DB6F95ab3963cE0A85f64b7c7) | Flare Mainnet    |
| src/layer2/utils/stargate/StargateBridgeQuoter.sol    | [0x11476323D8DFCBAFac942588E2f38823d2Dd308e](https://flarescan.com/address/0x11476323D8DFCBAFac942588E2f38823d2Dd308e) | Flare Mainnet    |

## Out of scope

Contracts:

- `BridgeQuoter.sol`

Vendor Libraries:

- `chainlink`
- `solidty-cborutils`
- `layerzero`
- `layerzero-upgradeable`
- `zksync`

# Additional Context

- Trusted Roles

  - `DEFAULT_ADMIN_ROLE`: Set keeper role in the Oracle contract
  - `KEEPER_ROLE`: Set Oracle answer
  - `SYNC_KEEPER`: Execute sync on Layer 2
  - `OWNER`: Set OApp delegate, peers and update key parameters
  - `DELEGATE`: Set OApp configuration

- EIP Specifications:

  - `DineroERC20RebaseUpgradeable`: Should comply with `ERC-20` standard
  - `WrappedLiquidStakedToken`: Should comply with `ERC-20` standard

- In the event of DOS, we would consider a finding to be valid if it is reproducible for a minimum duration of 4 hours.

## Main invariants

- Setting and updating contract addresses (`wLST`, `peers` etc) which are controlled by the `OWNER`
- `brandedLST.totalSupply` should not be greater than `pxETH` equivalent assets in the lockbox (under collateralization)
- `totalShares`
- `totalStaked`
- `unsyncedPendingDeposit`
- `syncedPendingDeposit`
- `pendingDeposit`
- `avgAssetsPerShare`

## Scoping Details

- If you have a public code repo, please share it here: https://github.com/dinero-protocol/pirex-eth-contracts
- How many contracts are in scope?: 27
- Total SLoC for these contracts?: 2776
- How many external imports are there?: 88
- How many separate interfaces and struct definitions are there for the contracts within scope?: 16 interfaces & 20 structs
- Does most of your code generally use composition or inheritance?: Yes, inheritance
- How many external calls?: 1 - Native bridge call (Arbitrum, Optimism, ZKSync), 2 - LayerZero call (`send` and `quote`), 1 Startgate bridge call (`sendToken`)
- What is the overall line coverage percentage provided by your tests?: 99.8%
- Is this an upgrade of an existing system?: No
- Check all that apply (e.g. timelock, NFT, AMM, ERC20, rollups, etc.): ERC-20
- Is there a need to understand a separate part of the codebase / get context in order to audit this part of the protocol?:
- Please describe required context:
- Does it use an oracle?: Yes - Internal oracle to fetch the `assetsPerShare` ratio
- Does it use a side-chain?: Yes
- Describe any specific areas you would like addressed:

## Miscellaneous

Employees of Dinero Protocol, and employees' family members are ineligible for bounties. 