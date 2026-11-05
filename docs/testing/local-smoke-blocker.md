# Local integration remediation

The three prior failures are preserved. The user instructed continuation. The fixture now decodes actual Accrue/BadDebt/Liquidate events and independently calculates individually rounded payment, aggregate receivable reduction, rounding surplus and loss. The full asset identity includes that surplus. See local-smoke.json settlementAccounting.

The first browser PASS was invalidated after screenshots exposed stale asynchronous status matching; invalidated-racy-* artifacts are not acceptance evidence. Current acceptance requires fresh status, successful receipts for every wallet transaction and actual post-liquidation debt/collateral checks. See browser.json only when its current status is PASS.
