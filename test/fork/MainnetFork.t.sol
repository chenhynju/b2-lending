// SPDX-License-Identifier: MIT
pragma solidity 0.8.38;
import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {LendingVault} from "../../src/LendingVault.sol";
import {FeedOracle} from "../../src/FeedOracle.sol";

contract MainnetForkTest is Test {
    /// @notice Optional pinned mainnet fork: real USDT optional-return behavior, WETH and USD feeds.
    function testPinnedMainnetUSDTMarket() public {
        string memory rpc = vm.envOr("MAINNET_RPC_URL", string(""));
        if (bytes(rpc).length == 0) {
            vm.skip(true);
            return;
        }
        vm.createSelectFork(rpc, vm.envOr("MAINNET_FORK_BLOCK", uint256(26344752)));
        address usdt = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
        address weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
        FeedOracle o = new FeedOracle(
            0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419, 0x3E7d1eAB13ad0104d2750B8863b489D65364e32D, address(0), 1 days
        );
        LendingVault v = new LendingVault(usdt, weth, address(o));
        // Balance provisioning is explicitly synthetic; token/feed code and all state are pinned real mainnet.
        deal(usdt, address(this), 10000e6);
        deal(weth, address(this), 10 ether);
        (bool ok,) = usdt.call(abi.encodeWithSignature("approve(address,uint256)", address(v), type(uint256).max));
        assertTrue(ok);
        IERC20(weth).approve(address(v), type(uint256).max);
        v.deposit(10000e6, 0);
        v.addCollateral(1 ether);
        v.borrow(100e6);
        uint256 s = v.debtShares(address(this));
        v.repay(address(this), s, type(uint256).max);
        v.removeCollateral(1 ether);
        v.redeem(v.balanceOf(address(this)), 10000e6);
        assertEq(v.totalAssets(), 0);
        assertGt(o.price(), 0);
    }
}
