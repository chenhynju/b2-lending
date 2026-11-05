# LendingVault source walkthrough

Frozen source commit: b97598b987dfee2a0bf2ee40c95d2ebda1ad62fe. All paths/line links below are generated from the actual source.

## deposit: Lender enters the market

[Source line 127](../../src/LendingVault.sol#L127)

Checkpoint interest before pricing ownership. Use tracked cash plus aggregate debt, never the raw token balance. A first depositor receives six extra share decimals; later deposits round shares down. Enforce cap and minShares, then add cash and mint before the exact token pull. A failed pull reverts the entire mint. Balance-derived pricing or mint-before-accrual can transfer old lenders' value to new entrants. Alternatives: ERC-4626 virtual offsets; this market instead excludes donations.

Tests/evidence: testDonationCannotInflatePrice / testDepositWithdrawRedeem. Runtime commands: forge test --match-contract LendingVaultTest -vv; forge test --match-contract LendingInvariant -vv. See [measured results](../testing/results.md), not hypothetical sample output.

## withdraw: Exact-asset lender exit

[Source line 142](../../src/LendingVault.sol#L142)

Round the share burn UP so a withdrawing lender cannot underpay remaining owners. Require idle cash and maxShares, then prevent a final rounded burn from stranding receivables (L-01). Burn and reduce recognized cash before the transfer. Available receivables are not available cash. If all assets cannot be paid, redeeming the entire claim must wait for repayment/loss settlement.

Tests/evidence: testRegression_LastShareCannotOrphanReceivables / testInsufficientLiquidity. Runtime commands: forge test --match-contract LendingVaultTest -vv; forge test --match-contract LendingInvariant -vv. See [measured results](../testing/results.md), not hypothetical sample output.

## redeem: Exact-share lender exit

[Source line 158](../../src/LendingVault.sol#L158)

Round asset proceeds DOWN. Cash can be insufficient even when the claim has positive book value. Burn shares and reduce cash before interacting with the token. Zero proceeds are allowed so all owners can discard worthless shares after total loss. With S=0 there must be no prior lender claim; only then may a market restart.

Tests/evidence: testDustLiquidationAndRestart / testRedeemBlockedUntilBorrowerRepays. Runtime commands: forge test --match-contract LendingVaultTest -vv; forge test --match-contract LendingInvariant -vv. See [measured results](../testing/results.md), not hypothetical sample output.

## addCollateral: Borrower reduces risk

[Source line 172](../../src/LendingVault.sol#L172)

Record collateral balances and aggregate custody, then pull the exact amount. A price read is unnecessary: adding genuine collateral cannot increase debt. Amount caps and supported-token assumptions still apply. No third party may redirect the caller's collateral account.

Tests/evidence: testOracleFailureAllowsRepaymentAndCollateralTopup. Runtime commands: forge test --match-contract LendingVaultTest -vv; forge test --match-contract LendingInvariant -vv. See [measured results](../testing/results.md), not hypothetical sample output.

## removeCollateral: Borrower increases risk

[Source line 182](../../src/LendingVault.sol#L182)

Accrue debt, tentatively reduce collateral and check origination LTV if debt remains. The transaction rolls back when the residual position is unsafe. Debt-free collateral release needs no oracle. Pay the caller only after accounting/health checks; shared locking prevents cross-function callback escape.

Tests/evidence: testBorrowLTVAndWithdrawCollateralChecks. Runtime commands: forge test --match-contract LendingVaultTest -vv; forge test --match-contract LendingInvariant -vv. See [measured results](../testing/results.md), not hypothetical sample output.

## borrow: Cash becomes a receivable

[Source line 194](../../src/LendingVault.sol#L194)

Mint ceil(assets*RAY/index) debt shares, reduce cash, then validate the caller's conservative rounded liability using a fresh independent price. Only then transfer the exact loan amount. The debt addition cannot dilute pre-existing lender receivables. After price shocks or interest, health may later deteriorate: the LTV check is an execution-time constraint.

Tests/evidence: testBorrowAtLTVBoundary / testFuzz_BorrowRepayRounding. Runtime commands: forge test --match-contract LendingVaultTest -vv; forge test --match-contract LendingInvariant -vv. See [measured results](../testing/results.md), not hypothetical sample output.

## repay: Receivable becomes cash

[Source line 209](../../src/LendingVault.sol#L209)

Accept exact debt shares and collect ceil(shares*index/RAY), respecting maxAssets. Burn debt shares, add cash, then pull funds. Anyone may pay another borrower's debt, but cannot redirect their collateral. Aggregate receivable reduction can be one raw unit smaller than individual rounded payment; that difference is lender rounding surplus, not bad debt.

Tests/evidence: testThirdPartyRepayment / testPartialRepaymentRoundsUp. Runtime commands: forge test --match-contract LendingVaultTest -vv; forge test --match-contract LendingInvariant -vv. See [measured results](../testing/results.md), not hypothetical sample output.

## liquidate: Unhealthy collateral settlement

[Source line 224](../../src/LendingVault.sol#L224)

Read independent price; require debt above the 80% threshold. Calculate collateral-affordable repayment after the 5% bonus. Partial repayment seizes collateral down; collateral-exhausting settlement caps repayment and seizes the remainder. Remove residual debt shares and measure the EXACT aggregate receivable write-off, reducing lender share value. Payment and seizure are atomic; an unfunded caller cannot persist the write-off. No insurance magic can eliminate losses after a price gap.

Tests/evidence: testGapLossSocialization / testUnfundedLiquidationCannotCommitLosses. Runtime commands: forge test --match-contract LendingVaultTest -vv; forge test --match-contract LendingInvariant -vv. See [measured results](../testing/results.md), not hypothetical sample output.

## _previewIndex: Lazy time-value accounting

[Source line 275](../../src/LendingVault.sol#L275)

Compute utilization from stored receivables/cash, apply the piecewise nominal APR for elapsed seconds, and cap the index. Use integer mulDiv with explicit RAY/WAD units. Views preview the same accrual that the next mutation checkpoints. Frequent checkpoints compound: APR must not be mislabeled APY. The index ceiling avoids indefinite numeric growth at the cost of eventual interest cessation.

Tests/evidence: testFuzz_ActualAccrual / testInterestIndexCapAndIdleAccrual. Runtime commands: forge test --match-contract LendingVaultTest -vv; forge test --match-contract LendingInvariant -vv. See [measured results](../testing/results.md), not hypothetical sample output.

## _accrue: Materialize the lazy index

[Source line 268](../../src/LendingVault.sol#L268)

Measure old aggregate receivables, materialize the preview index and timestamp, and emit actual added interest. No borrower loop is needed. Monetary accounting must separately include this interest and the rounding surplus of repayments when comparing states across mined blocks.

Tests/evidence: testInterestAndFullRepayment / local-smoke evidence. Runtime commands: forge test --match-contract LendingVaultTest -vv; forge test --match-contract LendingInvariant -vv. See [measured results](../testing/results.md), not hypothetical sample output.

## _value: Unit-safe valuation

[Source line 296](../../src/LendingVault.sol#L296)

Compute floor(collateralRaw*priceWAD*assetUnit/(collateralUnit*WAD)) in one mulDiv. The normalized price is loan human units per collateral human unit. Conservative flooring prevents overstating collateral. Decimal metadata is fixed at deployment and limited to 18. A 6-decimal loan with 18-decimal collateral is the principal test fixture.

Tests/evidence: testBorrowAtLTVBoundary / MainnetForkTest. Runtime commands: forge test --match-contract LendingVaultTest -vv; forge test --match-contract LendingInvariant -vv. See [measured results](../testing/results.md), not hypothetical sample output.

## _price: Oracle trust boundary

[Source line 291](../../src/LendingVault.sol#L291)

Reject zero or excessive normalized prices even if a custom immutable oracle supplies them. FeedOracle adds staleness/round/sequencer policy. This boundary does not validate whether the deployer chose the correct economic feeds; feed selection remains a deployment trust assumption.

Tests/evidence: testInvalidOracleBounds / FeedOracleTest. Runtime commands: forge test --match-contract LendingVaultTest -vv; forge test --match-contract LendingInvariant -vv. See [measured results](../testing/results.md), not hypothetical sample output.

## _pull: Exact incoming asset transfer

[Source line 311](../../src/LendingVault.sol#L311)

Record vault token balance, use SafeERC20.transferFrom, then require an exact increment. SafeERC20 supports optional-return USDT semantics. Fee-on-transfer/rebasing/lying token behavior is outside the support model; do not silently mint claims against missing funds.

Tests/evidence: testNoReturnUSDTStyleToken / testFeeOnTransferIncomingRejected. Runtime commands: forge test --match-contract LendingVaultTest -vv; forge test --match-contract LendingInvariant -vv. See [measured results](../testing/results.md), not hypothetical sample output.

## _push: Exact outgoing asset transfer

[Source line 317](../../src/LendingVault.sol#L317)

Require exact vault debit AND exact recipient credit after SafeERC20.transfer. A receiver-side fee cannot silently charge the withdrawing user. Every caller is nonReentrant. A token callback that donates funds may cause this strict check to revert, but cannot commit a partially paid withdrawal.

Tests/evidence: testOutgoingFeeAndFalseReturnRejected / testMutationAndReadOnlyReentrancyRejected. Runtime commands: forge test --match-contract LendingVaultTest -vv; forge test --match-contract LendingInvariant -vv. See [measured results](../testing/results.md), not hypothetical sample output.

## _backed: Custody sanity check

[Source line 305](../../src/LendingVault.sol#L305)

Actual balances must cover tracked loan cash and aggregate collateral. Surplus donations are ignored for claim pricing. A negative rebase fails closed; this implementation has no administrator to manufacture accounting recovery.

Tests/evidence: testNegativeRebaseDetected / invariant_PhysicalBacking. Runtime commands: forge test --match-contract LendingVaultTest -vv; forge test --match-contract LendingInvariant -vv. See [measured results](../testing/results.md), not hypothetical sample output.

## totalAssets: Valuation API

[Source line 88](../../src/LendingVault.sol#L88)

Return tracked cash plus ceiling-rounded aggregate debt at the preview index. stableView refuses valuation while a mutating token interaction is in progress. An integration should use this guarded valuation API, not recompute an exchange rate from raw public getters during callbacks.

Tests/evidence: testMutationAndReadOnlyReentrancyRejected / invariant_AssetReceivableIdentity. Runtime commands: forge test --match-contract LendingVaultTest -vv; forge test --match-contract LendingInvariant -vv. See [measured results](../testing/results.md), not hypothetical sample output.

## healthFactor: Liquidation eligibility view

[Source line 103](../../src/LendingVault.sol#L103)

Return threshold-adjusted collateral/debt scaled by WAD. Debt-free positions return the maximum integer without requesting a price. A factor below 1e18 indicates liquidation eligibility, not an assurance that a liquidator or external liquidity exists.

Tests/evidence: testDebtFreeHealthAndBaseRate / testPartialAndFullLiquidation. Runtime commands: forge test --match-contract LendingVaultTest -vv; forge test --match-contract LendingInvariant -vv. See [measured results](../testing/results.md), not hypothetical sample output.

## Execution order and debugging

Trace a normal position with forge test --match-test testInterestAndFullRepayment -vvvv. Identify the external token calls, state writes, Accrue event, debt-share burn and final share burn. Trace the vulnerable version through the separate worktree command in finding L-01; do not overwrite the fixed checkout. Use forge test --debug --match-test testPartialAndFullLiquidation for the local debugger. A trace is evidence of this execution, not all possible executions.
