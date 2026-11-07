# Deployment and verification
The Base Sepolia demo market is deployed and functionally verified: [live report](base-sepolia-live.md) · [machine record](../../deployments/base-sepolia-live.json). The demo uses synthetic free-claim assets and an operator quote; the production Chainlink path and mainnet remain unexecuted. [Funding and deployment guide](base-sepolia-demo.md).

## Local
From the Foundry root in WSL:
```sh
forge build
python3 scripts/local_smoke.py
# Interactive local wallet demo:
python3 scripts/local_smoke.py --serve
# Browser verification (after npm ci and Playwright browser/dependencies):
python3 scripts/local_smoke.py --browser
```
The script launches ephemeral Anvil 31337 on 127.0.0.1:18545, deploys test tokens/oracle and market, broadcasts transactions, verifies successful receipts and deployed runtime after masking compiler-declared immutable slots, then stops the node. Local addresses/hashes are **local evidence**, not explorer addresses. The mock oracle is deliberately mutable and unsuitable for public lending.

## Public preflight
Review frozen source SHA, compiler/dependency identities, unresolved findings and coverage gaps; select actual Base Sepolia loan/collateral tokens, verified USD feeds, heartbeat and compatible sequencer protection; inspect chain ID 84532, wallet **public** address, test ETH/gas estimate, code sizes and constructor values. No keys belong in frontend or committed environment files.

The production script expects LOAN_TOKEN, COLLATERAL_TOKEN, COLLATERAL_USD_FEED, LOAN_USD_FEED, SEQUENCER_FEED and ORACLE_MAX_AGE.
Unsigned simulation:
```sh
forge script script/Deploy.s.sol:Deploy --rpc-url "$BASE_SEPOLIA_RPC_URL" --sender "$DEPLOYER_ADDRESS"
```
Only after explicit authorization, run broadcast with an encrypted Foundry account, record receipts, verify source and compare runtime/immutables. Source verification templates:
```sh
forge verify-contract --chain 84532 --watch \
  --constructor-args "$(cast abi-encode 'constructor(address,address,address)' "$LOAN_TOKEN" "$COLLATERAL_TOKEN" "$ORACLE_ADDRESS")" \
  "$VAULT_ADDRESS" src/LendingVault.sol:LendingVault
```
This is a command template, not an executed verification record. Verify FeedOracle with its four constructor parameters separately. Real explorer links must be added only after confirmed receipts/source verification.

## Post-deployment
Check immutable addresses/decimals, feed price/freshness/sequencer state, APR/limits, runtime, source metadata and admin absence. Execute authorized test deposits, collateral, borrow, repayment and exit; separately test a controlled mock market for liquidation. Public prices must never be changed to force liquidation on a real market.

## Local wallet funding without sharing a signing key
The automated browser uses Anvil's unlocked local accounts. For a separate browser
wallet, start --serve, select chain 31337 and fund only its public address locally.
From a second WSL shell in the project root:
```sh
export LOCAL_WALLET=0xYourPublicWalletAddress
python3 - <<'PY'
import json,os,sys
sys.path.insert(0,"scripts")
import local_smoke as demo
wallet=os.environ["LOCAL_WALLET"]
assert len(wallet)==42 and wallet.startswith("0x")
int(wallet,16)
assert int(demo.rpc("eth_chainId"),16)==31337
config=json.load(open("apps/web/config.json"))
assert config["chainId"]==31337
demo.selectors.update(json.load(open("apps/web/selectors.json")))
sender=demo.rpc("eth_accounts")[0]
demo.rpc("anvil_setBalance",[wallet,hex(100*10**18)])
demo.tx(sender,config["loan"],"mint(address,uint256)",[wallet,10_000*10**6])
demo.tx(sender,config["collateral"],"mint(address,uint256)",[wallet,10*10**18])
print("Local demo wallet funded")
PY
```
These are unrestricted **local mock tokens**, not public-network assets. No private
key is requested by the page or this funding command.
