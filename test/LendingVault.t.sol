// SPDX-License-Identifier: MIT
pragma solidity 0.8.38;
import {Test} from "forge-std/Test.sol";
import {LendingVault} from "../src/LendingVault.sol";
import {InterestRateModel} from "../src/InterestRateModel.sol";
import {MockToken, MockOracle, NoReturnToken} from "./mocks/Mocks.sol";

contract LendingVaultTest is Test {
    MockToken internal loan;
    MockToken internal coll;
    MockOracle internal oracle;
    LendingVault internal vault;
    address internal alice = address(0xA11CE);
    address internal bob = address(0xB0B);
    address internal liquidator = address(0xC1EA);
    uint256 internal constant U = 1e6;

    function setUp() public {
        vm.warp(10 days);
        loan = new MockToken(6);
        coll = new MockToken(18);
        oracle = new MockOracle();
        vault = new LendingVault(address(loan), address(coll), address(oracle));
        _fund(alice);
        _fund(bob);
        _fund(liquidator);
    }

    function _fund(address user) internal {
        loan.mint(user, 1e15);
        coll.mint(user, 1000 ether);
        vm.startPrank(user);
        loan.approve(address(vault), type(uint256).max);
        coll.approve(address(vault), type(uint256).max);
        vm.stopPrank();
    }

    function _redeemAll(address user, uint256 minAssets) internal returns (uint256) {
        uint256 s = vault.balanceOf(user);
        vm.prank(user);
        return vault.redeem(s, minAssets);
    }

    function _repayAll(address payer, address borrower) internal {
        uint256 s = vault.debtShares(borrower);
        vm.prank(payer);
        vault.repay(borrower, s, type(uint256).max);
    }

    function _deposit() internal {
        vm.prank(alice);
        vault.deposit(10_000 * U, 0);
    }

    function _position() internal {
        _deposit();
        vm.startPrank(bob);
        vault.addCollateral(1 ether);
        vault.borrow(1000 * U);
        vm.stopPrank();
    }

    function testDepositWithdrawRedeem() public {
        _deposit();
        assertEq(vault.decimals(), 12);
        assertEq(vault.balanceOf(alice), 10_000 * U * 1e6);
        vm.startPrank(alice);
        vault.withdraw(1000 * U, type(uint256).max);
        vault.redeem(vault.balanceOf(alice), 0);
        vm.stopPrank();
        assertEq(vault.cash(), 0);
        assertEq(vault.totalSupply(), 0);
    }

    function testInterestAndFullRepayment() public {
        _position();
        uint256 initial = vault.totalAssets();
        vm.warp(block.timestamp + 365 days);
        assertGt(vault.debtOf(bob), 1000 * U);
        assertGt(vault.totalAssets(), initial);
        vault.accrue();
        _repayAll(bob, bob);
        assertEq(vault.totalDebt(), 0);
        vm.prank(bob);
        vault.removeCollateral(1 ether);
        _redeemAll(alice, 0);
        assertEq(vault.totalAssets(), 0);
    }

    function testThirdPartyRepayment() public {
        _position();
        _repayAll(alice, bob);
        assertEq(vault.debtShares(bob), 0);
        assertEq(vault.collateralOf(bob), 1 ether);
    }

    function testPartialRepaymentRoundsUp() public {
        _position();
        vm.warp(block.timestamp + 123 days);
        vault.accrue();
        uint256 s = vault.debtShares(bob) / 3;
        uint256 before = vault.cash();
        vm.prank(bob);
        uint256 paid = vault.repay(bob, s, type(uint256).max);
        assertEq(vault.cash() - before, paid);
        assertEq(paid, (s * vault.borrowIndex() + 1e27 - 1) / 1e27);
    }

    function testBorrowLTVAndWithdrawCollateralChecks() public {
        _position();
        vm.startPrank(bob);
        vm.expectRevert(LendingVault.UnsafePosition.selector);
        vault.borrow(501 * U);
        vm.expectRevert(LendingVault.UnsafePosition.selector);
        vault.removeCollateral(1 ether);
        vault.removeCollateral(0.1 ether);
        vm.stopPrank();
        assertGe(vault.healthFactor(bob), 1e18);
    }

    function testBorrowAtLTVBoundary() public {
        _deposit();
        vm.startPrank(bob);
        vault.addCollateral(1 ether);
        vault.borrow(1500 * U);
        vm.expectRevert(LendingVault.UnsafePosition.selector);
        vault.borrow(1);
        vm.stopPrank();
    }

    function testInsufficientLiquidity() public {
        _position();
        vm.prank(alice);
        vm.expectRevert(LendingVault.InsufficientLiquidity.selector);
        vault.withdraw(9001 * U, type(uint256).max);
    }

    function testHealthyCannotBeLiquidated() public {
        _position();
        vm.prank(liquidator);
        vm.expectRevert(LendingVault.HealthyPosition.selector);
        vault.liquidate(bob, type(uint256).max, type(uint256).max, 0);
    }

    function testPartialAndFullLiquidation() public {
        _position();
        oracle.setPrice(1200e18);
        vm.startPrank(liquidator);
        (uint256 paid, uint256 seized) = vault.liquidate(bob, 100 * U, type(uint256).max, 0);
        assertEq(paid, 100 * U);
        assertEq(seized, 0.0875 ether);
        vault.liquidate(bob, type(uint256).max, type(uint256).max, 0);
        vm.stopPrank();
        assertEq(vault.debtShares(bob), 0);
        assertGt(vault.collateralOf(bob), 0);
        assertEq(vault.cumulativeBadDebt(), 0);
    }

    function testGapLossSocialization() public {
        _position();
        oracle.setPrice(500e18);
        uint256 before = vault.totalAssets();
        vm.prank(liquidator);
        (uint256 paid, uint256 seized) = vault.liquidate(bob, type(uint256).max, type(uint256).max, 1 ether);
        assertEq(seized, 1 ether);
        assertLe(paid, 500 * U);
        assertEq(vault.debtShares(bob), 0);
        assertEq(vault.collateralOf(bob), 0);
        assertEq(before - vault.totalAssets(), vault.cumulativeBadDebt());
        _redeemAll(alice, 0);
        assertEq(vault.totalAssets(), 0);
    }

    function testDustLiquidationAndRestart() public {
        vm.prank(alice);
        vault.deposit(1, 0);
        vm.startPrank(bob);
        vault.addCollateral(1 ether);
        vault.borrow(1);
        vm.stopPrank();
        oracle.setPrice(1);
        vm.prank(liquidator);
        (uint256 paid,) = vault.liquidate(bob, type(uint256).max, 0, 0);
        assertEq(paid, 0);
        assertEq(vault.totalAssets(), 0);
        vm.prank(alice);
        vm.expectRevert(LendingVault.InsolventMarket.selector);
        vault.deposit(1, 0);
        _redeemAll(alice, 0);
        vm.prank(alice);
        vault.deposit(1, 0);
        assertEq(vault.totalAssets(), 1);
    }

    function testDonationCannotInflatePrice() public {
        vm.prank(alice);
        vault.deposit(1, 0);
        vm.prank(alice);
        loan.transfer(address(vault), 10_000 * U);
        assertEq(vault.totalAssets(), 1);
        assertEq(vault.previewDeposit(100 * U), 100 * U * 1e6);
        vm.prank(bob);
        vault.deposit(100 * U, 100 * U * 1e6);
        _redeemAll(alice, 1);
        assertEq(_redeemAll(bob, 0), 100 * U);
        assertEq(loan.balanceOf(address(vault)), 10_000 * U);
    }

    function testNoSameTransactionProfit() public {
        _position();
        uint256 before = loan.balanceOf(liquidator);
        vm.startPrank(liquidator);
        uint256 shares = vault.deposit(1000 * U, 0);
        vault.redeem(shares, 0);
        vm.stopPrank();
        assertEq(loan.balanceOf(liquidator), before);
    }

    function testShareTransfer() public {
        _deposit();
        uint256 s = vault.balanceOf(alice);
        vm.prank(alice);
        vault.transfer(bob, s);
        vm.prank(bob);
        vault.redeem(s, 10_000 * U);
        assertEq(vault.cash(), 0);
    }

    function testOracleFailureAllowsRepaymentAndCollateralTopup() public {
        _position();
        oracle.setFail(true);
        vm.startPrank(bob);
        vm.expectRevert();
        vault.borrow(1);
        vm.expectRevert();
        vault.removeCollateral(1);
        vault.addCollateral(1 ether);
        vault.repay(bob, vault.debtShares(bob), type(uint256).max);
        vault.removeCollateral(2 ether);
        vm.stopPrank();
        _redeemAll(alice, 0);
    }

    function testInvalidOracleBounds() public {
        _position();
        oracle.setPrice(0);
        vm.prank(bob);
        vm.expectRevert(LendingVault.InvalidOraclePrice.selector);
        vault.borrow(1);
        oracle.setPrice(1e36 + 1);
        vm.prank(bob);
        vm.expectRevert(LendingVault.InvalidOraclePrice.selector);
        vault.borrow(1);
    }

    function testFeeOnTransferIncomingRejected() public {
        loan.setFee(true);
        vm.prank(alice);
        vm.expectRevert(LendingVault.UnsupportedToken.selector);
        vault.deposit(100 * U, 0);
        assertEq(vault.totalSupply(), 0);
        coll.setFee(true);
        vm.prank(bob);
        vm.expectRevert(LendingVault.UnsupportedToken.selector);
        vault.addCollateral(1 ether);
    }

    function testOutgoingFeeAndFalseReturnRejected() public {
        _position();
        loan.setFee(true);
        vm.prank(alice);
        vm.expectRevert(LendingVault.UnsupportedToken.selector);
        vault.withdraw(100 * U, type(uint256).max);
        loan.setFee(false);
        loan.setFail(true);
        vm.prank(alice);
        vm.expectRevert();
        vault.withdraw(100 * U, type(uint256).max);
        coll.setFee(true);
        vm.prank(bob);
        vm.expectRevert(LendingVault.UnsupportedToken.selector);
        vault.removeCollateral(0.1 ether);
    }

    function testNegativeRebaseDetected() public {
        _position();
        loan.burn(address(vault), 1);
        vm.prank(bob);
        vm.expectRevert(LendingVault.UnsupportedToken.selector);
        vault.borrow(1);
    }

    function testMutationAndReadOnlyReentrancyRejected() public {
        loan.setHook(address(vault));
        _deposit();
        assertTrue(loan.mutationBlocked());
        assertTrue(loan.viewBlocked());
        vm.prank(alice);
        vault.withdraw(100 * U, type(uint256).max);
        assertTrue(loan.mutationBlocked());
        assertTrue(loan.viewBlocked());
        coll.setHook(address(vault));
        vm.prank(bob);
        vault.addCollateral(1 ether);
        assertTrue(coll.mutationBlocked());
        assertTrue(coll.viewBlocked());
    }

    function testNoReturnUSDTStyleToken() public {
        NoReturnToken t = new NoReturnToken();
        LendingVault v = new LendingVault(address(t), address(coll), address(oracle));
        t.mint(address(this), 100 * U);
        t.approve(address(v), 100 * U);
        v.deposit(100 * U, 0);
        v.redeem(v.balanceOf(address(this)), 100 * U);
        assertEq(t.balanceOf(address(this)), 100 * U);
    }

    function testSlippageProtection() public {
        vm.prank(alice);
        vm.expectRevert(LendingVault.Slippage.selector);
        vault.deposit(1, 1e6 + 1);
        _position();
        vm.prank(alice);
        vm.expectRevert(LendingVault.Slippage.selector);
        vault.withdraw(U, 0);
        vm.prank(alice);
        vm.expectRevert(LendingVault.Slippage.selector);
        vault.redeem(U, 1e20);
        vm.prank(bob);
        vm.expectRevert(LendingVault.Slippage.selector);
        vault.repay(bob, U, 0);
        oracle.setPrice(1200e18);
        vm.prank(liquidator);
        vm.expectRevert(LendingVault.Slippage.selector);
        vault.liquidate(bob, U, 0, 0);
        vm.prank(liquidator);
        vm.expectRevert(LendingVault.Slippage.selector);
        vault.liquidate(bob, U, U, type(uint256).max);
    }

    function testInvalidAmounts() public {
        uint256 cap = vault.DEPOSIT_CAP();
        vm.expectRevert(LendingVault.InvalidAmount.selector);
        vault.deposit(0, 0);
        vm.expectRevert(LendingVault.InvalidAmount.selector);
        vault.deposit(cap + 1, 0);
        vm.expectRevert(LendingVault.InvalidAmount.selector);
        vault.withdraw(0, 0);
        vm.expectRevert(LendingVault.InvalidAmount.selector);
        vault.redeem(0, 0);
        vm.expectRevert(LendingVault.InvalidAmount.selector);
        vault.addCollateral(0);
        vm.expectRevert(LendingVault.InvalidAmount.selector);
        vault.addCollateral(cap + 1);
        vm.expectRevert(LendingVault.InvalidAmount.selector);
        vault.removeCollateral(1);
        vm.expectRevert(LendingVault.InvalidAmount.selector);
        vault.borrow(0);
        vm.expectRevert(LendingVault.InsufficientLiquidity.selector);
        vault.borrow(1);
        vm.expectRevert(LendingVault.InvalidAmount.selector);
        vault.repay(bob, 1, 0);
        vm.expectRevert(LendingVault.InvalidAmount.selector);
        vault.liquidate(bob, 1, 0, 0);
    }

    function testConstructorRejectsInvalidConfiguration() public {
        vm.expectRevert(LendingVault.InvalidConfiguration.selector);
        new LendingVault(address(loan), address(loan), address(oracle));
        vm.expectRevert(LendingVault.InvalidConfiguration.selector);
        new LendingVault(address(0), address(coll), address(oracle));
        vm.expectRevert(LendingVault.InvalidConfiguration.selector);
        new LendingVault(address(loan), address(coll), address(0));
        MockToken invalid = new MockToken(19);
        vm.expectRevert(LendingVault.InvalidConfiguration.selector);
        new LendingVault(address(invalid), address(coll), address(oracle));
    }

    function testInterestIndexCapAndIdleAccrual() public {
        uint256 start = vault.borrowIndex();
        vm.warp(block.timestamp + 365 days);
        vault.accrue();
        assertEq(vault.borrowIndex(), start);
        _position();
        vm.warp(block.timestamp + 365 days * 1e12);
        vault.accrue();
        assertEq(vault.borrowIndex(), vault.MAX_INDEX());
        vm.warp(block.timestamp + 365 days);
        vault.accrue();
        assertEq(vault.borrowIndex(), vault.MAX_INDEX());
    }

    function testFuzz_DepositRedeem(uint256 amount) public {
        amount = bound(amount, 1, 1e14);
        vm.startPrank(alice);
        uint256 s = vault.deposit(amount, 0);
        assertEq(vault.redeem(s, 0), amount);
        vm.stopPrank();
    }

    function testFuzz_BorrowRepayRounding(uint256 amount, uint256 elapsed) public {
        _position();
        elapsed = bound(elapsed, 1, 365 days);
        amount = bound(amount, 1, 100 * U);
        vm.warp(block.timestamp + elapsed);
        vault.accrue();
        uint256 before = vault.totalAssets();
        vm.startPrank(bob);
        uint256 s = vault.borrow(amount);
        vault.repay(bob, s, type(uint256).max);
        vm.stopPrank();
        assertGe(vault.totalAssets(), before);
    }

    function testFuzz_RateMonotonic(uint256 a, uint256 b) public pure {
        a = bound(a, 0, 1e18);
        b = bound(b, a, 1e18);
        assertLe(InterestRateModel.rate(a), InterestRateModel.rate(b));
        assertLe(InterestRateModel.rate(b), 1e18);
    }

    function testRateBoundaries() public {
        assertEq(InterestRateModel.rate(0), 2e16);
        assertEq(InterestRateModel.rate(8e17), 1e17);
        assertEq(InterestRateModel.rate(1e18), 1e18);
        vm.expectRevert(InterestRateModel.InvalidUtilization.selector);
        this.rate(1e18 + 1);
    }

    function testRegression_LastShareCannotOrphanReceivables() public {
        vm.prank(alice);
        vault.deposit(2, 0);
        vm.startPrank(bob);
        vault.addCollateral(1 ether);
        vault.borrow(1);
        vm.stopPrank();
        uint256 shares = vault.balanceOf(alice);
        vm.prank(alice);
        vault.redeem(shares - 1, 0);
        assertEq(vault.totalSupply(), 1);
        vm.warp(block.timestamp + 2 * 365 days);
        vault.accrue();
        _repayAll(bob, bob);
        vm.prank(bob);
        vault.borrow(1);
        vm.prank(alice);
        vm.expectRevert(LendingVault.InvalidAmount.selector);
        vault.withdraw(1, 1);
        assertEq(vault.totalSupply(), 1);
        assertEq(vault.totalAssets(), 5);
    }

    function rate(uint256 u) external pure returns (uint256) {
        return InterestRateModel.rate(u);
    }
}
