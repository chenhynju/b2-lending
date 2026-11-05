// SPDX-License-Identifier: MIT
pragma solidity 0.8.38;
import {Test} from "forge-std/Test.sol";
import {LendingVault} from "../../src/LendingVault.sol";
import {MockToken, MockOracle} from "../mocks/Mocks.sol";

abstract contract LendingFixture is Test {
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
}
