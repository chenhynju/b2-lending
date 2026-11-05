# Frozen assessment scope
Assessment type: **AI-Assisted Self-Assessment** (not an independent audit).
Source freeze: b97598b987dfee2a0bf2ee40c95d2ebda1ad62fe.
Vulnerable baseline: 02c4ad53c0dcc2903a7a1bf26983fe6d0feb770d.

In scope: src/LendingVault.sol, src/InterestRateModel.sol, src/FeedOracle.sol, src/interfaces/IPriceOracle.sol. Solidity 0.8.38, Cancun, optimized IR, 1,000 runs; vendored OZ 5.0.2 and forge-std 1.14.0 with content lock.

Supporting review: test fixtures/handler, financial reference, production deployment script, local smoke tooling and browser UI. These supporting files may be extended after the contract freeze; evidence records their own run state. Local mocks are not production assets or a production oracle. No public deployment, independent oracle infrastructure, external liquidator operations or mainnet assurance is included.

Threat actors: malicious borrowers/lenders/liquidators, token callbacks, donation manipulators, transaction ordering and flash-funded compositors. Trusted dependencies: honest supported tokens, correct immutable feed configuration, economically valid feeds and the chain's timestamp/sequencer assumptions. No owner/admin/upgrader role exists.

[Core invariants](../economics/invariants.md) · [finding](findings/L-01-last-share.md) · [raw evidence](../../evidence/)
