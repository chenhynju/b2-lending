# Attack scenarios
| Attacker / scenario | Expected safety behavior | Test |
|---|---|---|
| First depositor donates loan tokens | Surplus does not increase accounted A or dilute new lenders | testDonationCannotInflatePrice |
| Flash-funded deposit then redeem | No same-transaction profit | testFlashDepositRedeemHasNoProfit |
| Flash-funded collateral then borrow/escape | Collateral release reverts; entire flash transaction rolls back | testFlashCollateralCannotEscapeDebt |
| Market-balance donation used as price manipulation | Independent oracle borrowing capacity unchanged | testDonationDoesNotChangeBorrowingPower |
| Borrower repeatedly borrows and repays tiny amounts | Debt/share rounding cannot drain lenders | testFuzz_BorrowRepayRounding |
| Liquidator has no loan tokens/allowance | Settlement and write-off roll back atomically | testUnfundedLiquidationCannotCommitLosses |
| Price gaps below recoverable debt | Explicit loss recognition and pro rata lender haircut | testGapLossSocialization |
| Token callback reenters mutation or valuation | Shared lock and stableView reject access | testMutationAndReadOnlyReentrancyRejected |
| Transfer-tax token changes receipt/payment | Whole operation reverts on exact delta mismatch | incoming/outgoing fee tests |
| Rebase destroys backing | Fail closed rather than masking deficit | testNegativeRebaseDetected |
| Sequencer outage or stale USD feed | No borrow, collateral escape or liquidation with unsafe price | FeedOracleTest |
| Last microscopic lender share burns early | Revert unless full claim is paid | testRegression_LastShareCannotOrphanReceivables |

The flash lender is a local zero-fee fixture; it demonstrates atomic composition and collateral constraints, not universal compatibility with every external lender. Legitimate liquidation and arbitrage are not classified as attacks. Oracle governance corruption, wrong feed selection, order flow censorship, extreme gaps and unavailable liquidators remain external economic risks.
