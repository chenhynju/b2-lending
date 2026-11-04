// SPDX-License-Identifier: MIT
pragma solidity 0.8.38;
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IPriceOracle} from "./interfaces/IPriceOracle.sol";

interface IAggregatorV3 {
    function decimals() external view returns (uint8);
    function latestRoundData() external view returns (uint80, int256, uint256, uint256, uint80);
}

/// @title Dual USD-feed oracle with optional L2 sequencer protection
/// @notice Invalid data fails closed; no fallback to manipulable market spot prices.
contract FeedOracle is IPriceOracle {
    IAggregatorV3 public immutable collateralFeed;
    IAggregatorV3 public immutable loanFeed;
    IAggregatorV3 public immutable sequencerFeed;
    uint256 public immutable maxAge;
    uint256 public immutable collateralScale;
    uint256 public immutable loanScale;
    uint256 public constant GRACE_PERIOD = 1 hours;
    error InvalidConfiguration();
    error InvalidPrice();
    error UnsafeSequencer();

    constructor(address collateral_, address loan_, address sequencer_, uint256 maxAge_) {
        if (collateral_.code.length == 0 || loan_.code.length == 0 || maxAge_ < 60 || maxAge_ > 7 days) {
            revert InvalidConfiguration();
        }
        if (sequencer_ != address(0) && sequencer_.code.length == 0) revert InvalidConfiguration();
        if (block.chainid == 8453 && sequencer_ == address(0)) revert InvalidConfiguration();
        collateralFeed = IAggregatorV3(collateral_);
        loanFeed = IAggregatorV3(loan_);
        sequencerFeed = IAggregatorV3(sequencer_);
        uint8 c = collateralFeed.decimals();
        uint8 l = loanFeed.decimals();
        if (c > 18 || l > 18) revert InvalidConfiguration();
        collateralScale = 10 ** (18 - c);
        loanScale = 10 ** (18 - l);
        maxAge = maxAge_;
    }

    /// @inheritdoc IPriceOracle
    function price() external view returns (uint256 value) {
        if (address(sequencerFeed) != address(0)) {
            (, int256 status, uint256 since,,) = sequencerFeed.latestRoundData();
            if (status != 0 || since == 0 || since > block.timestamp || block.timestamp - since <= GRACE_PERIOD) {
                revert UnsafeSequencer();
            }
        }
        value = Math.mulDiv(_read(collateralFeed, collateralScale), 1e18, _read(loanFeed, loanScale));
        if (value == 0 || value > 1e36) revert InvalidPrice();
    }

    function _read(IAggregatorV3 feed, uint256 scale) private view returns (uint256) {
        (uint80 id, int256 answer,, uint256 updated, uint80 answered) = feed.latestRoundData();
        if (
            answer <= 0 || id == 0 || answered < id || updated == 0 || updated > block.timestamp
                || block.timestamp - updated > maxAge || uint256(answer) > 1e36 / scale
        ) revert InvalidPrice();
        return uint256(answer) * scale;
    }
}
