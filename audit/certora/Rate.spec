methods {
    function rate(uint256 utilization) external returns (uint256) envfree;
}

rule rateBounds(uint256 utilization) {
    require utilization <= 1000000000000000000;
    uint256 result = rate(utilization);
    assert result >= 20000000000000000 && result <= 1000000000000000000;
}

rule rateMonotonic(uint256 lower, uint256 upper) {
    require lower <= upper && upper <= 1000000000000000000;
    uint256 lowerRate = rate(lower);
    uint256 upperRate = rate(upper);
    assert lowerRate <= upperRate;
}
