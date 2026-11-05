// SPDX-License-Identifier: MIT
pragma solidity 0.8.38;
import {Test} from "forge-std/Test.sol";
import {FeedOracle} from "../src/FeedOracle.sol";
import {MockFeed} from "./mocks/Mocks.sol";

contract FeedOracleTest is Test {
    OracleTestFactory factory;
    MockFeed c;
    MockFeed l;
    MockFeed s;
    FeedOracle o;

    function setUp() public {
        vm.warp(10 days);
        factory = new OracleTestFactory();
        c = new MockFeed(8, 2000e8);
        l = new MockFeed(8, 1e8);
        s = new MockFeed(0, 0);
        s.set(0, block.timestamp - 2 hours, block.timestamp);
        o = factory.deploy(address(c), address(l), address(s), 1 hours);
    }

    function testValidPriceAndNormalization() public view {
        assertEq(o.price(), 2000e18);
    }

    function testDebtDepegIsNotAssumedOneDollar() public {
        l.set(5e7, block.timestamp, block.timestamp);
        assertEq(o.price(), 4000e18);
    }

    function testDifferentFeedDecimals() public {
        MockFeed other = new MockFeed(18, 2000e18);
        FeedOracle x = factory.deploy(address(other), address(l), address(0), 1 hours);
        assertEq(x.price(), 2000e18);
    }

    function testStaleFeedAndExactBoundary() public {
        vm.warp(block.timestamp + 1 hours);
        assertEq(o.price(), 2000e18);
        vm.warp(block.timestamp + 1);
        vm.expectRevert(FeedOracle.InvalidPrice.selector);
        o.price();
    }

    function testInvalidAnswers() public {
        c.set(0, 1, block.timestamp);
        vm.expectRevert(FeedOracle.InvalidPrice.selector);
        o.price();
        c.set(-1, 1, block.timestamp);
        vm.expectRevert(FeedOracle.InvalidPrice.selector);
        o.price();
        c.set(1e37, 1, block.timestamp);
        vm.expectRevert(FeedOracle.InvalidPrice.selector);
        o.price();
    }

    function testFutureAndZeroTimestamps() public {
        c.set(1e8, 1, 0);
        vm.expectRevert(FeedOracle.InvalidPrice.selector);
        o.price();
        c.set(1e8, 1, block.timestamp + 1);
        vm.expectRevert(FeedOracle.InvalidPrice.selector);
        o.price();
    }

    function testInvalidRound() public {
        c.setRound(2, 1);
        vm.expectRevert(FeedOracle.InvalidPrice.selector);
        o.price();
        c.setRound(0, 0);
        vm.expectRevert(FeedOracle.InvalidPrice.selector);
        o.price();
    }

    function testSequencerDownAndGrace() public {
        s.set(1, block.timestamp - 2 hours, block.timestamp);
        vm.expectRevert(FeedOracle.UnsafeSequencer.selector);
        o.price();
        s.set(0, block.timestamp - 1 hours, block.timestamp);
        vm.expectRevert(FeedOracle.UnsafeSequencer.selector);
        o.price();
        s.set(0, block.timestamp - 1 hours - 1, block.timestamp);
        assertEq(o.price(), 2000e18);
    }

    function testSequencerZeroFuture() public {
        s.set(0, 0, block.timestamp);
        vm.expectRevert(FeedOracle.UnsafeSequencer.selector);
        o.price();
        s.set(0, block.timestamp + 1, block.timestamp);
        vm.expectRevert(FeedOracle.UnsafeSequencer.selector);
        o.price();
    }

    function testConfigBoundaries() public {
        vm.expectRevert(FeedOracle.InvalidConfiguration.selector);
        factory.deploy(address(0), address(l), address(0), 3600);
        vm.expectRevert(FeedOracle.InvalidConfiguration.selector);
        factory.deploy(address(c), address(l), address(1), 3600);
        vm.expectRevert(FeedOracle.InvalidConfiguration.selector);
        factory.deploy(address(c), address(l), address(0), 59);
        vm.expectRevert(FeedOracle.InvalidConfiguration.selector);
        factory.deploy(address(c), address(l), address(0), 7 days + 1);
        MockFeed invalid = new MockFeed(19, 1);
        vm.expectRevert(FeedOracle.InvalidConfiguration.selector);
        factory.deploy(address(invalid), address(l), address(0), 3600);
        vm.chainId(8453);
        vm.expectRevert(FeedOracle.InvalidConfiguration.selector);
        factory.deploy(address(c), address(l), address(0), 3600);
    }

    function testPriceUpperAndLowerBounds() public {
        c.set(1, 1, block.timestamp);
        l.set(1e26, 1, block.timestamp);
        vm.expectRevert(FeedOracle.InvalidPrice.selector);
        o.price();
        c.set(1e26, 1, block.timestamp);
        l.set(1, 1, block.timestamp);
        vm.expectRevert(FeedOracle.InvalidPrice.selector);
        o.price();
    }

    function testFuzz_PriceRatio(uint256 collateralPrice, uint256 loanPrice) public {
        collateralPrice = bound(collateralPrice, 1, 1e18);
        loanPrice = bound(loanPrice, 1e4, 1e18);
        c.set(int256(collateralPrice), 1, block.timestamp);
        l.set(int256(loanPrice), 1, block.timestamp);
        assertEq(o.price(), collateralPrice * 1e18 / loanPrice);
    }
}

/// @notice Explicit deployment boundary avoids coverage misattribution across inline constructor call sites.
contract OracleTestFactory {
    function deploy(address c, address l, address s, uint256 a) external returns (FeedOracle) {
        return new FeedOracle(c, l, s, a);
    }
}
