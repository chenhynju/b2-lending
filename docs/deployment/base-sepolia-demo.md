# Base Sepolia demo deployment

**Status: BLOCKED on a funded signer. Nothing has been signed or broadcast.** The user permitted testnet deployment, and this plan selects Base Sepolia, chain ID 84532.

1. Create or select a wallet you can control locally, for example from the [official MetaMask download page](https://metamask.com/download).
2. Add Base Sepolia using the [official network settings](https://docs.base.org/get-started/connect-to-base): RPC https://sepolia.base.org, chain ID 84532, currency ETH.
3. Claim free **Base Sepolia ETH** through the [Chainlink faucet](https://faucets.chain.link/base-sepolia) or a faucet in the [official Base funding guide](https://docs.base.org/get-started/get-funds). Eligibility and limits vary. No purchase is necessary.
4. Confirm the balance for your public address on [BaseScan](https://sepolia.basescan.org). Share the public address for preflight. The signing wallet stays local; no secret recovery phrase, private key, or password is required in chat.

## Exact deployment scope

[DeployBaseSepoliaDemo](../../script/DeployBaseSepoliaDemo.s.sol) creates four contracts: a 6-decimal demo loan token, an 18-decimal demo collateral token, a controlled test quote, and the frozen LendingVault. The deployer is the immutable operator of the test quote and can change it to demonstrate liquidation; the quote expires after seven days. Both assets provide one free allocation per address. The assets and quote reject deployment on other chains. These fixtures carry no real asset backing and do not replace the production FeedOracle or its sequencer checks.

[Local dry run](../../evidence/base-sepolia-demo-dry-run.json) validated all four CREATE operations on private Anvil configured with chain ID 84532. Those gas limits are local simulation observations, not a live Base fee quote. [Regression log](../../evidence/base-sepolia-prep-regression.txt) records 62 pass, zero fail, and the explicitly optional fork skip. The production source remains unchanged.

## After funding

Run the unsigned simulation with the actual deployer. The command below does not broadcast:

```sh
export BASE_SEPOLIA_RPC_URL=https://sepolia.base.org
export DEPLOYER_ADDRESS=0xYourPublicWalletAddress
forge script script/DeployBaseSepoliaDemo.s.sol:DeployBaseSepoliaDemo \
  --sig "run(address)" "$DEPLOYER_ADDRESS" \
  --sender "$DEPLOYER_ADDRESS" --rpc-url "$BASE_SEPOLIA_RPC_URL"
```

Recheck chain, nonce, exact constructor inputs, available test ETH, and fees including the L1 data component. Sign locally with a wallet or an encrypted Foundry account only after reviewing that transaction plan. Wait for successful receipts, verify deployed runtime and immutables, submit the exact source/constructor inputs for explorer verification, and record contract addresses, transaction hashes, blocks and gas used. An actual deployment must pass these checks before the browser config points at it.

For the browser smoke test, claim the demo tokens from both verified contracts, configure the actual addresses and chain ID 84532, then exercise deposit, collateral, borrowing, repayment and exit. The test quote operator can separately run a controlled liquidation. Test ETH is required only for transaction fees; the demo tokens are claimed from their own contracts.
