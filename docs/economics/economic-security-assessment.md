# Economic security assessment
**AI-Assisted Self-Assessment.** No formal verification, independent audit or real-funds readiness is asserted.

Tested properties: exact cash-flow conservation, supply/debt/collateral ledgers, bounded debt rounding, interest-index behavior, independent rational formula vectors, adverse oracle states, flash collateral escape, donation resistance, funded liquidation, bad-debt recognition and conditional complete lender exit.

Bounded assumptions: honest independent USD feeds within configured freshness; supported exact-transfer tokens; available external repayment/liquidator capital; four generated actors; bounded amounts and time steps. The stateful campaign samples action sequences rather than enumerating all transaction orderings.

Residual risk: price gaps can consume all lender equity, liquidation incentives do not guarantee execution, accrued debt may exceed collateral, debt granularity worsens at very high indices, index-ceiling interest cessation, token blacklists/upgrades/pauses and sequencer/oracle governance. No emergency administrator or reserve can reverse these losses. A fresh feed may still be economically wrong. A valid heartbeat is asset-specific, not universally one hour.

[Simulation evidence](simulation-report.md) · [invariants and permitted exceptions](invariants.md)

## Algebraic properties versus implementation evidence
Within the exact nonnegative integer model, ceil subadditivity proves
0 <= sum(ceil(q_i I/R)) - ceil(sum(q_i) I/R) <= N-1.
Each ceil adds a fractional correction in [0,1); the difference is an integer,
cannot be negative, and is strictly less than N.

For a repayment of s shares from aggregate Q, let payment=ceil(s I/R) and
debtDrop=ceil(Q I/R)-ceil((Q-s) I/R). The same identity gives
payment-debtDrop in {0,1}. This is lender rounding surplus, not a missing asset.
The corrected local ledger verifies stored assets + accrued interest +
repayment surplus - write-off = final assets. Comparing a previewed asset view
with an entire checkpoint interest event would double-count already-previewed interest.

The rate curve is nondecreasing on [0,WAD]: both integer slopes are nonnegative
and the two pieces meet at the 80% kink. These algebraic statements do not prove
that the deployed implementation or external dependencies are universally safe;
implementation correspondence is tested within recorded bounds.
