from pathlib import Path
import shutil,json
r=Path('/home/chenhy/workspace/web3-portfolio/b2-lending')
for name in ['forge-std','openzeppelin-contracts']:
 src=Path('/mnt/d/appspace/web3prepare/b2-amm/lib')/name
 print(name,json.loads((src/'package.json').read_text())['version'])
 shutil.copytree(src,r/'lib'/name,dirs_exist_ok=True)
for d in ['src','test','evidence','scripts']: (r/d).mkdir(exist_ok=True)
(r/'foundry.toml').write_text('''[profile.default]
src = "src"
test = "test"
script = "script"
out = "out"
libs = ["lib"]
solc_version = "0.8.28"
evm_version = "cancun"
optimizer = true
optimizer_runs = 1000
via_ir = true
bytecode_hash = "ipfs"
remappings = ["@openzeppelin/contracts/=lib/openzeppelin-contracts/contracts/"]
[profile.default.fuzz]
runs = 1024
[profile.default.invariant]
runs = 128
depth = 64
[profile.ci.fuzz]
runs = 10000
[profile.ci.invariant]
runs = 512
depth = 256
[profile.deep.fuzz]
runs = 50000
[profile.deep.invariant]
runs = 1000
depth = 512
''')
(r/'src/LendingVault.sol').write_text('''// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/// @title LendingVault initialization scaffold
/// @notice Interface planning only. No assets may be entrusted to this scaffold.
/// @dev All operations revert until accounting, oracle checks and tests are implemented.
contract LendingVault {
    /// @notice Signals an intentionally unimplemented operation.
    error NotImplemented();

    /// @notice Planned lender deposit, with shares rounded down.
    /// @param assets Amount of the loan asset in native token units.
    /// @return shares Planned lender shares minted.
    function deposit(uint256 assets) external pure returns (uint256 shares) {
        assets; shares; revert NotImplemented();
    }
    /// @notice Planned withdrawal constrained by available liquidity.
    function withdraw(uint256 assets) external pure { assets; revert NotImplemented(); }
    /// @notice Planned collateral deposit for the caller.
    function addCollateral(uint256 amount) external pure { amount; revert NotImplemented(); }
    /// @notice Planned collateral withdrawal subject to health checks.
    function removeCollateral(uint256 amount) external pure { amount; revert NotImplemented(); }
    /// @notice Planned overcollateralized borrow using a fresh independent oracle.
    function borrow(uint256 assets) external pure { assets; revert NotImplemented(); }
    /// @notice Planned debt repayment and debt-share settlement.
    function repay(uint256 assets) external pure { assets; revert NotImplemented(); }
    /// @notice Planned liquidation with capped seizure and explicit bad-debt settlement.
    function liquidate(address borrower, uint256 assets) external pure {
        borrower; assets; revert NotImplemented();
    }
}
''')
(r/'test/LendingVault.t.sol').write_text('''// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;
import {Test} from "forge-std/Test.sol";
import {LendingVault} from "../src/LendingVault.sol";
/// @notice Scaffold checks only; these do not verify a lending protocol.
contract LendingVaultTest is Test {
    LendingVault internal vault;
    function setUp() public { vault = new LendingVault(); }
    function testScaffoldRejectsDeposits() public {
        vm.expectRevert(LendingVault.NotImplemented.selector);
        vault.deposit(1 ether);
    }
}
''')
shutil.copy('/mnt/d/appspace/web3prepare/AGENTS.md',r/'AGENTS.md')
shutil.copy('/mnt/d/appspace/web3prepare/b2-amm/scripts/dependencies.py',r/'scripts/dependencies.py')
(r/'README.md').write_text('''# B2 Lending Vault\n\nInitialization scaffold only. No lending functionality or security assurance is delivered yet.\n\n## Quick start\n\nRun in WSL Ubuntu from this Foundry root:\n\n```sh\nforge test\n```\n\n## Status\n\nImplements only a reverting API scaffold. Unit, fuzz, handler invariants, economic analysis, audit, frontend, fork and deployment acceptance remain NOT RUN. Solidity 0.8.28 is the mandated initialization baseline; compiler security review is required before release. Public signing and broadcasting require separate explicit authorization under AGENTS.md section 8.4.\n''')
(r/'.gitignore').write_text('.env\n.env.*\n!.env.example\nout/\ncache/\nbroadcast/\n*.key\nkeystore/\n')
(r/'.env.example').write_text('# No environment variables are consumed by this initialization scaffold.\n')
