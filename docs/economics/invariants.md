# Economic invariants and exceptions
These are executable bounded tests, not formal universal proofs.

| Property | Expression / scope | Executable verification |
|---|---|---|
| Cash conservation | C + withdrawals + borrowed = deposits + repaid + liquidation paid | invariant_CashConservationGhostLedger |
| Lender supply | sum lender balances = S = ghost minted − ghost burned | invariant_LenderShareSupply |
| Debt supply | sum user debt shares = Q | invariant_DebtShareSupply |
| Collateral conservation | sum user collateral = totalCollateral = ghost in − ghost out | invariant_CollateralConservation |
| Physical custody | actual loan balance ≥ C; actual collateral ≥ totalCollateral | invariant_PhysicalBacking |
| Asset identity | A = C + ceil(Q I/R) | invariant_AssetReceivableIdentity |
| Interest | R ≤ I ≤ cap and I never decreases | invariant_IndexMonotonicAndCapped |
| Debt rounding | 0 ≤ sum user debt − D ≤ N−1 | invariant_DebtRoundingBound |
| APR | 2% ≤ rate ≤100% nominal; utilization-monotone | invariant_RateBounded / testFuzz_RateMonotonic |
| Origination safety | new debt ≤75% priced collateral | handler borrow/remove immediate assertions |
| Loss settlement | collateral exhausted ⇒ liquidated borrower's debt=0; assets decrease by recognized write-off | handler liquidate / testGapLossSocialization |
| Lender exit | all funded debt repaid, collateral released, shares redeemed ⇒ Q=S=C=0 | afterInvariant |

A direct donation is an excluded balance surplus. Oracle movement/interest may violate subsequent borrower health without violating an origination check. Liquidation can realize losses; “no debt after collateral exhaustion” does not mean “no loss.” Supply and asset values use different units; equality of their raw numbers would be an invalid invariant.

Four actors are pre-funded by test fixtures. Handler actions choose bounded inputs and legitimate preconditions; return-before-action skips are possible and are not economic successes. The fixture starts with a real deposit/borrow, ensuring non-vacuous debt. No blanket try/catch hides unexpected vault reverts.
