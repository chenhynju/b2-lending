// SPDX-License-Identifier: MIT
pragma solidity 0.8.38;
import {InterestRateModel} from "../../src/InterestRateModel.sol";

/// @notice Expose the actual internal rate library for verification.
contract RateHarness {
    function rate(uint256 utilization) external pure returns (uint256) {
        return InterestRateModel.rate(utilization);
    }
}
