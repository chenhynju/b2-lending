// SPDX-License-Identifier: MIT
pragma solidity 0.8.38;
import {Test} from "forge-std/Test.sol";
import {LendingFixture} from "./fixtures/LendingFixture.sol";
import {LendingVault} from "../src/LendingVault.sol";
import {MockToken} from "./mocks/Mocks.sol";

/// @notice Supplemental failure and dust paths, staged separately during the frozen fuzz campaign.
contract AdditionalLendingTest is LendingFixture {
    function testDebtFreeHealthAndBaseRate() public view {
        assertEq(vault.healthFactor(bob), type(uint256).max);
        assertEq(vault.borrowRate(), 2e16);
        assertEq(vault.previewDeposit(7), 7e6);
    }

    function testRedeemBlockedUntilBorrowerRepays() public {
        _position();
        uint256 shares = vault.balanceOf(alice);
        vm.prank(alice);
        vm.expectRevert(LendingVault.InsufficientLiquidity.selector);
        vault.redeem(shares, 0);
        _repayAll(bob, bob);
        _redeemAll(alice, 0);
    }

    function testWorthlessShareQuoteFailsClosed() public {
        vm.prank(alice);
        vault.deposit(1, 0);
        vm.startPrank(bob);
        vault.addCollateral(1 ether);
        vault.borrow(1);
        vm.stopPrank();
        oracle.setPrice(1);
        vm.prank(liquidator);
        vault.liquidate(bob, type(uint256).max, 0, 0);
        vm.expectRevert(LendingVault.InsolventMarket.selector);
        vault.previewDeposit(1);
        assertEq(vault.totalAssets(), 0);
    }

    function testLiquidationDustCannotTakePaymentForZeroCollateral() public {
        _position();
        oracle.setPrice(1e36);
        // Debt becomes unhealthy only through an independent price fall, never a market donation.
        oracle.setPrice(1200e18);
        // One loan raw unit still yields collateral for 18-decimal tokens; use zero-decimal collateral.
        MockToken integerCollateral = new MockToken(0);
        LendingVault v = new LendingVault(address(loan), address(integerCollateral), address(oracle));
        loan.approve(address(v), type(uint256).max);
        loan.mint(address(this), 10000e6);
        v.deposit(10000e6, 0);
        integerCollateral.mint(address(this), 1);
        integerCollateral.approve(address(v), 1);
        v.addCollateral(1);
        v.borrow(800e6);
        oracle.setPrice(900e18);
        vm.expectRevert(LendingVault.InvalidAmount.selector);
        v.liquidate(address(this), 1, 1, 0);
    }

    function testCollateralNegativeRebaseStopsMutation() public {
        _position();
        coll.burn(address(vault), 1);
        vm.prank(alice);
        vm.expectRevert(LendingVault.UnsupportedToken.selector);
        vault.deposit(1, 0);
    }

    function testRepayUnauthorizedSharesCannotBeRemoved() public {
        _position();
        uint256 excessiveShares = vault.debtShares(bob) + 1;
        vm.expectRevert(LendingVault.InvalidAmount.selector);
        vault.repay(bob, excessiveShares, type(uint256).max);
    }

    function testAggregateCapsAndZeroShareDeposits() public {
        loan.mint(alice, vault.DEPOSIT_CAP());
        uint256 cap = vault.DEPOSIT_CAP();
        vm.prank(alice);
        vault.deposit(cap, 0);
        vm.prank(bob);
        vm.expectRevert(LendingVault.InvalidAmount.selector);
        vault.deposit(1, 0);
        coll.mint(bob, cap);
        vm.prank(bob);
        vault.addCollateral(cap);
        vm.prank(alice);
        vm.expectRevert(LendingVault.InvalidAmount.selector);
        vault.addCollateral(1);
    }
}
