// SPDX-License-Identifier: MIT
pragma solidity 0.8.38;
import {LendingVault} from "../src/LendingVault.sol";
import {MockToken, MockOracle} from "./mocks/Mocks.sol";

contract AuditVaultEchidna {
    MockToken private loan;
    MockToken private collateral;
    MockOracle private oracle;
    LendingVault private vault;

    constructor() {
        loan = new MockToken(6);
        collateral = new MockToken(18);
        oracle = new MockOracle();
        vault = new LendingVault(address(loan), address(collateral), address(oracle));
        loan.mint(address(this), 20_000e6);
        collateral.mint(address(this), 10 ether);
        loan.approve(address(vault), type(uint256).max);
        collateral.approve(address(vault), type(uint256).max);
        vault.deposit(5_000e6, 0);
        vault.addCollateral(1 ether);
    }

    function supply(uint64 seed) external {
        uint256 amount = uint256(seed) % 1000e6 + 1;
        if (loan.balanceOf(address(this)) >= amount) vault.deposit(amount, 0);
    }

    function borrow(uint64 seed) external {
        uint256 amount = uint256(seed) % 1000e6 + 1;
        if (vault.debtShares(address(this)) == 0 && vault.cash() >= amount) vault.borrow(amount);
    }

    function repay() external {
        uint256 shares = vault.debtShares(address(this));
        if (shares > 0 && loan.balanceOf(address(this)) >= vault.debtOf(address(this))) {
            vault.repay(address(this), shares, type(uint256).max);
        }
    }

    function exitMarket() external {
        uint256 shares = vault.balanceOf(address(this));
        if (shares > 0 && vault.totalDebtShares() == 0) vault.redeem(shares, 0);
    }

    function echidna_cash_conserved() external view returns (bool) {
        return loan.balanceOf(address(vault)) == vault.cash()
            && vault.cash() + loan.balanceOf(address(this)) == 20_000e6;
    }

    function echidna_collateral_conserved() external view returns (bool) {
        return collateral.balanceOf(address(vault)) == vault.totalCollateral()
            && vault.totalCollateral() + collateral.balanceOf(address(this)) == 10 ether;
    }

    function echidna_claims_accounted() external view returns (bool) {
        return vault.totalAssets() == vault.cash() + vault.totalDebt()
            && vault.totalSupply() == vault.balanceOf(address(this))
            && vault.totalDebtShares() == vault.debtShares(address(this));
    }
}
