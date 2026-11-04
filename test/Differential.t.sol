// SPDX-License-Identifier: MIT
pragma solidity 0.8.38;
import {Test} from "forge-std/Test.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {InterestRateModel} from "../src/InterestRateModel.sol";
import {LendingVault} from "../src/LendingVault.sol";
import {MockToken, MockOracle} from "./mocks/Mocks.sol";

contract DifferentialTest is Test {
    function testPythonIntegerVectors() public view {
        uint256[][] memory rows = abi.decode(vm.parseJson(vm.readFile("test/fixtures/reference.json")), (uint256[][]));
        assertEq(rows.length, 256);
        for (uint256 i; i < rows.length; i++) {
            uint256[] memory x = rows[i];
            assertEq(InterestRateModel.rate(x[0]), x[1]);
            uint256 next = x[2] + Math.mulDiv(x[2], Math.mulDiv(x[1], x[3], 365 days), 1e18);
            assertEq(Math.min(next, 1e36), x[4]);
            assertEq(Math.mulDiv(x[5], x[6], x[7]), x[8]);
            assertEq(Math.mulDiv(x[5], x[6], x[7], Math.Rounding.Ceil), x[9]);
            assertEq(Math.mulDiv(x[5], 1e27, x[2], Math.Rounding.Ceil), x[10]);
            assertEq(Math.mulDiv(x[5], x[2], 1e27, Math.Rounding.Ceil), x[11]);
        }
    }

    /// @notice Compare actual checkpointed storage with the separately derived APR equation.
    function testFuzz_ActualAccrual(uint256 borrowed, uint256 dt) public {
        borrowed = bound(borrowed, 1, 10000e6);
        dt = bound(dt, 0, 10 * 365 days);
        MockToken a = new MockToken(6);
        MockToken c = new MockToken(18);
        MockOracle o = new MockOracle();
        LendingVault v = new LendingVault(address(a), address(c), address(o));
        a.mint(address(this), 10000e6);
        c.mint(address(this), 100 ether);
        a.approve(address(v), type(uint256).max);
        c.approve(address(v), type(uint256).max);
        v.deposit(10000e6, 0);
        v.addCollateral(100 ether);
        v.borrow(borrowed);
        uint256 utilization = borrowed * 1e18 / 10000e6;
        uint256 r = utilization <= 8e17 ? 2e16 + utilization / 10 : 1e17 + (utilization - 8e17) * 9 / 2;
        uint256 expected = 1e27 + 1e27 * (r * dt / (365 days)) / 1e18;
        vm.warp(block.timestamp + dt);
        v.accrue();
        assertEq(v.borrowIndex(), expected);
    }
}
