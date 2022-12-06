// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "forge-std/Test.sol";
import "../../../src/USX.sol";
import "../../interfaces/IUSXTest.t.sol";
import "../../common/constants.t.sol";
import "./common/TestHelpers.t.sol";

contract TestAdmin is Test, CrossChainSetup {
    function test_fail_manageCrossChainTransfers_sender() public {
        // Expectations
        vm.expectRevert("Ownable: caller is not the owner");

        // Act - attempt pause
        vm.prank(TEST_ADDRESS);
        IUSXTest(address(usx_proxy)).manageCrossChainTransfers(
            [BridgingProtocols.WORMHOLE, BridgingProtocols.LAYER_ZERO], [false, false]
        );

        // Expectations
        vm.expectRevert("Ownable: caller is not the owner");

        // Act - attempt unpause
        vm.prank(TEST_ADDRESS);
        IUSXTest(address(usx_proxy)).manageCrossChainTransfers(
            [BridgingProtocols.WORMHOLE, BridgingProtocols.LAYER_ZERO], [true, true]
        );
    }

    function test_manageCrossChainTransfers_pause_both() public {
        // Pre-action assertions
        assertEq(IUSXTest(address(usx_proxy)).transferPrivileges(uint8(BridgingProtocols.WORMHOLE)), true);
        assertEq(IUSXTest(address(usx_proxy)).transferPrivileges(uint8(BridgingProtocols.LAYER_ZERO)), true);

        // Act - pause
        IUSXTest(address(usx_proxy)).manageCrossChainTransfers(
            [BridgingProtocols.WORMHOLE, BridgingProtocols.LAYER_ZERO], [false, false]
        );

        // Post-action assertions
        assertEq(IUSXTest(address(usx_proxy)).transferPrivileges(uint8(BridgingProtocols.WORMHOLE)), false);
        assertEq(IUSXTest(address(usx_proxy)).transferPrivileges(uint8(BridgingProtocols.LAYER_ZERO)), false);
    }

    function test_manageCrossChainTransfers_unpause_both() public {
        // Setup
        IUSXTest(address(usx_proxy)).manageCrossChainTransfers(
            [BridgingProtocols.WORMHOLE, BridgingProtocols.LAYER_ZERO], [false, false]
        );
        assertEq(IUSXTest(address(usx_proxy)).transferPrivileges(uint8(BridgingProtocols.WORMHOLE)), false);
        assertEq(IUSXTest(address(usx_proxy)).transferPrivileges(uint8(BridgingProtocols.LAYER_ZERO)), false);

        // Act - unpause
        IUSXTest(address(usx_proxy)).manageCrossChainTransfers(
            [BridgingProtocols.WORMHOLE, BridgingProtocols.LAYER_ZERO], [true, true]
        );

        // Post-action assertions
        assertEq(IUSXTest(address(usx_proxy)).transferPrivileges(uint8(BridgingProtocols.WORMHOLE)), true);
        assertEq(IUSXTest(address(usx_proxy)).transferPrivileges(uint8(BridgingProtocols.LAYER_ZERO)), true);
    }

    /// @dev Test that each bridge can be singularly paused
    function test_manageCrossChainTransfers_pause_one() public {
        uint256 id = vm.snapshot();
        bool[2] memory privileges = [true, true];

        // Iterate through privileges, each time revoking privileges for only one bridge
        for (uint256 pausedIndex = 0; pausedIndex < privileges.length; pausedIndex++) {
            // Pre-action assertions
            assertEq(IUSXTest(address(usx_proxy)).transferPrivileges(uint8(BridgingProtocols.WORMHOLE)), true);
            assertEq(IUSXTest(address(usx_proxy)).transferPrivileges(uint8(BridgingProtocols.LAYER_ZERO)), true);

            privileges = [true, true];
            privileges[pausedIndex] = false;

            // Act - pause
            IUSXTest(address(usx_proxy)).manageCrossChainTransfers(
                [BridgingProtocols.WORMHOLE, BridgingProtocols.LAYER_ZERO], privileges
            );

            // Given this iteration's privilege settings, iterate through both bridges to ensure privileges are active
            for (
                uint8 bridgeID = uint8(BridgingProtocols.WORMHOLE);
                bridgeID <= uint8(BridgingProtocols.LAYER_ZERO);
                bridgeID++
            ) {
                if (bridgeID == pausedIndex) {
                    assertEq(IUSXTest(address(usx_proxy)).transferPrivileges(bridgeID), false);
                } else {
                    assertEq(IUSXTest(address(usx_proxy)).transferPrivileges(bridgeID), true);
                }
            }
            // Revert chain state, such that each iteration is state-independent
            vm.revertTo(id);
        }
    }
}
