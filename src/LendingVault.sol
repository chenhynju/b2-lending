// SPDX-License-Identifier: MIT
pragma solidity 0.8.38;
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IPriceOracle} from "./interfaces/IPriceOracle.sol";
import {InterestRateModel} from "./InterestRateModel.sol";

/// @title Isolated collateralized lending vault
/// @notice Immutable exact-transfer market. Lender shares absorb realized bad debt.
/// @dev Not ERC-4626: withdrawals require cash; debt is indexed; donations are excluded.
contract LendingVault is ERC20, ReentrancyGuard {
    using SafeERC20 for IERC20;
    uint256 public constant WAD = 1e18;
    uint256 public constant RAY = 1e27;
    uint256 public constant LTV = 75e16;
    uint256 public constant LIQUIDATION_THRESHOLD = 8e17;
    uint256 public constant LIQUIDATION_BONUS = 5e16;
    uint256 public constant MAX_INDEX = 1e36;
    uint256 public constant DEPOSIT_CAP = 1e30;
    uint256 public constant SHARE_SCALE = 1e6;
    IERC20 public immutable asset;
    IERC20 public immutable collateralToken;
    IPriceOracle public immutable oracle;
    uint256 public immutable assetUnit;
    uint256 public immutable collateralUnit;
    uint8 private immutable _shareDecimals;
    uint256 public cash;
    uint256 public totalCollateral;
    uint256 public totalDebtShares;
    uint256 public borrowIndex = RAY;
    uint256 public lastAccrual;
    uint256 public cumulativeBadDebt;
    mapping(address => uint256) public debtShares;
    mapping(address => uint256) public collateralOf;

    error InvalidConfiguration();
    error InvalidAmount();
    error Slippage();
    error InsufficientLiquidity();
    error UnsafePosition();
    error HealthyPosition();
    error UnsupportedToken();
    error InsolventMarket();
    error ReadDuringMutation();
    error InvalidOraclePrice();

    event Deposit(address indexed lender, uint256 assets, uint256 shares);
    event Withdraw(address indexed lender, uint256 assets, uint256 shares);
    event CollateralAdded(address indexed user, uint256 amount);
    event CollateralRemoved(address indexed user, uint256 amount);
    event Borrow(address indexed borrower, uint256 assets, uint256 shares);
    event Repay(address indexed payer, address indexed borrower, uint256 assets, uint256 shares);
    event Accrue(uint256 index, uint256 interest);
    event Liquidate(address indexed liquidator, address indexed borrower, uint256 paid, uint256 seized);
    event BadDebt(address indexed borrower, uint256 shares, uint256 assets);

    modifier stableView() {
        if (_reentrancyGuardEntered()) revert ReadDuringMutation();
        _;
    }

    constructor(address asset_, address collateral_, address oracle_) ERC20("Isolated Lending Share", "iLEND") {
        if (
            asset_ == collateral_ || asset_.code.length == 0 || collateral_.code.length == 0 || oracle_.code.length == 0
        ) revert InvalidConfiguration();
        uint8 a = IERC20Metadata(asset_).decimals();
        uint8 c = IERC20Metadata(collateral_).decimals();
        if (a > 18 || c > 18) revert InvalidConfiguration();
        asset = IERC20(asset_);
        collateralToken = IERC20(collateral_);
        oracle = IPriceOracle(oracle_);
        assetUnit = 10 ** a;
        collateralUnit = 10 ** c;
        _shareDecimals = a + 6;
        lastAccrual = block.timestamp;
    }

    /// @notice Shares have six extra decimals relative to the loan token.
    function decimals() public view override returns (uint8) {
        return _shareDecimals;
    }

    /// @notice Tracked cash plus receivables including pending interest; excludes donations.
    function totalAssets() public view stableView returns (uint256) {
        return cash + _debtAt(_previewIndex());
    }

    /// @notice Aggregate receivable, rounded up once rather than once per borrower.
    function totalDebt() external view stableView returns (uint256) {
        return _debtAt(_previewIndex());
    }

    /// @notice Individual liability in loan-token units, rounded up.
    function debtOf(address user) public view stableView returns (uint256) {
        return Math.mulDiv(debtShares[user], _previewIndex(), RAY, Math.Rounding.Ceil);
    }

    /// @notice Threshold-adjusted collateral/debt (1e18); debt-free positions return uint256 max.
    function healthFactor(address user) external view stableView returns (uint256) {
        uint256 debt = Math.mulDiv(debtShares[user], _previewIndex(), RAY, Math.Rounding.Ceil);
        if (debt == 0) return type(uint256).max;
        return Math.mulDiv(_value(collateralOf[user], _price()), LIQUIDATION_THRESHOLD, debt);
    }

    /// @notice Annualized borrow rate, scaled by 1e18.
    function borrowRate() external view stableView returns (uint256) {
        return InterestRateModel.rate(_utilization(_debtAt(_previewIndex())));
    }

    /// @notice Deposit quote rounded down. Existing worthless shares must be burned before restart.
    function previewDeposit(uint256 assets) external view stableView returns (uint256) {
        uint256 managed = cash + _debtAt(_previewIndex());
        if (totalSupply() != 0 && managed == 0) revert InsolventMarket();
        return totalSupply() == 0 ? assets * SHARE_SCALE : Math.mulDiv(assets, totalSupply(), managed);
    }

    /// @notice Permissionlessly checkpoint interest; linear per interval, compounded across intervals.
    function accrue() external nonReentrant {
        _accrue();
    }

    /// @notice Deposit exact loan tokens; mint shares down with slippage protection.
    function deposit(uint256 assets, uint256 minShares) external nonReentrant returns (uint256 shares) {
        _accrue();
        _backed();
        uint256 managed = cash + _debtAt(borrowIndex);
        if (assets == 0 || assets > DEPOSIT_CAP || managed + assets > DEPOSIT_CAP) revert InvalidAmount();
        if (totalSupply() != 0 && managed == 0) revert InsolventMarket();
        shares = totalSupply() == 0 ? assets * SHARE_SCALE : Math.mulDiv(assets, totalSupply(), managed);
        if (shares == 0 || shares < minShares) revert Slippage();
        cash += assets;
        _mint(msg.sender, shares);
        _pull(asset, msg.sender, assets);
        emit Deposit(msg.sender, assets, shares);
    }

    /// @notice Withdraw exact assets, burn shares up; idle cash must cover the withdrawal.
    function withdraw(uint256 assets, uint256 maxShares) external nonReentrant returns (uint256 shares) {
        _accrue();
        _backed();
        if (assets == 0) revert InvalidAmount();
        if (assets > cash) revert InsufficientLiquidity();
        shares = Math.mulDiv(assets, totalSupply(), cash + _debtAt(borrowIndex), Math.Rounding.Ceil);
        if (shares == 0 || shares > maxShares) revert Slippage();
        cash -= assets;
        _burn(msg.sender, shares);
        _push(asset, msg.sender, assets);
        emit Withdraw(msg.sender, assets, shares);
    }

    /// @notice Redeem shares down; worthless shares can be burned after complete market loss.
    function redeem(uint256 shares, uint256 minAssets) external nonReentrant returns (uint256 assets) {
        _accrue();
        _backed();
        if (shares == 0) revert InvalidAmount();
        assets = Math.mulDiv(shares, cash + _debtAt(borrowIndex), totalSupply());
        if (assets < minAssets) revert Slippage();
        if (assets > cash) revert InsufficientLiquidity();
        cash -= assets;
        _burn(msg.sender, shares);
        if (assets != 0) _push(asset, msg.sender, assets);
        emit Withdraw(msg.sender, assets, shares);
    }

    /// @notice Lock exact collateral for the caller. Does not depend on price availability.
    function addCollateral(uint256 amount) external nonReentrant {
        _backed();
        if (amount == 0 || amount > DEPOSIT_CAP || totalCollateral + amount > DEPOSIT_CAP) revert InvalidAmount();
        collateralOf[msg.sender] += amount;
        totalCollateral += amount;
        _pull(collateralToken, msg.sender, amount);
        emit CollateralAdded(msg.sender, amount);
    }

    /// @notice Release collateral only if remaining debt is within origination LTV.
    function removeCollateral(uint256 amount) external nonReentrant {
        _accrue();
        _backed();
        if (amount == 0 || amount > collateralOf[msg.sender]) revert InvalidAmount();
        collateralOf[msg.sender] -= amount;
        totalCollateral -= amount;
        if (debtShares[msg.sender] != 0) _requireHealthy(msg.sender);
        _push(collateralToken, msg.sender, amount);
        emit CollateralRemoved(msg.sender, amount);
    }

    /// @notice Borrow exact assets, creating debt shares rounded up against the borrower.
    function borrow(uint256 assets) external nonReentrant returns (uint256 shares) {
        _accrue();
        _backed();
        if (assets == 0) revert InvalidAmount();
        if (assets > cash) revert InsufficientLiquidity();
        shares = Math.mulDiv(assets, RAY, borrowIndex, Math.Rounding.Ceil);
        debtShares[msg.sender] += shares;
        totalDebtShares += shares;
        cash -= assets;
        _requireHealthy(msg.sender);
        _push(asset, msg.sender, assets);
        emit Borrow(msg.sender, assets, shares);
    }

    /// @notice Repay exact debt shares on behalf of a borrower; loan-token payment rounds up.
    function repay(address borrower, uint256 shares, uint256 maxAssets) external nonReentrant returns (uint256 assets) {
        _accrue();
        _backed();
        if (shares == 0 || shares > debtShares[borrower]) revert InvalidAmount();
        assets = Math.mulDiv(shares, borrowIndex, RAY, Math.Rounding.Ceil);
        if (assets > maxAssets) revert Slippage();
        debtShares[borrower] -= shares;
        totalDebtShares -= shares;
        cash += assets;
        _pull(asset, msg.sender, assets);
        emit Repay(msg.sender, borrower, assets, shares);
    }

    /// @notice Liquidate unhealthy debt and atomically socialize debt left after collateral exhaustion.
    /// @dev May consume less than maxDebtShares. Economically unpayable dust can settle with zero paid.
    function liquidate(address borrower, uint256 maxDebtShares, uint256 maxAssets, uint256 minCollateral)
        external
        nonReentrant
        returns (uint256 paid, uint256 seized)
    {
        _accrue();
        _backed();
        uint256 userShares = debtShares[borrower];
        if (maxDebtShares == 0 || userShares == 0) revert InvalidAmount();
        uint256 p = _price();
        uint256 value = _value(collateralOf[borrower], p);
        uint256 userDebt = Math.mulDiv(userShares, borrowIndex, RAY, Math.Rounding.Ceil);
        if (userDebt <= Math.mulDiv(value, LIQUIDATION_THRESHOLD, WAD)) revert HealthyPosition();
        uint256 affordable = Math.mulDiv(Math.mulDiv(value, WAD, WAD + LIQUIDATION_BONUS), RAY, borrowIndex);
        uint256 shares = Math.min(maxDebtShares, userShares);
        if (affordable < userShares && shares >= affordable) {
            shares = affordable;
            seized = collateralOf[borrower];
        } else {
            paid = Math.mulDiv(shares, borrowIndex, RAY, Math.Rounding.Ceil);
            seized = Math.mulDiv(paid, (WAD + LIQUIDATION_BONUS) * collateralUnit, p * assetUnit);
            if (seized == 0) revert InvalidAmount();
        }
        paid = Math.mulDiv(shares, borrowIndex, RAY, Math.Rounding.Ceil);
        if (paid > maxAssets || seized < minCollateral) revert Slippage();
        debtShares[borrower] -= shares;
        totalDebtShares -= shares;
        collateralOf[borrower] -= seized;
        totalCollateral -= seized;
        cash += paid;
        if (collateralOf[borrower] == 0 && debtShares[borrower] != 0) {
            uint256 beforeDebt = _debtAt(borrowIndex);
            uint256 writtenShares = debtShares[borrower];
            totalDebtShares -= writtenShares;
            debtShares[borrower] = 0;
            uint256 loss = beforeDebt - _debtAt(borrowIndex);
            cumulativeBadDebt += loss;
            emit BadDebt(borrower, writtenShares, loss);
        }
        if (paid != 0) _pull(asset, msg.sender, paid);
        if (seized != 0) _push(collateralToken, msg.sender, seized);
        emit Liquidate(msg.sender, borrower, paid, seized);
    }

    function _accrue() private {
        uint256 beforeDebt = _debtAt(borrowIndex);
        borrowIndex = _previewIndex();
        lastAccrual = block.timestamp;
        emit Accrue(borrowIndex, _debtAt(borrowIndex) - beforeDebt);
    }

    function _previewIndex() private view returns (uint256) {
        if (totalDebtShares == 0 || borrowIndex == MAX_INDEX || block.timestamp == lastAccrual) return borrowIndex;
        uint256 rate = InterestRateModel.rate(_utilization(_debtAt(borrowIndex)));
        uint256 factor = Math.mulDiv(rate, block.timestamp - lastAccrual, 365 days);
        uint256 growth = Math.mulDiv(borrowIndex, factor, WAD);
        return growth >= MAX_INDEX - borrowIndex ? MAX_INDEX : borrowIndex + growth;
    }

    function _debtAt(uint256 index) private view returns (uint256) {
        return Math.mulDiv(totalDebtShares, index, RAY, Math.Rounding.Ceil);
    }

    function _utilization(uint256 debt) private view returns (uint256) {
        return debt == 0 ? 0 : Math.mulDiv(debt, WAD, cash + debt);
    }

    function _price() private view returns (uint256 p) {
        p = oracle.price();
        if (p == 0 || p > 1e36) revert InvalidOraclePrice();
    }

    function _value(uint256 collateral, uint256 p) private view returns (uint256) {
        return Math.mulDiv(collateral, p * assetUnit, collateralUnit * WAD);
    }

    function _requireHealthy(address borrower) private view {
        uint256 debt = Math.mulDiv(debtShares[borrower], borrowIndex, RAY, Math.Rounding.Ceil);
        if (debt > Math.mulDiv(_value(collateralOf[borrower], _price()), LTV, WAD)) revert UnsafePosition();
    }

    function _backed() private view {
        if (asset.balanceOf(address(this)) < cash || collateralToken.balanceOf(address(this)) < totalCollateral) {
            revert UnsupportedToken();
        }
    }

    function _pull(IERC20 token, address from, uint256 amount) private {
        uint256 beforeBalance = token.balanceOf(address(this));
        token.safeTransferFrom(from, address(this), amount);
        if (token.balanceOf(address(this)) != beforeBalance + amount) revert UnsupportedToken();
    }

    function _push(IERC20 token, address to, uint256 amount) private {
        uint256 beforeBalance = token.balanceOf(address(this));
        uint256 receiverBalance = token.balanceOf(to);
        token.safeTransfer(to, amount);
        if (token.balanceOf(address(this)) + amount != beforeBalance || token.balanceOf(to) != receiverBalance + amount)
        {
            revert UnsupportedToken();
        }
    }
}
