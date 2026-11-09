# D02 isolated lending acceptance evidence

Evidence index prepared 2026-11-09. Repository inspected at `68196421618e292ad3d97d0e9a8328caadf9bf89`. Individual reports and deployment manifests identify the source that was tested or deployed.

| Gate | Result |
| --- | --- |
| Local engineering | PASS within the tested scope |
| Security self-review | Recorded in [AI-Assisted Self-Assessment](../audit/review-2026-11-08.md) |
| Independent third-party audit | NOT RUN |
| Owner learning mastery | NOT RUN |

## Local verification

66 Solidity tests passed with one optional fork test skipped. The local browser wallet workflow passed. [Browser log](../../evidence/review-2026-11-08/d02-browser-current.log).

## Public testnet

Base Sepolia deployment and historical borrower/lender workflow PASS. Four contract creation receipts and twelve workflow receipts cover synthetic asset claims, approvals, deposit, collateral, borrowing, repayment and exit. [Deployment and workflow journal](../../deployments/base-sepolia-live.json).

## Remaining scope

Public liquidation, bad-debt socialization and production oracle behavior are NOT RUN in this synthetic market. [Hosted UI rendering](../../evidence/hosted-ui-20261109/acceptance.json) passed separately.
