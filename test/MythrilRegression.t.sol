// SPDX-License-Identifier: MIT
pragma solidity 0.8.38;

import {LendingFixture} from "./fixtures/LendingFixture.sol";

/// @notice Replay Mythril's concrete getter selectors in the real EVM.
contract MythrilRegressionTest is LendingFixture {
    function testFuzz_ReportedGetterCalldataGuards(uint256 extraLength) public {
        _position();
        extraLength = bound(extraLength, 0, 256);
        bytes4[6] memory selectors = [
            bytes4(0x4ac8eb5f),
            bytes4(0x38d52e0f),
            bytes4(0x3574d4c4),
            bytes4(0x313ce567),
            bytes4(0x1b859e41),
            bytes4(0x18160ddd)
        ];
        bytes[6] memory expected = [
            abi.encode(uint256(1 ether)),
            abi.encode(address(loan)),
            abi.encode(uint256(5e16)),
            abi.encode(uint256(12)),
            abi.encode(uint256(1000 * U)),
            abi.encode(uint256(10_000 * U * 1e6))
        ];
        for (uint256 i; i < selectors.length; i++) {
            bytes memory payload = abi.encodePacked(selectors[i], new bytes(extraLength));
            (bool success, bytes memory result) = address(vault).staticcall(payload);
            assertTrue(success, "Reported getter reverted");
            assertEq(result, expected[i], "Getter returned an unexpected value");
        }
        assertEq(vault.cash(), 9000 * U);
        assertEq(vault.debtOf(bob), 1000 * U);
    }

    function test_ReportedGetterRejectsTruncatedSelector() public view {
        bytes memory complete = abi.encodePacked(bytes4(0x18160ddd));
        for (uint256 length; length < 4; length++) {
            bytes memory truncated = new bytes(length);
            for (uint256 i; i < length; i++) {
                truncated[i] = complete[i];
            }
            (bool success,) = address(vault).staticcall(truncated);
            assertFalse(success, "Truncated selector must fail ABI dispatch");
        }
    }

    function test_TimestampChangesOnlyTheSpecifiedInterestAccrual() public {
        _position();
        uint256 initialIndex = vault.borrowIndex();
        vm.warp(block.timestamp + 365 days);
        // Initial utilization is 10%, giving a 3% annual checkpoint rate.
        assertEq(vault.totalAssets(), 10_030 * U);
        assertEq(vault.debtOf(bob), 1030 * U);
        assertEq(vault.borrowIndex(), initialIndex);
        vault.accrue();
        assertEq(vault.borrowIndex(), initialIndex * 103 / 100);
        assertEq(vault.totalAssets(), 10_030 * U);
        assertLe(vault.borrowIndex(), vault.MAX_INDEX());
    }
}
