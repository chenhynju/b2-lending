# Lending vault security assessment
**AI-Assisted Self-Assessment. No independent third-party audit or production certification.**

Contract scope is frozen at **b97598b987dfee2a0bf2ee40c95d2ebda1ad62fe**; [scope and assumptions](../scope.md).
One confirmed Low finding, [L-01](../findings/L-01-last-share.md), was reproduced locally, fixed and regression/mutation tested. No unresolved true Critical/High/Medium finding was identified by this bounded self-assessment. This wording is not a guarantee that none exists.

## Reviews performed
Access and external calls: no admin/upgrader; users cannot redirect another borrower's collateral through repayment; liquidation pays and seizes atomically; shared reentrancy guard protects asset methods.
Asset flow: exact deltas, donation exclusion, aggregate and individual rounding reviewed; negative backing fails closed.
Mathematics: independent Python Fraction/integer vectors, actual-index differential fuzz, debt/share conservation, rounding bounds and final-share guard.
Oracle/MEV: dual USD ratio, stale/invalid data rejection, sequencer down/grace, no spot fallback; slippage bounds on supply/withdraw/redeem/repay/liquidation.
Economic review: jump-to-insolvency, same-transaction composition, four-actor generated sequences, funded loss settlement and conditional full exit.
Tooling: Slither/Aderyn raw warnings are retained and [triaged](../static-triage.md); four mutants are killed; compiler and dependency snapshots are recorded.

## Material acceptance limitations
- Final raw coverage meets the 90% branch target in every production module: vault 36/38, oracle 8/8, rate model 2/2. The test-only deployment factory fixes constructor-call-site attribution; no production branch was deleted or suppressed.
- The recorded campaign actually ran 1,821.66 seconds over 73 changing seeds, on the identical frozen production source.
- Mainnet fork uses real token/feed state but synthetic token balances; a public RPC can prune the pinned block.
- Local smoke independently includes accrued interest, aggregate-vs-individual rounding surplus and write-off. The current browser run waits for every successful receipt and verifies final state; earlier racy PASS artifacts are invalidated and retained.
- Base Sepolia broadcast/source verification is not performed without authorization and complete network-specific preflight.
- Owner learning mastery is NOT RUN until the owner explains the code and completes exercises.

[Live evidence/gates](../../testing/results.md) · [economic assessment](../../economics/economic-security-assessment.md) · [deployment](../../deployment/README.md)
