# Dependencies and trust
OZ **5.0.2** is vendored from the official tagged archive. Initial WSL git download failed; a 5.4.0 offline copy was temporary and was replaced before the contract freeze. The removed copy was preserved outside the project. forge-std **1.14.0** is test-only. scripts/dependencies.py verifies every vendored file against dependencies.lock.json.

A snapshot of 20 published official repository advisories is stored in evidence/toolchain/oz-advisories.json. Range review found no listed advisory affecting 5.0.2 in that snapshot: the Base64 issue excludes 5.0.2 and the newer Bytes.lastIndexOf issue begins at 5.2.0. The imported runtime set is ERC20/IERC20Metadata, SafeERC20/Address, Math and ReentrancyGuard; no proxy, forwarder, governor or signature verifier is imported. This is not a timeless vulnerability clearance.

[Official advisories](https://github.com/OpenZeppelin/openzeppelin-contracts/security/advisories)
[OZ 5.0.2 source](https://github.com/OpenZeppelin/openzeppelin-contracts/tree/v5.0.2)

Storage ReentrancyGuard is used. ReentrancyGuardTransient was introduced in OZ 5.1, so the pinned 5.0.2 release does not contain it. A fabricated transient-vs-storage benchmark is not reported. No ownership/AccessControl/initializer/storage-upgrade semantics apply because these modules and proxies are absent.

The browser has no runtime SDK/CDN dependency; all token quantities use BigInt. Playwright 1.56.1 is a locked development dependency. A local npm install/audit result is recorded separately and does not audit Solidity dependencies.

The dated OSV querybatch snapshot covers five exact locked npm/library versions and returns no published advisory IDs. It is recorded in evidence/dependency-audit.json; registry coverage and unknown vulnerabilities remain limitations. Offline npm install output alone is not a current advisory clearance.

All 68 vendored forge-std files were compared against the official v1.14.0 archive and match exactly; tag commit and archive digest are in evidence/toolchain/forge-std-provenance.json. OZ v5.0.2 resolves to dbb6104ce834628e473d2173bbc9d47f81a9eec3.
