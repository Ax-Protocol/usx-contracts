// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "forge-std/Test.sol";
import "../../../src/token/USX.sol";
import "./common/TestHelpers.t.sol";

import "../../../src/common/interfaces/IUSXAdmin.sol";

import "../../common/Constants.t.sol";

contract AdminTest is Test, BridgingSetup {
    function testCannot_manageCrossChainTransfers_unauthorized() public {
        bool[2][4] memory trials = [[true, true], [true, false], [false, true], [false, false]];

        for (uint256 i = 0; i < trials.length; i++) {
            // Expectations
            vm.expectRevert("Ownable: caller is not the owner");

            // Act: attempt unauthorized privilege update
            vm.prank(TEST_ADDRESS);
            IUSXAdmin(address(usx_proxy)).manageCrossChainTransfers(
                [address(wormhole_bridge), address(layer_zero_bridge)], trials[i]
            );
        }
    }

    function test_manageCrossChainTransfers_pause_both() public {
        // Pre-action assertions
        assertEq(
            IUSXAdmin(address(usx_proxy)).transferPrivileges(address(wormhole_bridge)),
            true,
            "Privilege failed: Wormhole."
        );
        assertEq(
            IUSXAdmin(address(usx_proxy)).transferPrivileges(address(layer_zero_bridge)),
            true,
            "Privilege failed: Layer Zero."
        );

        // Act: pause
        IUSXAdmin(address(usx_proxy)).manageCrossChainTransfers(
            [address(wormhole_bridge), address(layer_zero_bridge)], [false, false]
        );

        // Post-action assertions
        assertEq(
            IUSXAdmin(address(usx_proxy)).transferPrivileges(address(wormhole_bridge)), false, "Pause failed: Wormhole."
        );
        assertEq(
            IUSXAdmin(address(usx_proxy)).transferPrivileges(address(layer_zero_bridge)),
            false,
            "Pause failed: Layer Zero."
        );
    }

    function test_manageCrossChainTransfers_unpause_both() public {
        // Setup
        IUSXAdmin(address(usx_proxy)).manageCrossChainTransfers(
            [address(wormhole_bridge), address(layer_zero_bridge)], [false, false]
        );
        assertEq(
            IUSXAdmin(address(usx_proxy)).transferPrivileges(address(wormhole_bridge)), false, "Pause failed: Wormhole."
        );
        assertEq(
            IUSXAdmin(address(usx_proxy)).transferPrivileges(address(layer_zero_bridge)),
            false,
            "Pause failed: Layer Zero."
        );

        // Act: unpause
        IUSXAdmin(address(usx_proxy)).manageCrossChainTransfers(
            [address(wormhole_bridge), address(layer_zero_bridge)], [true, true]
        );

        // Post-action assertions
        assertEq(
            IUSXAdmin(address(usx_proxy)).transferPrivileges(address(wormhole_bridge)),
            true,
            "Unpaused failed: Wormhole."
        );
        assertEq(
            IUSXAdmin(address(usx_proxy)).transferPrivileges(address(layer_zero_bridge)),
            true,
            "Unpaused failed: Layer Zero."
        );
    }

    /// @dev Test that each bridge can be singularly paused
    function test_manageCrossChainTransfers_pause_one() public {
        uint256 id = vm.snapshot();
        address[2] memory bridgeContracts = [address(wormhole_bridge), address(layer_zero_bridge)];
        bool[2] memory privileges = [true, true];

        // Iterate through privileges, each time revoking privileges for only one bridge
        for (uint256 pausedIndex = 0; pausedIndex < privileges.length; pausedIndex++) {
            // Pre-action assertions
            assertEq(
                IUSXAdmin(address(usx_proxy)).transferPrivileges(address(wormhole_bridge)),
                true,
                "Privilege failed: Wormhole."
            );
            assertEq(
                IUSXAdmin(address(usx_proxy)).transferPrivileges(address(layer_zero_bridge)),
                true,
                "Privilege failed: Layer Zero."
            );

            privileges = [true, true];
            privileges[pausedIndex] = false;

            // Act: pause
            IUSXAdmin(address(usx_proxy)).manageCrossChainTransfers(
                [address(wormhole_bridge), address(layer_zero_bridge)], privileges
            );

            // Given this iteration's privilege settings, iterate through both bridges to ensure privileges are active
            for (uint256 i = 0; i < bridgeContracts.length; i++) {
                if (i == pausedIndex) {
                    assertEq(
                        IUSXAdmin(address(usx_proxy)).transferPrivileges(bridgeContracts[i]), false, "Pause failed."
                    );
                } else {
                    assertEq(
                        IUSXAdmin(address(usx_proxy)).transferPrivileges(bridgeContracts[i]), true, "Privilege failed."
                    );
                }
            }
            // Revert chain state, such that each iteration is state-independent
            vm.revertTo(id);
        }
    }
}
