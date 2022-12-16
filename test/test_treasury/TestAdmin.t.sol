// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "forge-std/Test.sol";
import "./common/TestHelpers.t.sol";

import "../../src/treasury/interfaces/ITreasuryAdmin.sol";

import "../common/Constants.t.sol";

contract TestAdmin is Test, TreasurySetup {
    function test_addSupportedStable() public {
        // Test Variables
        int128 testCurveIndex = 0;

        // Pre-action assertions
        (bool supported, int128 returnedTestCurveIndex) =
            ITreasuryAdmin(address(treasury_proxy)).supportedStables(TEST_STABLE);
        assertEq(supported, false, "Error: stable already supported");

        // Act
        ITreasuryAdmin(address(treasury_proxy)).addSupportedStable(TEST_STABLE, testCurveIndex);

        // Post-action assertions
        (supported, returnedTestCurveIndex) = ITreasuryAdmin(address(treasury_proxy)).supportedStables(TEST_STABLE);
        assertEq(supported, true, "Error: failed to add supported stable");
        assertEq(
            returnedTestCurveIndex, testCurveIndex, "Equivalence violation: returnedTestCurveIndex and testCurveIndex"
        );
    }

    function testCannot_addSupportedStable_sender() public {
        // Test Variables
        int128 testCurveIndex = 0;

        // Expectations
        vm.expectRevert("Ownable: caller is not the owner");

        // Act
        vm.prank(TEST_ADDRESS);
        ITreasuryAdmin(address(treasury_proxy)).addSupportedStable(TEST_STABLE, testCurveIndex);
    }

    function test_removeSupportedStable() public {
        // Setup
        ITreasuryAdmin(address(treasury_proxy)).addSupportedStable(TEST_STABLE, 0);

        // Pre-action assertions
        (bool supported, int128 returnedTestCurveIndex) =
            ITreasuryAdmin(address(treasury_proxy)).supportedStables(TEST_STABLE);
        assertEq(supported, true, "Error: stable not supported");
        assertEq(returnedTestCurveIndex, 0, "Equivalence violation: returnedTestCurveIndex and testCurveIndex");

        // Act
        ITreasuryAdmin(address(treasury_proxy)).removeSupportedStable(TEST_STABLE);

        // Post-action assertions
        (supported, returnedTestCurveIndex) = ITreasuryAdmin(address(treasury_proxy)).supportedStables(TEST_STABLE);
        assertEq(supported, false, "Error: failed to remove supported stable");
    }

    function testCannot_removeSupportedStable_sender() public {
        // Expectations
        vm.expectRevert("Ownable: caller is not the owner");

        // Act
        vm.prank(TEST_ADDRESS);
        ITreasuryAdmin(address(treasury_proxy)).removeSupportedStable(TEST_STABLE);
    }
}
