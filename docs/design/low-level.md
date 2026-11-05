# Low-level design
Foundry root is the repository root. Solidity 0.8.38, Cancun, optimized IR, 1,000 optimizer runs. OpenZeppelin 5.0.2 supplies ERC20, SafeERC20, Math and storage ReentrancyGuard. Vendored dependency files are content-locked.

## Storage
cash: recognized loan-token cash, excluding direct transfers.
totalCollateral: sum of collateralOf.
debtShares / totalDebtShares: indexed liability units.
borrowIndex: RAY (1e27) initially, nondecreasing, capped at 1e36.
lastAccrual: timestamp of last checkpoint.
cumulativeBadDebt: historical aggregate receivable reduction.
ERC20 balances/totalSupply: lender ownership, with six additional share decimals.

## External methods
- deposit(assets,minShares): accrue → check backing/cap → floor shares → update cash/mint → exact pull.
- withdraw(assets,maxShares): accrue → check liquidity → ceil burn → protect final claim → burn/update cash → exact push.
- redeem(shares,minAssets): floor proceeds → liquidity → burn/update cash → exact push; worthless shares may be burned.
- addCollateral(amount): balance check → account → exact pull. No price dependency.
- removeCollateral(amount): accrue → remove collateral → check remaining LTV if debt exists → exact push.
- borrow(assets): accrue → ceil debt shares → reduce cash → independent oracle health check → exact push.
- repay(borrower,shares,maxAssets): accrue → ceil payment → burn debt shares → add cash → exact pull.
- liquidate(borrower,maxDebtShares,maxAssets,minCollateral): fresh oracle → unhealthy check → collateral-affordable repayment cap → state settlement → residual write-off → exact payment/seizure.
- accrue(): permissionless interest checkpoint.

All state-mutating asset methods use the same storage reentrancy lock. Quotes involving assets/debt use stableView and revert during mutation. Raw public accounting getters and ERC20 balance getters are not an integration price API.

## Failure policy
Stale/invalid/unavailable prices or sequencer outage/grace block borrowing, debt-bearing collateral withdrawal and liquidation. Debt repayment, collateral top-up, lender deposits/withdrawals and debt-free collateral withdrawal remain available subject to exact token backing. An actual backing deficit halts asset methods. Unsupported rebasing assets are not repaired by silently recognizing gains/losses.

## Bounds and rounding
Token decimals 0–18; deposit and collateral aggregate caps 1e30 native units; oracle ratio (0,1e36]. Token amount caps are raw units, not fiat TVL limits. The index cap prevents indefinite growth from overflowing; at the cap, additional interest stops. At very high indices debt-share granularity is poor (one share can cost up to 1e9 raw loan units). This is an explicitly documented longevity limitation, not a production-scale risk policy.
