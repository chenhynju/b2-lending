# WSL tool-assisted self-assessment

2026-11-05. Checkout d719c0c4dbce5bbc6b4c86db86dfddfbb41601ac. The four production source hashes matched the existing review lock at b97598b987dfee2a0bf2ee40c95d2ebda1ad62fe. Scans and tests ran in temporary WSL copies. This is an AI-assisted self-assessment. Independent third-party audit remains NOT RUN.

| Check | Result | Evidence |
|---|---|---|
| Slither 0.11.6 | Scan completed with 27 reports. The reviewed-warning gate passed. | [Raw report](slither-final.json) |
| Aderyn 0.6.8 | Scan completed. Two High and two Low issue groups matched the existing triage. | [Raw report](aderyn-final.json) |
| Foundry 1.8.1 | Six fuzz tests passed at 10,000 inputs per test, seed 0x20261105. | [Fuzz log](fuzz.txt) |
| Echidna 2.3.3 | Three properties passed after 10,009 calls, sequence length 32, seed 20261105, one worker. | [Echidna log](echidna-src.txt) |
| Halmos 0.3.3 | Rate range passed over utilization 0 through 1e18. Symbolic rate monotonicity timed out. | [Halmos log](halmos.txt) |

The [reviewed-warning gate](triage.txt) passed on the fresh reports using the existing [source-bound triage](../../docs/audit/static-triage.md). Slither reported ten strict-equality, twelve timestamp, three reentrancy-balance and two unused-return warnings. Its raw exit code was 255. The scan scope is src/ and excludes the Base Sepolia demo script. The existing demo regression evidence is [separate](../base-sepolia-prep-regression.txt).

The [Echidna harness](AuditVaultEchidna.sol) uses one actor, standard mock tokens and a fixed mock quote. It exercises supply, borrowing, repayment and exit. The three properties cover cash conservation, collateral conservation and agreement of lender shares, debt shares and recorded assets. The first invocation could not locate the harness under test/ in the compilation output. The successful run placed it under src/ in the isolated copy, with the mock under src/mocks/ and the LendingVault import adjusted to ./LendingVault.sol. The test does not quantify multi-actor behavior, changing oracles or real token behavior.

The [Halmos harness](AuditRateProperties.sol) was placed at test/AuditRateProperties.t.sol in a copy of the Foundry project with src/, lib/ and foundry.toml. Halmos followed its check_ convention. The successful result covers the stated rate bounds. Foundry exercised monotonicity with randomized inputs, while the symbolic result remains unresolved. [Halmos symbolic testing guide](https://github.com/a16z/halmos/blob/main/docs/getting-started.md)

The WSL inventory also found Medusa 1.5.1 and Wake 4.22.1. Mythril and Semgrep entry points were present and their version probes timed out. These four tools did not run an audit scan in this pass. The manual deep profile remains NOT RUN. [Recorded commands and exit codes](runs.json)
