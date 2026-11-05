# Economic model
No emissions, reward subsidy, protocol fee or admin fee exists. Lenders supply loan assets; borrowers pay interest; liquidators supply repayment capital and receive collateral at a 5% incentive. Lender shares absorb recognized shortfalls.

Let C=tracked cash, S=total lender shares, Q=total debt shares, I=borrowIndex, R=1e27, W=1e18. All token amounts use native integer units.
- D=ceil(Q I/R); A=C+D.
- First deposit mints a*1e6 shares. Later mint=floor(a S/A).
- Withdraw burns ceil(a S/A). Redeem pays floor(s A/S).
- Borrow mints ceil(a R/I) debt shares.
- Repay s debt shares costs ceil(s I/R).
- User liability d=ceil(q I/R). Sum of rounded user liabilities can exceed D by at most N−1 raw units.
- u=floor(D W/(C+D)), or zero with no debt.
- Nominal APR r=0.02W + floor(u*0.08W/(0.8W)) up to the 80% kink; above it r=0.10W+floor((u−0.8W)*0.90W/(0.2W)).
- f=floor(r Δt/(365 days)); I'=min(1e36,I+floor(I f/W)).

Interest is linear inside a checkpoint interval and compounds across intervals; frequency influences realized APY. At 100% constant utilization, annual simple accrual is 100%; very frequent checkpointing approaches exp(1)−1 APY, not 100% APY. This is nominal APR, not a fixed-yield promise. The finite index ceiling eventually stops accrual.

## Price and collateral
p is loan human units per collateral human unit at W precision. For token units Ua and Uc, collateral value v=floor(c*p*Ua/(Uc*W)).
Origination constraint: d ≤ floor(v*0.75W/W).
Liquidatable: d > floor(v*0.80W/W).
Health factor = floor(v*0.80W/d), or uint256 max when d=0.

Both USD feeds must be valid/fresh. L2 sequencing must be operational beyond the one-hour grace period when a sequencer feed is configured. A loan-token depeg changes the ratio. There is no guaranteed real-world stablecoin peg.

## Liquidation and loss
Affordable repayment budget b=floor(v W/(W+bonus)); affordable debt shares qA=floor(b R/I).
For requested shares below the collateral-exhausting boundary, collect ceil(q I/R) and seize floor(payment*(W+bonus)*Uc/(p*Ua)). Otherwise consume up to qA, seize the remaining collateral and write off residual borrower debt shares. Economically unpayable dust can pay zero. Its value is bounded by the representability of one debt share, which worsens near the index ceiling.

Bad debt is measured as the exact reduction in aggregate D after removing the residual shares. A decreases by this loss (apart from separately accrued interest/rounding). There is no insurance fund or backstop. Worst case: loan assets can be fully lost. Liquidity shortages also block withdrawal without implying accounting insolvency.

## Parameter authority
75% LTV, 80% threshold, 5% bonus, APR curve, caps and share precision are immutable. There is no post-deployment adjustment authority. Deployment must select suitable assets, feeds and heartbeat; deploying another market is the only parameter change mechanism.

[Independent integer/Fraction model](../../scripts/reference_model.py) · [executable invariants](../../test/Invariant.t.sol)
