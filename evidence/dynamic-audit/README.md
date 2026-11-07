# Lending vault dynamic audit

AI-Assisted Self-Assessment. Production source freeze b97598b987dfee2a0bf2ee40c95d2ebda1ad62fe. This pass changes the Foundry handler and tests only.

## Dynamic evidence

- Seed: 0xB220261105. The existing four-actor handler varies the price and elapsed time and exercises deposits, debt, share transfers and liquidation.
- The liquidation handler reconciles loan and collateral token balances for the payer, borrower collateral, lender assets, and recognized bad debt. It allows at most one smallest loan unit of lender gain from debt rounding.
- A deterministic price shock triggers liquidation by a different account and confirms positive recognized bad debt and zero remaining borrower debt. See liquidation-witness.txt.
- The short invariant run passed all nine checks with 16 runs and depth 64 per check. See foundry-liquidation-smoke.txt.
- The non-invariant regression passed 61 tests with one optional fork skipped. See foundry-regression.txt. The new deterministic witness was run separately.
- Z3 4.12.5 returned unsat for a decreasing pair in the full valid input range of the independent integer rate formula. The largest intermediate product fits uint256. This model does not execute Solidity and does not close the timed-out Halmos bytecode check.

## Tool retries

- Wake 4.22.1: compiler index retrieval timed out on both URLs. An isolated offline cache seeded from the already installed Foundry binary bypassed download, exposing the installed Wake compiler ceiling of 0.8.34. The project pins 0.8.38. Gate BLOCKED.
- Mythril: a one-transaction FeedOracle runtime scan returned eight raw issues. The seven SWC-101 PCs all point to compiler ABI calldata-length checks in getter dispatch. The sequence CALLDATASIZE, PUSH1 3, NOT, ADD, SLT computes a signed length comparison. Its modular ADD is intentional and does not calculate prices or assets. The SWC-123 PC is the default selector-dispatch REVERT, with no nested call at that site. The trace uses bare runtime bytecode with zeroed immutable slots. No protocol exploit was identified in these eight reports. Raw trace, selector mapping and disassembly are preserved. The previous LendingVault-wide run timed out, so Mythril coverage is partial.
- Certora has no prover result for this revision. Slither, Aderyn, Echidna and Medusa retain the scopes and results of the previous pass.

No new confirmed vulnerability was identified within the completed checks.

The final default suite passed 63 tests with zero failures and one optional fork skipped. Foundry reported 128 invariant runs, 8,192 calls and zero reverts. Formatting and git diff checks passed. The CI-profile runs at 512 x 256 were still running when this summary was recorded.
