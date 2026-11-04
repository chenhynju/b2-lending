// SPDX-License-Identifier: MIT
pragma solidity 0.8.38;
import {Test} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {LendingVault} from "../src/LendingVault.sol";
import {MockToken, MockOracle} from "./mocks/Mocks.sol";
import {LendingHandler} from "./invariant/LendingHandler.sol";

contract LendingInvariant is StdInvariant, Test {
    LendingVault v;
    MockToken loan;
    MockToken coll;
    MockOracle oracle;
    LendingHandler h;

    function setUp() public {
        vm.warp(10 days);
        loan = new MockToken(6);
        coll = new MockToken(18);
        oracle = new MockOracle();
        v = new LendingVault(address(loan), address(coll), address(oracle));
        h = new LendingHandler(v, loan, coll, oracle);
        bytes4[] memory selectors = new bytes4[](12);
        selectors[0] = h.deposit.selector;
        selectors[1] = h.withdraw.selector;
        selectors[2] = h.redeem.selector;
        selectors[3] = h.addCollateral.selector;
        selectors[4] = h.removeCollateral.selector;
        selectors[5] = h.borrow.selector;
        selectors[6] = h.repay.selector;
        selectors[7] = h.liquidate.selector;
        selectors[8] = h.price.selector;
        selectors[9] = h.elapse.selector;
        selectors[10] = h.donate.selector;
        selectors[11] = h.transferShares.selector;
        targetSelector(FuzzSelector(address(h), selectors));
        targetContract(address(h));
    }

    function invariant_CashConservationGhostLedger() public view {
        assertEq(v.cash() + h.withdrawals() + h.borrows(), h.deposits() + h.repayments() + h.liquidationPayments());
    }

    function invariant_LenderShareSupply() public view {
        uint256 sum;
        for (uint256 i; i < 4; i++) {
            sum += v.balanceOf(h.actors(i));
        }
        assertEq(sum, v.totalSupply());
        assertEq(sum + h.burnedShares(), h.mintedShares());
    }

    function invariant_DebtShareSupply() public view {
        uint256 sum;
        for (uint256 i; i < 4; i++) {
            sum += v.debtShares(h.actors(i));
        }
        assertEq(sum, v.totalDebtShares());
    }

    function invariant_CollateralConservation() public view {
        uint256 sum;
        for (uint256 i; i < 4; i++) {
            sum += v.collateralOf(h.actors(i));
        }
        assertEq(sum, v.totalCollateral());
        assertEq(sum + h.collateralOut(), h.collateralIn());
    }

    function invariant_PhysicalBacking() public view {
        assertGe(loan.balanceOf(address(v)), v.cash());
        assertGe(coll.balanceOf(address(v)), v.totalCollateral());
    }

    function invariant_AssetReceivableIdentity() public view {
        assertEq(v.totalAssets(), v.cash() + v.totalDebt());
    }

    function invariant_IndexMonotonicAndCapped() public view {
        assertTrue(h.indexMonotonic());
        assertGe(v.borrowIndex(), 1e27);
        assertLe(v.borrowIndex(), v.MAX_INDEX());
    }

    function invariant_DebtRoundingBound() public view {
        uint256 sum;
        for (uint256 i; i < 4; i++) {
            sum += v.debtOf(h.actors(i));
        }
        assertGe(sum, v.totalDebt());
        assertLe(sum - v.totalDebt(), 3);
    }

    function invariant_RateBounded() public view {
        assertGe(v.borrowRate(), 2e16);
        assertLe(v.borrowRate(), 1e18);
    }

    /// @notice Close every generated path with funded repayment, collateral release and complete lender exit.
    /// @dev This proves exit WITH external repayment capital, not unconditional withdrawal liquidity.
    function afterInvariant() public {
        v.accrue();
        for (uint256 i; i < 4; i++) {
            address user = h.actors(i);
            uint256 debt = v.debtShares(user);
            if (debt != 0) {
                loan.mint(user, v.debtOf(user));
                vm.prank(user);
                v.repay(user, debt, type(uint256).max);
            }
            uint256 collateral = v.collateralOf(user);
            if (collateral != 0) {
                vm.prank(user);
                v.removeCollateral(collateral);
            }
        }
        for (uint256 i; i < 4; i++) {
            address user = h.actors(i);
            uint256 shares = v.balanceOf(user);
            if (shares != 0) {
                vm.prank(user);
                v.redeem(shares, 0);
            }
        }
        assertEq(v.totalSupply(), 0);
        assertEq(v.totalDebt(), 0);
        assertEq(v.cash(), 0);
        assertEq(v.totalCollateral(), 0);
    }
}
