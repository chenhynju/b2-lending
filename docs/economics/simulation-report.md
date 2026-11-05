# Simulation report

AI-Assisted Self-Assessment; sampled bounded testing, not formal proof.

- Four actors, 12 handler actions, nine conservation/accounting properties, 1821.66 seconds over 73 changing seeds.
- Actual index differential fuzz; 256 rational/integer vectors; 50,000 Python rate/round-trip samples.
- Flash collateral escape rolls back; donation does not change borrowing capacity; same-transaction deposit/redeem does not profit.
- Gap insolvency is recognized and lender equity reduced, with independent exact rounding-surplus/interest/write-off settlement checks.
- Real-state USDT/WETH/feed fork passes with declared synthetic balances.
- Local and browser transactions have confirmed successful receipts; negative input/network/account/healthy-liquidation paths are verified.

Uncovered: corrupted oracle governance, actual liquidation competition, public L2 outage recovery, censorship, unlimited actor/action/time space, cross-protocol mainnet flash liquidity and equilibrium incentives. No insurance/backstop guarantees losses cannot occur. [Current gates](../testing/results.md).
