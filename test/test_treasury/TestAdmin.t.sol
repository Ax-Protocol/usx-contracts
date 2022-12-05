// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "forge-std/Test.sol";
import "../interfaces/ITreasuryTest.t.sol";
import "../common/constants.t.sol";
import "./common/TestHelpers.t.sol";

contract TestAdmin is Test, TreasurySetup {
    function test_addSupportedStable() public {
        // Test Variables
        int128 testCurveIndex = 0;

        // Pre-action Assertions
        (bool supported, int128 returnedTestCurveIndex) =
            ITreasuryTest(address(treasury_proxy)).supportedStables(TEST_STABLE);
        assertEq(supported, false);

        // Act
        ITreasuryTest(address(treasury_proxy)).addSupportedStable(TEST_STABLE, testCurveIndex);

        // Post-action Assertions
        (supported, returnedTestCurveIndex) = ITreasuryTest(address(treasury_proxy)).supportedStables(TEST_STABLE);
        assertEq(supported, true);
        assertEq(returnedTestCurveIndex, testCurveIndex);
    }

    function testCannot_addSupportedStable_sender() public {
        // Test Variables
        int128 testCurveIndex = 0;

        // Expectations
        vm.expectRevert("Ownable: caller is not the owner");

        // Act
        vm.prank(TEST_ADDRESS);
        ITreasuryTest(address(treasury_proxy)).addSupportedStable(TEST_STABLE, testCurveIndex);
    }

    function test_removeSupportedStable() public {
        // Setup
        ITreasuryTest(address(treasury_proxy)).addSupportedStable(TEST_STABLE, 0);

        // Pre-action Assertions
        (bool supported, int128 returnedTestCurveIndex) =
            ITreasuryTest(address(treasury_proxy)).supportedStables(TEST_STABLE);
        assertEq(supported, true);
        assertEq(returnedTestCurveIndex, 0);

        // Act
        ITreasuryTest(address(treasury_proxy)).removeSupportedStable(TEST_STABLE);

        // Post-action Assertions
        (supported, returnedTestCurveIndex) = ITreasuryTest(address(treasury_proxy)).supportedStables(TEST_STABLE);
        assertEq(supported, false);
    }

    function testCannot_removeSupportedStable_sender() public {
        // Expectations
        vm.expectRevert("Ownable: caller is not the owner");

        // Act
        vm.prank(TEST_ADDRESS);
        ITreasuryTest(address(treasury_proxy)).removeSupportedStable(TEST_STABLE);
    }
}
