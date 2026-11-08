methods {
    function cash() external returns (uint256) envfree;
    function totalSupply() external returns (uint256) envfree;
    function totalDebtShares() external returns (uint256) envfree;
    function debtShares(address borrower) external returns (uint256) envfree;
    function collateralOf(address borrower) external returns (uint256) envfree;
    function borrowIndex() external returns (uint256) envfree;
}

invariant indexBounded()
    borrowIndex() >= 1000000000000000000000000000
    && borrowIndex() <= 1000000000000000000000000000000000000;

rule depositAccounting(env e, uint256 assets, uint256 minimumShares) {
    uint256 cashBefore = cash();
    uint256 supplyBefore = totalSupply();
    uint256 minted = deposit(e, assets, minimumShares);
    assert to_mathint(cash()) == to_mathint(cashBefore) + to_mathint(assets);
    assert to_mathint(totalSupply()) == to_mathint(supplyBefore) + to_mathint(minted);
}

rule repaymentAccounting(env e, address borrower, uint256 shares, uint256 maximumAssets) {
    uint256 cashBefore = cash();
    uint256 userSharesBefore = debtShares(borrower);
    uint256 totalSharesBefore = totalDebtShares();
    uint256 paid = repay(e, borrower, shares, maximumAssets);
    assert to_mathint(cash()) == to_mathint(cashBefore) + to_mathint(paid);
    assert to_mathint(debtShares(borrower)) + to_mathint(shares) == to_mathint(userSharesBefore);
    assert to_mathint(totalDebtShares()) + to_mathint(shares) == to_mathint(totalSharesBefore);
}

rule exhaustedCollateralClearsDebt(env e, address borrower, uint256 maximumShares,
                                  uint256 maximumAssets, uint256 minimumCollateral) {
    liquidate(e, borrower, maximumShares, maximumAssets, minimumCollateral);
    assert collateralOf(borrower) == 0 => debtShares(borrower) == 0;
}

rule completeLiquidationClearsDebt(env e, address borrower, uint256 maximumAssets,
                                  uint256 minimumCollateral) {
    uint256 allShares = debtShares(borrower);
    liquidate(e, borrower, allShares, maximumAssets, minimumCollateral);
    assert debtShares(borrower) == 0;
}
