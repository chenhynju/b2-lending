# Frontend wallet-context finding UI-01
AI-Assisted Self-Assessment against baseline 7c7c892.
During eth_estimateGas, switching chain or account could still reach eth_sendTransaction.
vulnerable-app.js is the baseline source. wallet-race.cjs reproduces the request against a synthetic wallet.
The fix captures sender and epoch, binds chainId, checks network and active account after estimation, and rejects stale receipt completion.
scripts/wallet_context_test.cjs now tests five contexts directly against apps/web/app.js.
scripts/browser_test.cjs adds a chain-change-during-estimation regression using real local Anvil estimates.
See ../closure-2026-11-08/browser-race.txt for the full browser run. Real MetaMask extension signing was not exercised.
