// SPDX-License-Identifier: MIT
pragma solidity 0.8.38;

/// @notice Implementations must reject invalid/stale data and unsafe sequencer conditions.
interface IPriceOracle {
    /// @return value Loan-token human units per collateral-token human unit, scaled by 1e18.
    function price() external view returns (uint256 value);
}
