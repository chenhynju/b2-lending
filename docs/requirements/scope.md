# B2 Lending: scope and acceptance
This delivery is the lending series, separate from the AMM and RWA projects. It is an AI-assisted portfolio implementation, not evidence of the owner's independent mastery.

## Included
An immutable isolated loan/collateral market, transferable lender ERC20 shares, collateral custody, indexed debt, kinked utilization APR, third-party debt repayment, independently priced liquidation, explicit loss socialization, dual Chainlink-style feed adapter, sequencer grace period, exact-transfer token checks, local wallet UI and deployment tooling.

## Deliberate exclusions
AMM k/TWAP/LP tokens, an AMM swap UI, pooled multi-collateral risk, rewards/emissions, protocol fees, upgradeability, administrator controls, permissionless asset listing and a protocol-owned flash lending facility. Flash-funded external composition is tested. This vault is not advertised as ERC-4626. B16/B17 concepts are prerequisites; no permit/signature protocol is reimplemented here.

## Acceptance interpretation
- Shares are claims on assets; their **numeric amounts do not equal asset units**. Test sum(balances)=totalSupply and assets=cash+receivables.
- Borrow and collateral withdrawal must satisfy 75% LTV at execution. Exogenous price falls and interest may subsequently make a position unhealthy.
- Liquidation clears residual debt when collateral is exhausted and recognizes lender losses. It cannot ensure zero economic loss during arbitrary market gaps.
- Full LP exit means exit after borrowers repay or bad debt is settled, with sufficient idle cash. It is not a promise of unconditional liquidity.
- Unit → bounded fuzz → four-actor handler/ghost invariants → pinned real-state fork.
- A timed changing-seed campaign must actually run at least 1,800 seconds after compilation.
- Public Base Sepolia transactions require explicit authorization under AGENTS.md §8.4. No public transaction is part of this local delivery.
- Post-scope update (2026-11-06): an authorized Base Sepolia **demo** deployment was executed; see [base-sepolia-live.md](../deployment/base-sepolia-live.md). The production FeedOracle market and mainnet were not deployed.

[Measured gates](../testing/results.md) separate contract checks, deployment and learning mastery.
