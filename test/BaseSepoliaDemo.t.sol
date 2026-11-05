// SPDX-License-Identifier: MIT
pragma solidity 0.8.38;

import {Test} from "forge-std/Test.sol";
import {
    DemoAsset,
    DemoQuote,
    DeployBaseSepoliaDemo,
    BaseSepoliaOnly,
    InvalidDemoConfiguration
} from "../script/DeployBaseSepoliaDemo.s.sol";
import {LendingVault} from "../src/LendingVault.sol";

contract BaseSepoliaDemoTest is Test {
    address constant OPERATOR = address(0xABCD);
    address constant LENDER = address(0xBEEF);
    address constant BORROWER = address(0xCAFE);

    DemoAsset loan;
    DemoAsset collateral;
    DemoQuote quote;
    LendingVault vault;

    function setUp() public {
        vm.chainId(84532);
        vm.warp(10 days);
        loan = new DemoAsset("B2 Demo Loan Token", "mUSD", 6, 20_000e6);
        collateral = new DemoAsset("B2 Demo Collateral", "mETH", 18, 10 ether);
        quote = new DemoQuote(OPERATOR);
        vault = new LendingVault(address(loan), address(collateral), address(quote));
    }

    function testOnlyBaseSepolia() public {
        DeployBaseSepoliaDemo deployer = new DeployBaseSepoliaDemo();
        vm.chainId(8453);
        vm.expectRevert(BaseSepoliaOnly.selector);
        deployer.run(OPERATOR);
        vm.expectRevert(BaseSepoliaOnly.selector);
        new DemoAsset("Test", "TEST", 6, 1);
        vm.expectRevert(BaseSepoliaOnly.selector);
        new DemoQuote(OPERATOR);
    }

    function testNoInvalidConfiguration() public {
        vm.expectRevert(InvalidDemoConfiguration.selector);
        new DemoAsset("Test", "TEST", 19, 1);
        vm.expectRevert(InvalidDemoConfiguration.selector);
        new DemoAsset("Test", "TEST", 6, 0);
        vm.expectRevert(InvalidDemoConfiguration.selector);
        new DemoQuote(address(0));
    }

    function testClaimOncePerAddress() public {
        vm.startPrank(LENDER);
        loan.claim();
        vm.expectRevert(DemoAsset.AlreadyClaimed.selector);
        loan.claim();
        vm.stopPrank();
        vm.prank(BORROWER);
        loan.claim();
        assertEq(loan.balanceOf(LENDER), 20_000e6);
        assertEq(loan.balanceOf(BORROWER), 20_000e6);
        assertEq(loan.decimals(), 6);
    }

    function testQuoteAuthorizationAndFreshness() public {
        assertEq(quote.price(), 2000e18);
        vm.prank(BORROWER);
        vm.expectRevert(DemoQuote.Unauthorized.selector);
        quote.setQuote(1000e18);
        vm.prank(OPERATOR);
        vm.expectRevert(DemoQuote.InvalidQuote.selector);
        quote.setQuote(0);
        uint256 maxAge = quote.MAX_AGE();
        vm.warp(block.timestamp + maxAge);
        assertEq(quote.price(), 2000e18);
        vm.warp(block.timestamp + 1);
        vm.expectRevert(DemoQuote.StaleQuote.selector);
        quote.price();
        vm.prank(OPERATOR);
        quote.setQuote(500e18);
        assertEq(quote.price(), 500e18);
    }

    function testDemoLifecycleAndLiquidation() public {
        vm.startPrank(LENDER);
        loan.claim();
        loan.approve(address(vault), 20_000e6);
        uint256 shares = vault.deposit(10_000e6, 0);
        vm.stopPrank();
        vm.startPrank(BORROWER);
        collateral.claim();
        collateral.approve(address(vault), 1 ether);
        vault.addCollateral(1 ether);
        vault.borrow(1000e6);
        vm.stopPrank();
        vm.prank(OPERATOR);
        quote.setQuote(500e18);
        vm.startPrank(LENDER);
        vault.liquidate(BORROWER, type(uint256).max, 1000e6, 1 ether);
        vault.redeem(shares, 0);
        vm.stopPrank();
        assertEq(vault.totalAssets(), 0);
        assertEq(vault.debtShares(BORROWER), 0);
        assertEq(vault.collateralOf(BORROWER), 0);
        assertGt(vault.cumulativeBadDebt(), 0);
    }
}
