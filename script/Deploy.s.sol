// SPDX-License-Identifier: MIT
pragma solidity 0.8.38;
import {Script} from "forge-std/Script.sol";
import {LendingVault} from "../src/LendingVault.sol";
import {FeedOracle} from "../src/FeedOracle.sol";

/// @notice Unsigned by default. Broadcast public networks only after explicit authorization.
contract Deploy is Script {
    function run() external returns (LendingVault vault, FeedOracle oracle) {
        address loan = vm.envAddress("LOAN_TOKEN");
        address collateral = vm.envAddress("COLLATERAL_TOKEN");
        address collateralFeed = vm.envAddress("COLLATERAL_USD_FEED");
        address loanFeed = vm.envAddress("LOAN_USD_FEED");
        address sequencer = vm.envAddress("SEQUENCER_FEED");
        uint256 maxAge = vm.envUint("ORACLE_MAX_AGE");
        // A zero sequencer feed is permitted for Ethereum only, not a public Base deployment.
        require(block.chainid == 1 || sequencer != address(0), "sequencer required");
        vm.startBroadcast();
        oracle = new FeedOracle(collateralFeed, loanFeed, sequencer, maxAge);
        oracle.price();
        vault = new LendingVault(loan, collateral, address(oracle));
        vm.stopBroadcast();
    }
}
