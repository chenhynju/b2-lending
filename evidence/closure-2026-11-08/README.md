# Frontend remediation and audit closure

AI-Assisted Self-Assessment. Baseline 7c7c892. Exact final file hashes are in source-hashes.json.

## Frontend UI-01

The original send function could reach a wallet transaction request after a chain/account change during gas estimation. The fix captures sender/epoch, binds chainId, checks the active account and chain again, and rejects stale completion after submission.
Five isolated regressions passed. The full browser flow passed with a new chain-change-during-estimation case against real local Anvil estimation. The 28 setup/settlement transactions and 15 browser wallet transactions succeeded. MetaMask extension signing itself is outside these tests.
The full Foundry suite passed 63 tests with zero failures and one optional fork skip.

## Formal checks

Halmos with CVC5 1.2.1 passed rate range and monotonicity (31 paths total). The monotonic property uses uint64 inputs constrained to 0 <= lower <= upper <= 1e18. This includes every valid utilization value accepted by InterestRateModel. Both properties call the actual Solidity library. CVC5 was downloaded from its official release and checked against the SHA-256 pinned in installed Halmos metadata, 6d44abc233980a14d72cc5809287d27c3335b1d6ee863381d0b5ffcbd0d8de56.
The failed first solver download and Z3 timeout remain in the logs.

Certora CLI 8.19.1 initially lacked Java. A verified isolated Temurin JRE 21 now enables local checks. RateHarness and both CVL rules pass compilation/typechecking without IR. The optimized IR preparation fails on unsupported Yul optimizer steps for 0.8.38. No cloud prover result exists. A configured authorized Certora prover is needed for that gate.

Wake 4.22.2 was verified against PyPI metadata and run as an isolated overlay. It still rejects Solidity 0.8.38 because its maximum is 0.8.34. This compatibility gate remains BLOCKED. Candidate paths are waiting for compatible Wake support, or evaluating a separately tested compiler migration with a new source freeze and redeployment decision.

Mythril's previous full vault timeout remains open. Its completed oracle runtime findings remain separately triaged. Slither/Aderyn raw warnings and the prior bounded Echidna/Medusa campaigns retain their documented scopes. Production Solidity code did not change in this remediation.

## Synchronization

Development, tests and commit originate in WSL. The original dirty WSL state is preserved in stash. Windows is updated from origin/main only after a successful push. Host Git transport is used from the WSL working tree because Linux HTTPS cannot reach GitHub through the host VPN.
