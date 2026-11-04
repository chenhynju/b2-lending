// SPDX-License-Identifier: MIT
pragma solidity 0.8.38;
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {LendingVault} from "../../src/LendingVault.sol";
import {IPriceOracle} from "../../src/interfaces/IPriceOracle.sol";
import {IAggregatorV3} from "../../src/FeedOracle.sol";

contract MockToken is ERC20 {
    uint8 private immutable _decimals;
    bool public fee;
    bool public fail;
    address public hook;
    bool public mutationBlocked;
    bool public viewBlocked;

    constructor(uint8 decimals_) ERC20("Mock", "MOCK") {
        _decimals = decimals_;
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external {
        _burn(from, amount);
    }

    function setFee(bool x) external {
        fee = x;
    }

    function setFail(bool x) external {
        fail = x;
    }

    function setHook(address x) external {
        hook = x;
    }

    function transfer(address to, uint256 amount) public override returns (bool) {
        if (fail) return false;
        return super.transfer(to, amount);
    }

    function _update(address from, address to, uint256 amount) internal override {
        if (fee && from != address(0) && to != address(0) && amount > 1) {
            super._update(from, address(0), 1);
            amount -= 1;
        }
        super._update(from, to, amount);
        if (hook != address(0) && from != address(0) && to != address(0)) {
            (bool ok, bytes memory result) = hook.call(abi.encodeCall(LendingVault.accrue, ()));
            mutationBlocked = !ok && bytes4(result) == bytes4(keccak256("ReentrancyGuardReentrantCall()"));
            (ok, result) = hook.staticcall(abi.encodeCall(LendingVault.totalAssets, ()));
            viewBlocked = !ok && bytes4(result) == LendingVault.ReadDuringMutation.selector;
        }
    }
}

contract MockOracle is IPriceOracle {
    uint256 public value = 2000e18;
    bool public fail;

    function setPrice(uint256 x) external {
        value = x;
    }

    function setFail(bool x) external {
        fail = x;
    }

    function price() external view returns (uint256) {
        require(!fail, "unavailable");
        return value;
    }
}

contract MockFeed is IAggregatorV3 {
    uint8 public immutable decimals;
    uint80 public round = 1;
    uint80 public answered = 1;
    int256 public answer;
    uint256 public started;
    uint256 public updated;

    constructor(uint8 d, int256 a) {
        decimals = d;
        set(a, block.timestamp, block.timestamp);
    }

    function set(int256 a, uint256 s, uint256 u) public {
        answer = a;
        started = s;
        updated = u;
    }

    function setRound(uint80 r, uint80 a) external {
        round = r;
        answered = a;
    }

    function latestRoundData() external view returns (uint80, int256, uint256, uint256, uint80) {
        return (round, answer, started, updated, answered);
    }
}

/// @notice USDT-style optional return and zero-first approval fixture; six decimals.
contract NoReturnToken {
    uint8 public constant decimals = 6;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    function mint(address to, uint256 value) external {
        balanceOf[to] += value;
    }

    function approve(address to, uint256 value) external {
        require(value == 0 || allowance[msg.sender][to] == 0, "zero first");
        allowance[msg.sender][to] = value;
    }

    function transfer(address to, uint256 value) external {
        _send(msg.sender, to, value);
    }

    function transferFrom(address from, address to, uint256 value) external {
        allowance[from][msg.sender] -= value;
        _send(from, to, value);
    }

    function _send(address from, address to, uint256 value) private {
        balanceOf[from] -= value;
        balanceOf[to] += value;
    }
}
