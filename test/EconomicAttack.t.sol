// SPDX-License-Identifier: MIT
pragma solidity 0.8.38;
import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {LendingVault} from "../src/LendingVault.sol";
import {MockToken, MockOracle} from "./mocks/Mocks.sol";

interface IFlashReceiver {
    function onFlash(address token, uint256 amount) external;
}

/// @notice Test-only zero-fee flash lender, enforcing exact principal repayment.
contract FlashLender {
    function flash(address token, uint256 amount, address receiver) external {
        uint256 before = IERC20(token).balanceOf(address(this));
        IERC20(token).transfer(receiver, amount);
        IFlashReceiver(receiver).onFlash(token, amount);
        require(IERC20(token).balanceOf(address(this)) >= before, "flash not repaid");
    }
}

contract FlashActor is IFlashReceiver {
    LendingVault immutable v;
    FlashLender immutable lender;
    uint256 public mode;

    constructor(LendingVault vault, FlashLender lender_) {
        v = vault;
        lender = lender_;
    }

    function run(address token, uint256 amount, uint256 mode_) external {
        mode = mode_;
        lender.flash(token, amount, address(this));
    }

    function onFlash(address token, uint256 amount) external {
        require(msg.sender == address(lender));
        IERC20(token).approve(address(v), amount);
        if (mode == 0) {
            uint256 s = v.deposit(amount, 0);
            v.redeem(s, 0);
        } else {
            v.addCollateral(amount);
            v.borrow(1000e6);
            v.removeCollateral(amount);
        }
        IERC20(token).transfer(address(lender), amount);
    }
}

contract EconomicAttackTest is Test {
    MockToken loan;
    MockToken coll;
    MockOracle oracle;
    LendingVault v;
    FlashLender lender;
    FlashActor actor;

    function setUp() public {
        loan = new MockToken(6);
        coll = new MockToken(18);
        oracle = new MockOracle();
        v = new LendingVault(address(loan), address(coll), address(oracle));
        lender = new FlashLender();
        actor = new FlashActor(v, lender);
        loan.mint(address(this), 100_000e6);
        loan.approve(address(v), type(uint256).max);
        v.deposit(10_000e6, 0);
        loan.mint(address(lender), 10_000e6);
        coll.mint(address(lender), 10 ether);
    }

    function testFlashDepositRedeemHasNoProfit() public {
        actor.run(address(loan), 1000e6, 0);
        assertEq(loan.balanceOf(address(actor)), 0);
        assertEq(v.cash(), 10_000e6);
    }

    function testFlashCollateralCannotEscapeDebt() public {
        vm.expectRevert(LendingVault.UnsafePosition.selector);
        actor.run(address(coll), 1 ether, 1);
        assertEq(v.debtShares(address(actor)), 0);
        assertEq(coll.balanceOf(address(lender)), 10 ether);
    }

    function testDonationDoesNotChangeBorrowingPower() public {
        coll.mint(address(this), 1 ether);
        coll.approve(address(v), type(uint256).max);
        v.addCollateral(1 ether);
        loan.transfer(address(v), 50_000e6);
        v.borrow(1500e6);
        vm.expectRevert(LendingVault.UnsafePosition.selector);
        v.borrow(1);
    }

    function testUnfundedLiquidationCannotCommitLosses() public {
        coll.mint(address(this), 1 ether);
        coll.approve(address(v), type(uint256).max);
        v.addCollateral(1 ether);
        v.borrow(1000e6);
        oracle.setPrice(500e18);
        address unfunded = address(0xBAD);
        vm.prank(unfunded);
        vm.expectRevert();
        v.liquidate(address(this), type(uint256).max, type(uint256).max, 0);
        assertEq(v.cumulativeBadDebt(), 0);
        assertEq(v.debtOf(address(this)), 1000e6);
        assertEq(v.collateralOf(address(this)), 1 ether);
    }

    function testFuzz_LossExactlyMatchesReceivableWriteOff(uint256 price) public {
        price = bound(price, 1e6, 1000e18);
        coll.mint(address(this), 1 ether);
        coll.approve(address(v), type(uint256).max);
        v.addCollateral(1 ether);
        v.borrow(1000e6);
        oracle.setPrice(price);
        uint256 before = v.totalAssets();
        v.liquidate(address(this), type(uint256).max, type(uint256).max, 0);
        assertEq(before - v.totalAssets(), v.cumulativeBadDebt());
        assertEq(v.debtShares(address(this)), 0);
    }
}
