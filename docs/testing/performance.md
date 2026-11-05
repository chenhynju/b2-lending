# Performance comparison

Solidity 0.8.38 / Cancun, identical frozen protocol source and OZ 5.0.2. Constructor gas comes from real unlocked Anvil transactions with successful receipts and verified runtime.

| Runs | viaIR | Compile/test | Runtime bytes | Creation bytes | Deployment gas |
|---|---|---|---|---|---|
| 200 | True | PASS | 10433 | 11991 | 2447134 |
| 1000 | True | PASS | 10984 | 12542 | 2558486 |
| 10000 | True | PASS | 11969 | 13527 | 2765792 |
| 200 | False | FAIL (stack depth) | N/A | N/A | N/A |
| 1000 | False | FAIL (stack depth) | N/A | N/A | N/A |
| 10000 | False | FAIL (stack depth) | N/A | N/A | N/A |

Creation sizes exclude the 96-byte constructor arguments. Zero deployment-cost entries from forge gas-report are not considered measurements; the actual receipt gas above replaces them.

## Core execution gas, selected 1,000-run variant

State/access/negative paths and mock token callbacks vary. These distributions are not production fee quotes.

| Function | Min | Average | Median | Max | Calls |
|---|---|---|---|---|---|
| accrue | 35998 | 42189 | 42363 | 42396 | 72 |
| addCollateral | 42445 | 114975 | 114347 | 127777 | 124 |
| borrow | 43667 | 118138 | 125022 | 142146 | 162 |
| deposit | 52074 | 148172 | 153037 | 161378 | 135 |
| liquidate | 53565 | 123269 | 136286 | 136286 | 42 |
| redeem | 50945 | 69304 | 69650 | 79601 | 46 |
| removeCollateral | 52729 | 71683 | 67086 | 95587 | 7 |
| repay | 53475 | 79883 | 81379 | 105859 | 40 |
| withdraw | 50747 | 68866 | 64676 | 93031 | 8 |

[Full variant commands/logs](../../evidence/optimizer-matrix.json), [actual deployment receipts](../../evidence/deployment-gas.json). 1,000 runs is an intermediate size/execution-cost choice; it is not a universal optimum.
