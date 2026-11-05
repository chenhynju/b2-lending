# Compiler review
Initialization used the requested 0.8.28 template. Security review identified subsequently documented optimizer/compiler defects. The delivered sources pin **0.8.38**, not 0.8.28.

Official compiler binary SHA-256: 65c3180a336eabb6bdc4bbd49cc405aeb233976964ae6c11fba2a6c8be8f3243.
The binary was obtained from the Solidity binary distribution and matched its build manifest. [Recorded identity](../../evidence/toolchain/compiler.json). [Official known-bug snapshot](../../evidence/toolchain/solidity-bugs.json).

The official list documents SOL-2026-7 (optimized Yul bookkeeping), fixed in 0.8.38. Earlier relevant entries include IR custom-error encoding and memory-byte deletion issues. Do not interpret successful testing under 0.8.28 as disproving a compiler bug. Local tests, reference tests, optimizer comparisons and reproducibility checks were rerun with 0.8.38.

[Solidity known bugs](https://docs.solidity.org/en/latest/bugs.html) · [official bug source](https://github.com/ethereum/solidity/blob/develop/docs/bugs.json)

This is a dated known-bug review, not a claim that the compiler has no undiscovered defects. Reassess before public release.
