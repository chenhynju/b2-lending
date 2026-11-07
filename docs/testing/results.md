# Measured verification results

2026-11-05. **AI-Assisted Self-Assessment**, not independent certification.

Production source is byte-for-byte frozen at **b97598b987dfee2a0bf2ee40c95d2ebda1ad62fe**. Later test/fixture/UI refinements did not change it.

## Engineering Report

Implemented isolated lender shares, supply/withdraw/redeem, collateral custody, indexed borrowing/repayment, kinked APR, independent-feed liquidation, explicit bad-debt socialization, wallet demo, deployment scripts and reproducible evidence.

| Gate | Current result |
|---|---|
| contract build/unit/fuzz/invariants | PASS |
| 30-minute changing-seed campaign | PASS |
| mainnet real-state fork | PASS |
| 90% branch target per production module | PASS |
| four targeted mutants | PASS |
| independent reproducible builds | PASS |
| static tools and reviewed-warning gate | PASS |
| dependency advisory snapshot | PASS |
| local chain settlement and runtime verification | PASS |
| browser wallet / receipt / security flows | PASS |
| manual economic review | PASS (bounded self-assessment) |
| deep profile (50k fuzz runs / 1000-depth invariant) | NOT RUN |
| public Base Sepolia demo deployment | PASS |
| Blockscout source verification | PASS (4/4) |
| on-chain runtime bytecode equality | PASS (4/4, immutables masked) |
| production Chainlink deployment / mainnet | NOT RUN |
| remote publication / remote CI | PASS (GitHub Actions 42350148797) |
| owner learning mastery | NOT RUN |
| independent third-party audit | NOT RUN |

### Test execution

{'passed': 63, 'failed': 0, 'skipped': 1, 'total': 64, 'status': 'PASS'}

Timed changing-seed campaign: **1821.66 seconds / 73 rounds**, each with 128 runs x64 handler depth. Nine invariant properties share the generated sequences; these are not nine independent campaigns. Commands, seeds, timing and per-selector call counts remain in [campaign.json](../../evidence/campaign.json).

[Final tests](../../evidence/tests-delivery.txt) and [real mainnet fork](../../evidence/mainnet-fork.json). The ordinary test command deliberately skips the fork without MAINNET_RPC_URL. The separately executed fork uses real token/feed state at a recorded block/hash and synthetic deal balances. No mainnet transaction was broadcast.

Four mutants are [KILLED](../../evidence/mutation.json). The independent Python Fraction/integer reference checks 50,000 seeded samples and 256 Solidity vectors; actual borrow-index storage also has differential fuzz.

### Raw coverage

| Production module | Lines | Functions | Branches |
|---|---|---|---|
| src/FeedOracle.sol | 27/27 | 3/3 | 8/8 |
| src/InterestRateModel.sol | 4/4 | 1/1 | 2/2 |
| src/LendingVault.sol | 164/181 | 28/28 | 36/38 |

Command: forge coverage --ir-minimum --no-match-contract 'LendingInvariant|MainnetForkTest' --fuzz-runs 256 --report summary --report lcov. Every production module meets 90% branch coverage. The denominator includes the constructor branches. Full original/failed coverage artifacts are retained.

The earlier inline constructor sites were misattributed by coverage. An explicit test-only OracleTestFactory invokes the identical constructor conditions and preserves every negative test. Both the isolated legacy experiment and final full IR-minimum coverage record all eight oracle branches. Production source did not change; no branch was deleted or suppressed. Two vault constructor branches remain uncredited, so vault coverage is reported as 36/38 rather than 100%.

### Local integration and browser

The current run records 28 successful Anvil setup/settlement transactions and 15 successful browser wallet transactions. Runtime bytecode matches with only compiler-declared immutable slots masked. Browser tests assert fresh completion status, every receipt status and actual post-liquidation debt/collateral. Wrong-network/account-change paths broadcast no transaction.

[Local receipts and exact settlement](../../evidence/local-smoke.json), [browser flows/receipts](../../evidence/browser.json), [desktop](../../evidence/frontend-desktop.png), [mobile](../../evidence/frontend-mobile.png).

Prior failed accounting assertions and the invalidated racy browser PASS are retained. The corrected ledger separately verifies accrued interest, individual-vs-aggregate repayment rounding surplus and bad-debt write-off. The UI now explicitly estimates gas with headroom, immediately clears stale completion status and waits for receipts. Fixture-generated transactions also wait for confirmations. [Remediation details](local-smoke-blocker.md).

### Environment, audit and performance

WSL Ubuntu24.04, Foundry1.8.1, Solidity0.8.38, OZ5.0.2, forge-std1.14.0, Slither0.11.6, Aderyn0.6.8. The official compiler digest is verified. [Compiler](../audit/compiler-review.md), [dependency review](../audit/dependency-review.md), [static triage](../audit/static-triage.md). The advisory snapshot is dated and is not assurance against unknown issues.

[Actual deployment gas and optimizer comparison](performance.md): 200/1,000/10,000 optimized-IR variants are measured, non-IR stack failures retained. Selected runtime 10,984 bytes; creation 12,542 bytes plus 96 constructor argument bytes; selected constructor gas 2,558,486 on Anvil. Gas-report zero deployment entries are not treated as valid cost measurements.

The CI workflow and locked installer exist. The Base Sepolia demo deployment is complete and recorded in [base-sepolia-live.md](../deployment/base-sepolia-live.md); remote CI results are recorded after the public repository push. The production FeedOracle market still needs real feeds/tokens and separate authorization. [Preflight](../deployment/README.md).

## Learning Report

[Business/math](../economics/economic-model.md), [HLD](../architecture/overview.md), [LLD](../design/low-level.md), [source walkthrough](../code-walkthrough/README.md), [execution/debug/defense exercises](../learning/interview-defense.md). Owner explanations and independent exercises are NOT RUN. Availability of AI-assisted material does not prove mastery.

## Clean checkout review

An offline Git-bundle clone at 46f74403dc5ada78a53dddd06cceb4d2bc0d5efc passed dependency content verification, the independent reference, all ordinary tests and fixed-seed gas regression. Every reviewed file matched its recorded SHA-256. Only evidence/documentation was added after that test revision; production/test/config/tool inputs are unchanged. [Machine record](../../evidence/fresh-clone.json) and [full output](../../evidence/fresh-clone.txt).
