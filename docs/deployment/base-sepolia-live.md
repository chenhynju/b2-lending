# Base Sepolia live deployment

**Status: deployed and functionally verified.** This is an authorized Base Sepolia testnet run of the self-contained demo market. It is not a mainnet deployment, not a production Chainlink market, and not an independent audit.

- Network: Base Sepolia, chain ID `84532`
- Repository: https://github.com/chenhynju/b2-lending
- Live UI: https://b2-lending-app.vercel.app (primary) · https://chenhynju.github.io/b2-lending/ (mirror)
- Deployer: `0x0118e172324801a6333e7d0fAF7f9BB4ED72628F`
- Deployed source commit: `d719c0c4dbce5bbc6b4c86db86dfddfbb41601ac`
- Compiler: Solidity `0.8.38`, optimizer runs `1000`, `via_ir = true`, EVM `cancun`
- Explorer: [Base Sepolia Blockscout](https://base-sepolia.blockscout.com)
- Machine-readable record: [base-sepolia-live.json](../../deployments/base-sepolia-live.json)

The four contracts are the exact `DeployBaseSepoliaDemo.s.sol` fixtures: two free-claim demo ERC20s, an operator-controlled quote, and the immutable `LendingVault`. The script is chain-locked to `84532`; it cannot be reused on another network.

## Funding and faucet check

The deployer address already held enough test ETH, so no additional faucet claim was required. Both incoming funding transactions were verified on-chain.

| Network | Amount | Block | Transaction | Source |
|---|---:|---:|---|---|
| Base Sepolia | 0.01 ETH | 55,184,876 | [`0xa2e13c16...285b7c`](https://base-sepolia.blockscout.com/tx/0xa2e13c16e146216079484e086a6116981c3a9ab6945aaee9d3b30eb9af285b7c) | L2 bridge internal transaction from `0x4200...0010`, 2026-11-06 09:54:04 UTC |
| Ethereum Sepolia | 0.05 ETH | 12,074,682 | [`0xeb57fd76...9d42e1`](https://eth-sepolia.blockscout.com/tx/0xeb57fd762abcf3e513605946bd8dd43b2c13b9eb1e6301c9f3291cc7889d42e1) | Faucet distributor `0x9484449f2BE7CD6E01eF55bC5438C733e0759e0f`, 2026-11-06 06:04:48 UTC |
| Arbitrum Sepolia | 0 | — | — | Not required; the demo contracts are Base Sepolia-only |

Faucet channels checked live on 2026-11-06:

| Faucet | Drip | Eligibility |
|---|---:|---|
| [Chainlink Base Sepolia](https://faucets.chain.link/base-sepolia) | 0.5 ETH | Wallet connection; provider eligibility rules |
| [Alchemy Base Sepolia](https://www.alchemy.com/faucets/base-sepolia) | 0.1 ETH / 24h | Mainnet balance and activity; low testnet balance |
| [Coinbase CDP](https://portal.cdp.coinbase.com/onchain-tools/faucet) | 0.1 ETH / 24h | Login required; also USDC/EURC/cbBTC |
| [thirdweb](https://thirdweb.com/base-sepolia-testnet) | Variable | Listed by Base docs |
| [QuickNode](https://faucet.quicknode.com/base/sepolia) | Variable | Login required |
| [Chainstack](https://faucet.chainstack.com/) | Variable | API key required |
| [Circle USDC](https://faucet.circle.com/) | Test USDC | Base Sepolia; not needed for synthetic demo tokens |

## Deployed contracts

All four transactions succeeded (`status = 1`). Runtime sizes match the local build exactly.

| Contract | Address | Transaction | Block | Gas used | Runtime |
|---|---|---|---:|---:|---:|
| DemoAsset `mUSD` (6 decimals) | [`0x450C689f...cb5D7`](https://base-sepolia.blockscout.com/address/0x450C689f0702Be8AF310A50D7fd6E009Abecb5D7) | [`0x5fd7f58d...e25367`](https://base-sepolia.blockscout.com/tx/0x5fd7f58db67179b5a0616037f22c068e761913bfa0a4482933579bf664e25367) | 55,255,327 | 573,257 | 2,126 B |
| DemoAsset `mETH` (18 decimals) | [`0xcAf05CF9...23DE6`](https://base-sepolia.blockscout.com/address/0xcAf05CF9D12A05B928E6cE473f680A7fd0023DE6) | [`0xe4e80323...4baee4`](https://base-sepolia.blockscout.com/tx/0xe4e803236f49971985c5fea80ada5269a851c8f60881ea5ce547864e234baee4) | 55,255,334 | 573,281 | 2,126 B |
| DemoQuote | [`0xb27100D4...303d7Ab`](https://base-sepolia.blockscout.com/address/0xb27100D4d478A439D31E48d89aA348D33303d7Ab) | [`0xf12f8cbc...a9f365`](https://base-sepolia.blockscout.com/tx/0xf12f8cbc317ddeb5daa036b4ed12da4c2b1376766f0416d122e87ff8a9a9f365) | 55,255,341 | 244,377 | 664 B |
| LendingVault | [`0x4A9c4C10...854999`](https://base-sepolia.blockscout.com/address/0x4A9c4C103EC26ED88528A9c8DAf032BEdB854999) | [`0x31b9b372...39e0a7`](https://base-sepolia.blockscout.com/tx/0x31b9b372446d51fce894b73786c23bc7c5a4b7633ee5b9206b9eb8408339e0a7) | 55,255,352 | 2,558,430 | 10,984 B |

Total deployment gas: **3,949,345**. L2 fee at an effective gas price of `0.006 gwei`: `0.00002369607 ETH`; L1 data fee: `17,621 wei`. Total deployment cost: **`0.000023696087621 ETH`**. The deployer also sent `0.002 ETH` to the functional-test account.

## Initialization and permission checks

| Check | Observed |
|---|---|
| `vault.asset()` | `0x450C689f0702Be8AF310A50D7fd6E009Abecb5D7` (`mUSD`, 6 decimals) |
| `vault.collateralToken()` | `0xcAf05CF9D12A05B928E6cE473f680A7fd0023DE6` (`mETH`, 18 decimals) |
| `vault.oracle()` | `0xb27100D4d478A439D31E48d89aA348D33303d7Ab` (`DemoQuote`) |
| Share decimals | `12` (`assetDecimals + 6`) |
| `assetUnit` / `collateralUnit` | `1e6` / `1e18` |
| `LTV` / liquidation threshold / bonus | `75%` / `80%` / `5%` |
| `borrowIndex` | `1e27` at deployment |
| `quote.operator()` | `0x0118e172324801a6333e7d0fAF7f9BB4ED72628F` |
| `quote.price()` | `2000e18` (`1 mETH = 2000 mUSD`) |
| `quote.MAX_AGE()` | `604800` seconds (7 days) |
| `cash` / `totalSupply` / `totalCollateral` | `0` / `0` / `0` at deployment |
| Owner / admin / upgrade functions in vault ABI | None |
| Unauthorized `setQuote` from a non-operator | Reverts with `Unauthorized` (`0x82b42900`) |

There is no proxy, upgrader, or administrative withdrawal path. The market is immutable, matching the source design.

## Functional verification

A disposable test account (`0xEbf414D54a24620FdAc02ea27EA24A4E2a8d95F0`) executed the core supply/borrow/repay/withdraw lifecycle against the deployed contracts. Every transaction below returned status `1`. Liquidation and bad-debt socialization were covered by the local unit/invariant suites, not by this live demo run. The quote operator is the deployer address `0x0118e172324801a6333e7d0fAF7f9BB4ED72628F`; the local Foundry signing-key file used for deployment is no longer present, and no price change was executed. The live quote therefore reads `2000e18`.

| Step | Transaction | Block | Gas |
|---|---|---:|---:|
| Claim 20,000 mUSD | [`0x2eda525e...623238`](https://base-sepolia.blockscout.com/tx/0x2eda525e02a364480e289d74344afbba5e0062b228f24cfc5e136b8976623238) | 55,256,733 | 89,788 |
| Claim 10 mETH | [`0x491064c3...a35d19`](https://base-sepolia.blockscout.com/tx/0x491064c36ca43231929ffedd4888f39f4d3a7d8a5e295a247f19448b49a35d19) | 55,256,810 | 89,788 |
| Approve 10,000 mUSD | [`0x54249b9a...09c72`](https://base-sepolia.blockscout.com/tx/0x54249b9afa81e3f8b174be9e0b5e07b93f595f4cacc57e0d7204dc672ce09c72) | 55,256,911 | 45,930 |
| Deposit 10,000 mUSD | [`0xc00cc57a...1638b2`](https://base-sepolia.blockscout.com/tx/0xc00cc57a390882839895b728b4559015b597fd8093ede88c5eb5287af81638b2) | 55,257,037 | 151,479 |
| Approve 1 mETH | [`0x2667a53a...72f56c`](https://base-sepolia.blockscout.com/tx/0x2667a53a7f6fa6fa6e2cbf9c0df95eafc1d3b41fb3112f0d43bcd9ab9172f56c) | 55,257,188 | 45,954 |
| Add 1 mETH collateral | [`0x5020068c...05c969`](https://base-sepolia.blockscout.com/tx/0x5020068cda9c250decf8a0e47bae6b8718ee994024eaccb2c878cdfc9105c969) | 55,257,487 | 114,777 |
| Borrow 1,000 mUSD | [`0x7dd22c1c...9f9f0d`](https://base-sepolia.blockscout.com/tx/0x7dd22c1cb14145a4af12d96bca0c7fae4db1dc24c7d27cb36ed1dfd34a9f9f0d) | 55,257,673 | 124,832 |
| Approve 1,100 mUSD for repayment | [`0xabbe1726...c889ea0b`](https://base-sepolia.blockscout.com/tx/0xabbe17267d41c1e4c8acd77aa0cf6811becb51c40933357b8f7a5155c889ea0b) | 55,259,280 | 45,918 |
| Repay 1,000,000,330 mUSD | [`0xc1b49841...40bec1`](https://base-sepolia.blockscout.com/tx/0xc1b49841359a17a883afd6ce73d39d761f3de5998e4b81aead2d4b249940bec1) | 55,259,404 | 79,045 |
| Withdraw 1,000 mUSD | [`0x85dc088e...58608d3`](https://base-sepolia.blockscout.com/tx/0x85dc088e1fb9f459a41c0736db4dd07aba50cc04a066a28ea59091d9558608d3) | 55,262,682 | 84,347 |
| Remove 0.5 mETH collateral | [`0x2e3269ba...232f420a`](https://base-sepolia.blockscout.com/tx/0x2e3269ba1581963b875d9805517030a7c10facd5dcf1467454aaaf3b232f420a) | 55,262,752 | 77,888 |
| Redeem 9,000,000,330 mUSD | [`0xd7bb5eb1...21e9df7`](https://base-sepolia.blockscout.com/tx/0xd7bb5eb1d0abd316bea38c8c98feccb5b2c149e438c76afa6ce19b90221e9df7) | 55,262,948 | 69,467 |

Key observations:

- Deposit of 10,000 mUSD minted `10,000,000,000,000,000` shares (10,000 × 1e12), matching `assetDecimals + 6`.
- After borrowing 1,000 mUSD, debt including accrued interest was `1,000,000,059`; health factor was `1.599999899200006350`; cash was `9,000,000,000`; borrow APR was `3.0000000711%` at 10% utilization.
- Full repayment consumed `1,000,000,330` mUSD (principal + interest) and cleared all debt shares.
- Final vault state: `cash = 0`, `totalSupply = 0`, `totalDebt = 0`, `totalCollateral = 0.5 mETH` (the remaining user collateral).
- Final actor balances: `20,000 mUSD` (full round trip) and `9.5 mETH`; `0.5 mETH` remains locked in the vault by the actor's choice.
- The first repayment attempt reverted during gas estimation with `ERC20InsufficientAllowance`, because the initial 10,000 mUSD allowance had been consumed by the deposit. A second approval was required. This is expected ERC20 behavior, not a contract defect.

## Source verification

**All four contracts verified on Blockscout.** `DemoAsset (mUSD)`, `DemoAsset (mETH)`, `DemoQuote` and `LendingVault` were submitted with ABI-encoded constructor arguments. Earlier attempts hit Blockscout rate limits; the final `LendingVault` submission was accepted and reported `Pass - Verified` (GUID `4a9c4c103ec26ed88528a9c8daf032bedb8549996aeeb387`).

Logs: [verify.log](../../evidence/base-sepolia-live/verify.log) · [verify-remaining.log](../../evidence/base-sepolia-live/verify-remaining.log) · [verify-retry.log](../../evidence/base-sepolia-live/verify-retry.log) · [verify-vault.log](../../evidence/base-sepolia-live/verify-vault.log) · [verify-vault-now.log](../../evidence/base-sepolia-live/verify-vault-now.log) · [verify-sourcify.log](../../evidence/base-sepolia-live/verify-sourcify.log). Command sequence: [verify-source.sh](../../evidence/base-sepolia-live/verify-source.sh).

## Runtime bytecode equality

The deployed runtime code was re-fetched with `eth_getCode` on 2026-11-07 and compared with the local Foundry artifact for all four contracts. Immutable reference ranges were zeroed on both sides before comparison; runtime sizes and immutable values were also checked.

| Contract | Runtime bytes | Immutable slots | Masked equality |
|---|---:|---:|---|
| LendingVault | 10,984 | 22 | PASS |
| DemoQuote | 664 | 2 | PASS |
| DemoAsset (mUSD) | 2,126 | 3 | PASS |
| DemoAsset (mETH) | 2,126 | 3 | PASS |

Live state read in the same run: quote price `2000e18`, operator `0x0118e172324801a6333e7d0fAF7f9BB4ED72628F` (the deployer), `updatedAt` `2026-11-06T13:48:57Z`; vault cash `0`, `totalCollateral` `0.5 mETH`. Raw output: [bytecode-equality.json](../../evidence/base-sepolia-live/bytecode-equality.json).

## Live UI hosting

- **Vercel:** project `b2-lending-app`, root directory `apps/web`, build command `cp config.live.json config.json`, output directory `.`. Production URL: https://b2-lending-app.vercel.app. The project is connected to the GitHub repository and redeploys on `main`.
- **GitHub Pages mirror:** workflow [pages.yml](../../.github/workflows/pages.yml) copies the same live config and publishes `apps/web`; URL: https://chenhynju.github.io/b2-lending/.
- The live config contains only public addresses and token metadata. The page never receives a private key; all signatures happen in the browser wallet.

## Reproduction notes

- The environment used Foundry `1.8.1` and Solidity `0.8.38`; dependencies are vendored.
- The local WSL network is routed through a Windows-side HTTP CONNECT proxy because the host VPN does not expose its routes to WSL. This is an environment workaround, not part of the protocol.
- Only Base Sepolia signing and broadcasting were authorized. No mainnet transaction was created.
- The demo tokens and quote have no real value. The demo quote operator is the deployer address; a controlled liquidation would require that wallet to sign `setQuote`, which was not part of this run.

## Limitations

- The demo quote is not a Chainlink feed and has no sequencer-uptime protection. The production `FeedOracle` path remains unexercised on a public network.
- The demo assets are freely claimable and not transfer-tax or rebasing tokens.
- All four contracts are verified on Blockscout. Earlier rate-limit failures are retained in the logs and are not presented as successful runs.
- Runtime bytecode equality was re-checked on 2026-11-07 for all four contracts; the raw comparison is recorded in [bytecode-equality.json](../../evidence/base-sepolia-live/bytecode-equality.json).
- The live demo did not exercise liquidation, bad-debt socialization or a price change. Those paths are covered by local and fork tests. A controlled liquidation requires the deployer/operator wallet to sign `setQuote`, so it is not demonstrated on this deployment.
- The working tree contains pre-existing test/evidence changes. The deployed `src/` bytecode corresponds to the frozen production source; the demo fixture contracts live in `script/DeployBaseSepoliaDemo.s.sol`.
