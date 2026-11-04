// SPDX-License-Identifier: MIT
pragma solidity 0.8.38;
import {Test} from "forge-std/Test.sol";
import {LendingVault} from "../../src/LendingVault.sol";
import {MockToken, MockOracle} from "../mocks/Mocks.sol";

/// @notice Stateful multi-actor driver. No catch-and-ignore of unexpected vault reverts.
contract LendingHandler is Test {
    LendingVault public immutable vault;
    MockToken public immutable loan;
    MockToken public immutable coll;
    MockOracle public immutable oracle;
    address[4] public actors;
    uint256 public deposits;
    uint256 public withdrawals;
    uint256 public borrows;
    uint256 public repayments;
    uint256 public liquidationPayments;
    uint256 public mintedShares;
    uint256 public burnedShares;
    uint256 public collateralIn;
    uint256 public collateralOut;
    uint256 public successfulBorrows;
    uint256 public successfulLiquidations;
    uint256 public lastIndex;
    bool public indexMonotonic = true;

    constructor(LendingVault v, MockToken a, MockToken c, MockOracle o) {
        vault = v;
        loan = a;
        coll = c;
        oracle = o;
        lastIndex = v.borrowIndex();
        for (uint256 i; i < 4; i++) {
            address user = address(uint160(0x100 + i));
            actors[i] = user;
            loan.mint(user, 1e24);
            coll.mint(user, 1e24);
            vm.startPrank(user);
            loan.approve(address(v), type(uint256).max);
            coll.approve(address(v), type(uint256).max);
            vm.stopPrank();
        }
    }

    function _observe() private {
        uint256 index = vault.borrowIndex();
        if (index < lastIndex) indexMonotonic = false;
        lastIndex = index;
    }

    function deposit(uint256 who, uint256 amount) external {
        address user = actors[who % 4];
        amount = bound(amount, 1, 1e10);
        uint256 managed = vault.totalAssets();
        if (managed + amount > vault.DEPOSIT_CAP() || (managed == 0 && vault.totalSupply() != 0)) return;
        if (vault.previewDeposit(amount) == 0 || loan.balanceOf(user) < amount) return;
        vm.prank(user);
        uint256 shares = vault.deposit(amount, 0);
        deposits += amount;
        mintedShares += shares;
        _observe();
    }

    function withdraw(uint256 who, uint256 amount) external {
        address user = actors[who % 4];
        uint256 supply = vault.totalSupply();
        if (supply == 0) return;
        uint256 available = vault.balanceOf(user) * vault.totalAssets() / supply;
        available = available < vault.cash() ? available : vault.cash();
        if (available == 0) return;
        amount = bound(amount, 1, available);
        uint256 managed = vault.totalAssets();
        if ((amount * supply + managed - 1) / managed == supply && amount != managed) return;
        vm.prank(user);
        uint256 shares = vault.withdraw(amount, type(uint256).max);
        withdrawals += amount;
        burnedShares += shares;
        _observe();
    }

    function redeem(uint256 who, uint256 shares) external {
        address user = actors[who % 4];
        uint256 balance = vault.balanceOf(user);
        if (balance == 0) return;
        shares = bound(shares, 1, balance);
        if (shares * vault.totalAssets() / vault.totalSupply() > vault.cash()) return;
        vm.prank(user);
        uint256 assets = vault.redeem(shares, 0);
        withdrawals += assets;
        burnedShares += shares;
        _observe();
    }

    function addCollateral(uint256 who, uint256 amount) external {
        address user = actors[who % 4];
        amount = bound(amount, 1e12, 10 ether);
        if (coll.balanceOf(user) < amount) return;
        vm.prank(user);
        vault.addCollateral(amount);
        collateralIn += amount;
        _observe();
    }

    function removeCollateral(uint256 who, uint256 amount) external {
        address user = actors[who % 4];
        uint256 balance = vault.collateralOf(user);
        if (balance == 0) return;
        amount = bound(amount, 1, balance);
        uint256 value = (balance - amount) * oracle.value() / 1e30;
        if (vault.debtOf(user) > value * 75 / 100) return;
        vm.prank(user);
        vault.removeCollateral(amount);
        collateralOut += amount;
        _observe();
        if (vault.debtShares(user) != 0) assertGe(vault.healthFactor(user), 1e18);
    }

    function borrow(uint256 who, uint256 amount) external {
        address user = actors[who % 4];
        uint256 value = vault.collateralOf(user) * oracle.value() / 1e30;
        uint256 maxDebt = value * 75 / 100;
        uint256 debt = vault.debtOf(user);
        if (maxDebt <= debt + 2 || vault.cash() == 0) return;
        uint256 available = maxDebt - debt - 2;
        if (available > vault.cash()) available = vault.cash();
        if (available > 1e10) available = 1e10;
        amount = bound(amount, 1, available);
        vm.prank(user);
        vault.borrow(amount);
        borrows += amount;
        successfulBorrows++;
        _observe();
        assertGe(vault.healthFactor(user), 1e18);
    }

    function repay(uint256 who, uint256 shares) external {
        address user = actors[who % 4];
        uint256 debt = vault.debtShares(user);
        if (debt == 0) return;
        shares = bound(shares, 1, debt);
        if (vault.debtOf(user) > loan.balanceOf(user)) return;
        vm.prank(user);
        uint256 paid = vault.repay(user, shares, type(uint256).max);
        repayments += paid;
        _observe();
    }

    function liquidate(uint256 who, uint256 payer) external {
        address user = actors[who % 4];
        address userPayer = actors[payer % 4];
        if (vault.debtShares(user) == 0 || vault.healthFactor(user) >= 1e18) return;
        if (loan.balanceOf(userPayer) < vault.debtOf(user)) return;
        vm.prank(userPayer);
        (uint256 paid, uint256 seized) = vault.liquidate(user, type(uint256).max, type(uint256).max, 0);
        liquidationPayments += paid;
        collateralOut += seized;
        successfulLiquidations++;
        _observe();
        assertEq(vault.debtShares(user), 0, "full liquidation must clear debt");
    }

    function price(uint256 p) external {
        oracle.setPrice(bound(p, 100e18, 4000e18));
    }

    function elapse(uint256 dt) external {
        vm.warp(block.timestamp + bound(dt, 0, 7 days));
        vault.accrue();
        _observe();
    }

    function donate(uint256 amount) external {
        amount = bound(amount, 1, 1e10);
        loan.mint(address(vault), amount);
        coll.mint(address(vault), amount);
    }

    function transferShares(uint256 from, uint256 to, uint256 shares) external {
        address sender = actors[from % 4];
        uint256 balance = vault.balanceOf(sender);
        if (balance == 0) return;
        vm.prank(sender);
        vault.transfer(actors[to % 4], bound(shares, 0, balance));
    }
}
