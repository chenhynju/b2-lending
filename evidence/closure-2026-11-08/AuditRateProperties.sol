// SPDX-License-Identifier: MIT
pragma solidity 0.8.38;
import {Test} from "forge-std/Test.sol";
import {InterestRateModel} from "../src/InterestRateModel.sol";
contract AuditRateProperties is Test {
    function check_rateRange(uint256 utilization) public pure {
        vm.assume(utilization <= 1e18);
        uint256 rate = InterestRateModel.rate(utilization);
        assert(rate >= 2e16 && rate <= 1e18);
    }
    function check_rateMonotonic(uint64 lower, uint64 upper) public pure {
        vm.assume(lower <= upper && upper <= 1e18);
        assert(InterestRateModel.rate(lower) <= InterestRateModel.rate(upper));
    }
}
