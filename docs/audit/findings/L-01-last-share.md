# L-01 — Final rounded share burn can orphan receivables
Severity: **Low**. Status: **FIXED**. AI-Assisted Self-Assessment.
Affected code: LendingVault.withdraw before the last-share protection.
Frozen vulnerable commit: 02c4ad53c0dcc2903a7a1bf26983fe6d0feb770d.
Fixed source commit: b97598b987dfee2a0bf2ee40c95d2ebda1ad62fe.

## Preconditions and root cause
A lender reduces supply to one smallest share while an indexed receivable remains. After interest/repayment the claim-to-share ratio becomes large. withdraw rounds its burn up and can burn the final share for less than the complete claim.

## Local reproduction
Deposit two raw units; collateralize and borrow one; redeem all but one microscopic lender share; accrue two years at full utilization; repay; borrow one again. At index 3e27, creating one debt share recognizes three raw receivable units. The lender's final share represents five assets, with two units idle. A one-unit withdraw formerly burned the final share and left four unowned assets. A later first deposit could claim that stranded value.

This requires extreme share granularity and the exiting owner's own final burn; no arbitrary other user's share can be burned without authorization. Hence Low, not an unsupported High claim.

## Evidence / regression
[Full vulnerable trace](../../../evidence/poc-last-share-before.txt). The PoC is executable from the vulnerable commit:
```sh
git worktree add /tmp/b2-lending-vulnerable 02c4ad53c0dcc2903a7a1bf26983fe6d0feb770d
cd /tmp/b2-lending-vulnerable
forge test --match-test testPoC_LastShareBurnOrphansReceivables -vvvv
```
Fixed regression: testRegression_LastShareCannotOrphanReceivables in test/LendingVault.t.sol. It expects InvalidAmount and retains the last share/claim. Mutation testing removes this exact guard and the regression fails, as recorded in evidence/mutation-last-share.txt.

## Fix review
Before state changes, if the burn equals totalSupply, require assets to equal all tracked cash plus receivables. Redeeming the final share already requests the full claim and requires sufficient cash. No admin/rescue mechanism is introduced.

Residual risk: tiny deposits can still quote zero shares (reverted); large indices degrade debt granularity. Integrations must set meaningful execution slippage limits.
