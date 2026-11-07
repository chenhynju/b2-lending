# AI-Assisted Self-Assessment follow-up

Source freeze: b97598b987dfee2a0bf2ee40c95d2ebda1ad62fe.
Checkout: d719c0c4dbce5bbc6b4c86db86dfddfbb41601ac.
Production sources were unchanged in this follow-up.

| Tool | Gate | Evidence |
| --- | --- | --- |
| Slither | Previously reviewed | 27 raw findings triaged in the prior pass |
| Aderyn | Previously reviewed | Two High and two Low raw finding groups triaged in the prior pass |
| Echidna | PASS within harness scope | Three properties, 10,009 calls in the prior pass |
| Medusa | PASS within harness scope | 7 checks, 10,315 calls, depth 32, zero failures |
| Wake | BLOCKED | Detector run stopped at compiler download TLS timeout |
| Halmos | PARTIAL | Rate range passed, monotonicity timed out in the prior pass |
| Mythril | BLOCKED | Runtime bytecode analysis did not return a result before the 100-second outer timeout |
| Certora CLI | NOT RUN | CLI 8.19.1 confirmed. No exported CERTORAKEY or project-specific CVL specification found |

Medusa reused the prior single-actor Echidna harness with its import path adjusted and its property prefix changed to property_. The oracle is fixed in that harness. The checks cover cash, share claims, collateral, and four action assertions. See medusa.txt for the invocation and result.

The earlier finding L-01 and its regression are documented in ../wsl-self-audit/README.md. This follow-up produced no new confirmed findings. The incomplete gates remain open.
