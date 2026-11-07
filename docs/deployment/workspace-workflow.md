# Development and synchronization

The canonical development and testing checkout is /home/chenhy/workspace/web3-portfolio/b2-lending in WSL Ubuntu-24.04. The Windows checkout is D:/appspace/web3prepare/b2-lending.

1. Inspect git status in both checkouts. Preserve local changes in a named stash or backup.
2. Make code changes and run the appropriate tests in WSL.
3. Commit in WSL and push that commit to origin/main.
4. In Windows, run git fetch origin followed by git merge --ff-only origin/main.
5. Compare git rev-parse HEAD in both checkouts and verify tracked-file content.

Never use reset --hard to synchronize. Windows changes must be deliberately migrated into WSL before they can enter the canonical history.

The original WSL work was preserved in a stash named presync-2026-11-08-preserve-local-audit before fast-forwarding to 7c7c892. Windows local audit notes and the frontend fix are preserved separately before its final pull.

## Network fallback

When Linux HTTPS cannot reach GitHub through the host VPN, Windows Git can be invoked from WSL with -C pointing to the WSL checkout UNC path. This uses the same WSL working tree and commit, with the host credential manager and network transport. No credential is embedded in project files. The ordinary Linux git push remains preferred when its connection is available.
