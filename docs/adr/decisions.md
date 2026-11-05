# Architecture decisions
## ADR-001: immutable isolated market
Context: demonstrate reviewable collateralized credit without hiding risk in an admin.
Decision: one loan token, one collateral, immutable LTV/threshold/bonus/curve; no proxy.
Alternatives: pooled multi-collateral markets and upgradeable risk managers.
Trade-offs: narrow scope and no emergency rescue; new parameters require a new deployment.
Security/performance: fewer permission/storage branches; token and oracle governance remain external.

## ADR-002: tracked cash, not donated balance
Context: first-depositor donation can distort proportional minting.
Decision: recognize cash only through exact operations; reject transfer taxes and negative backing.
Alternatives: ERC-4626 virtual shares/virtual assets or permissionless sync.
Trade-offs: unsolicited donations and positive rebases cannot be reclaimed; no promise to support arbitrary ERC20s.
Security/performance: exact transfer checks cost external balance reads, but avoid silently charging other lenders.

## ADR-003: indexed debt and explicit loss settlement
Context: interest must not require iterating over borrowers.
Decision: RAY borrowIndex and debt shares; aggregate ceiling and bounded per-account dust; collateral exhaustion atomically writes off remaining shares.
Alternatives: per-account loops, bad debt left as perpetual receivable, insurance subsidies.
Trade-offs: granular debt near the finite index ceiling; LPs absorb loss; permissionless accrual timing affects compounding.
Security/performance: constant-time methods, no borrower enumeration.

## ADR-004: independent USD feeds
Context: flash-funded spot price manipulation can corrupt liquidation.
Decision: ratio of collateral/USD and loan/USD feeds; no market-price fallback; optional sequencer adapter with deployment protections.
Alternatives: AMM spot oracle or TWAP-only pricing.
Trade-offs: feed availability/governance and heartbeat configuration are trusted.
Security/performance: extra STATICCALLs; fail closed for risk-sensitive operations.

## ADR-005: compiler and reentrancy guard
Context: initialization pins 0.8.28/OZ 5.0.2; compiler review reveals fixed optimizer issues.
Decision: exact Solidity 0.8.38, 1,000-run optimized IR; storage ReentrancyGuard from the mandated OZ version.
Alternatives: retain known-affected compiler, unoptimized legacy pipeline or change OZ to enable transient guard.
Trade-offs: compiler override is documented; legacy pipeline fails stack depth for this liquidation implementation.
Security/performance: six optimizer configurations are measured; unsupported variants are recorded, not omitted.

## ADR-006: small dependency-free wallet UI
Context: the lending series needs an executable capital-flow demo, not AMM swap screens.
Decision: static HTML/CSS/JavaScript + EIP-1193 provider, compiled selectors and BigInt; Playwright is test-only.
Alternatives: default Next/wagmi stack.
Trade-offs: fewer framework dependencies but narrower wallet UX; no wallet-connect/session/social login.
Security/performance: no signing secret/CDN runtime; explicit review/confirmation, configured-chain checks and bounded approvals. This is an intentional exception to the default frontend stack.
