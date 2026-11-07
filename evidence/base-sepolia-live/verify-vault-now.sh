#!/usr/bin/env bash
set -u
cd /mnt/d/appspace/web3prepare/b2-lending
export https_proxy=http://127.0.0.1:8899
export http_proxy=http://127.0.0.1:8899
LOG=evidence/base-sepolia-live/verify-vault-now.log
: > "$LOG"

VAULT_ARGS=$(cast abi-encode "constructor(address,address,address)" 0x450C689f0702Be8AF310A50D7fd6E009Abecb5D7 0xcAf05CF9D12A05B928E6cE473f680A7fd0023DE6 0xb27100D4d478A439D31E48d89aA348D33303d7Ab)

echo "=== LendingVault ===" | tee -a "$LOG"
timeout 300 forge verify-contract --chain 84532 --verifier blockscout --verifier-url https://base-sepolia.blockscout.com/api --retries 30 --delay 5 --constructor-args "$VAULT_ARGS" 0x4A9c4C103EC26ED88528A9c8DAf032BEdB854999 src/LendingVault.sol:LendingVault --watch 2>&1 | tee -a "$LOG"
