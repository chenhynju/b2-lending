// SPDX-License-Identifier: MIT
pragma solidity 0.8.38;

import {Script} from "forge-std/Script.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IPriceOracle} from "../src/interfaces/IPriceOracle.sol";
import {LendingVault} from "../src/LendingVault.sol";

error BaseSepoliaOnly();
error InvalidDemoConfiguration();

/// @notice Free test token with one fixed allocation per address. No production asset backing.
contract DemoAsset is ERC20 {
    error AlreadyClaimed();
    uint8 private immutable _decimals;
    uint256 public immutable allocation;
    mapping(address => bool) public claimed;

    constructor(string memory name_, string memory symbol_, uint8 decimals_, uint256 allocation_)
        ERC20(name_, symbol_)
    {
        if (block.chainid != 84532) revert BaseSepoliaOnly();
        if (decimals_ > 18 || allocation_ == 0) revert InvalidDemoConfiguration();
        _decimals = decimals_;
        allocation = allocation_;
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    /// @notice Claim one demo allocation. There is no admin mint.
    function claim() external {
        if (claimed[msg.sender]) revert AlreadyClaimed();
        claimed[msg.sender] = true;
        _mint(msg.sender, allocation);
    }
}

/// @notice Operator-controlled test quote for demonstrations and controlled liquidations.
/// @dev This is synthetic data. It does not represent a Chainlink price or sequencer feed.
contract DemoQuote is IPriceOracle {
    error Unauthorized();
    error InvalidQuote();
    error StaleQuote();

    uint256 public constant MAX_AGE = 7 days;
    address public immutable operator;
    uint256 public updatedAt;
    uint256 private _value;
    event QuoteUpdated(uint256 value, uint256 updatedAt);

    constructor(address operator_) {
        if (block.chainid != 84532) revert BaseSepoliaOnly();
        if (operator_ == address(0)) revert InvalidDemoConfiguration();
        operator = operator_;
        _update(2000e18);
    }

    function setQuote(uint256 value) external {
        if (msg.sender != operator) revert Unauthorized();
        _update(value);
    }

    function price() external view returns (uint256 value) {
        if (block.timestamp - updatedAt > MAX_AGE) revert StaleQuote();
        return _value;
    }

    function _update(uint256 value) private {
        if (value == 0 || value > 1e36) revert InvalidQuote();
        _value = value;
        updatedAt = block.timestamp;
        emit QuoteUpdated(value, block.timestamp);
    }
}

/// @notice Create the four contracts of a Base Sepolia demo. Default CLI invocation is unsigned.
contract DeployBaseSepoliaDemo is Script {
    function run(address deployer)
        external
        returns (DemoAsset loan, DemoAsset collateral, DemoQuote quote, LendingVault vault)
    {
        if (block.chainid != 84532) revert BaseSepoliaOnly();
        if (deployer == address(0)) revert InvalidDemoConfiguration();
        vm.startBroadcast(deployer);
        loan = new DemoAsset("B2 Demo Loan Token", "mUSD", 6, 20_000e6);
        collateral = new DemoAsset("B2 Demo Collateral", "mETH", 18, 10 ether);
        quote = new DemoQuote(deployer);
        vault = new LendingVault(address(loan), address(collateral), address(quote));
        vm.stopBroadcast();
    }
}
