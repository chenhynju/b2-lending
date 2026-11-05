# Source walkthrough

Commit b97598b987dfee2a0bf2ee40c95d2ebda1ad62fe.

- [Vault: state, formulas, security and tests](LendingVault.md)
- [Oracle and interest model](oracle-and-rates.md)
- [Learning exercises and defense](../learning/interview-defense.md)
- [Full source](../../src/LendingVault.sol)

OpenZeppelin implements ERC20 mechanics, safe calls, full-precision arithmetic and the storage reentrancy lock. The custom protocol code composes these components; it does not claim to reinvent them.
