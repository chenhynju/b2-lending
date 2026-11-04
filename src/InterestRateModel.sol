// SPDX-License-Identifier: MIT
pragma solidity 0.8.38;

/// @title Immutable kinked utilization model
library InterestRateModel {
    uint256 internal constant WAD = 1e18;
    uint256 internal constant KINK = 8e17;
    error InvalidUtilization();

    /// @notice 1e18-scaled APR: 2% at zero utilization, 10% at 80%, 100% at full.
    function rate(uint256 utilization) internal pure returns (uint256) {
        if (utilization > WAD) revert InvalidUtilization();
        if (utilization <= KINK) return 2e16 + utilization * 8e16 / KINK;
        return 1e17 + (utilization - KINK) * 9e17 / (WAD - KINK);
    }
}
