// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "../../../../src/token/USX.sol";

import "../../../../src/common/interfaces/IUSXAdmin.sol";

import "./common/TestSetup.t.sol";
import "../../common/Constants.t.sol";

contract AdminTest is BridgingSetup {
    function testCannot_manageCrossChainTransfers_unauthorized() public {
        bool[2][4] memory trials = [[true, true], [true, false], [false, true], [false, false]];

        for (uint256 i; i < trials.length; i++) {
            // Expectations
            vm.expectRevert("Ownable: caller is not the owner");

            // Act: attempt unauthorized privilege update
            vm.prank(TEST_ADDRESS);
            IUSXAdmin(address(usx_proxy)).manageCrossChainTransfers(
                [address(wormhole_bridge_proxy), address(layer_zero_bridge_proxy)], trials[i]
            );
        }
    }

    function test_manageCrossChainTransfers_pause_both() public {
        // Pre-action assertions
        assertEq(
            IUSXAdmin(address(usx_proxy)).transferPrivileges(address(wormhole_bridge_proxy)),
            true,
            "Privilege failed: Wormhole."
        );
        assertEq(
            IUSXAdmin(address(usx_proxy)).transferPrivileges(address(layer_zero_bridge_proxy)),
            true,
            "Privilege failed: Layer Zero."
        );

        // Act: pause
        IUSXAdmin(address(usx_proxy)).manageCrossChainTransfers(
            [address(wormhole_bridge_proxy), address(layer_zero_bridge_proxy)], [false, false]
        );

        // Post-action assertions
        assertEq(
            IUSXAdmin(address(usx_proxy)).transferPrivileges(address(wormhole_bridge_proxy)),
            false,
            "Pause failed: Wormhole."
        );
        assertEq(
            IUSXAdmin(address(usx_proxy)).transferPrivileges(address(layer_zero_bridge_proxy)),
            false,
            "Pause failed: Layer Zero."
        );
    }

    function test_manageCrossChainTransfers_unpause_both() public {
        // Setup
        IUSXAdmin(address(usx_proxy)).manageCrossChainTransfers(
            [address(wormhole_bridge_proxy), address(layer_zero_bridge_proxy)], [false, false]
        );
        assertEq(
            IUSXAdmin(address(usx_proxy)).transferPrivileges(address(wormhole_bridge_proxy)),
            false,
            "Pause failed: Wormhole."
        );
        assertEq(
            IUSXAdmin(address(usx_proxy)).transferPrivileges(address(layer_zero_bridge_proxy)),
            false,
            "Pause failed: Layer Zero."
        );

        // Act: unpause
        IUSXAdmin(address(usx_proxy)).manageCrossChainTransfers(
            [address(wormhole_bridge_proxy), address(layer_zero_bridge_proxy)], [true, true]
        );

        // Post-action assertions
        assertEq(
            IUSXAdmin(address(usx_proxy)).transferPrivileges(address(wormhole_bridge_proxy)),
            true,
            "Unpaused failed: Wormhole."
        );
        assertEq(
            IUSXAdmin(address(usx_proxy)).transferPrivileges(address(layer_zero_bridge_proxy)),
            true,
            "Unpaused failed: Layer Zero."
        );
    }

    /// @dev Test that each bridge can be singularly paused
    function test_manageCrossChainTransfers_pause_one() public {
        uint256 id = vm.snapshot();
        address[2] memory bridgeContracts = [address(wormhole_bridge_proxy), address(layer_zero_bridge_proxy)];
        bool[2] memory privileges = [true, true];

        // Iterate through privileges, each time revoking privileges for only one bridge
        for (uint256 pausedIndex; pausedIndex < privileges.length; pausedIndex++) {
            // Pre-action assertions
            assertEq(
                IUSXAdmin(address(usx_proxy)).transferPrivileges(address(wormhole_bridge_proxy)),
                true,
                "Privilege failed: Wormhole."
            );
            assertEq(
                IUSXAdmin(address(usx_proxy)).transferPrivileges(address(layer_zero_bridge_proxy)),
                true,
                "Privilege failed: Layer Zero."
            );

            privileges = [true, true];
            privileges[pausedIndex] = false;

            // Act: pause
            IUSXAdmin(address(usx_proxy)).manageCrossChainTransfers(
                [address(wormhole_bridge_proxy), address(layer_zero_bridge_proxy)], privileges
            );

            // Given this iteration's privilege settings, iterate through both bridges to ensure privileges are active
            for (uint256 i; i < bridgeContracts.length; i++) {
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

    function test_manageRoutes_layerzero() public {
        for (uint256 i; i < LZ_TEST_CHAIN_IDS.length; i++) {
            // Expectations: update to false one by one
            LZ_TEST_PRIVILEGES[i] = false;

            // Pre-action Assertions
            assertEq(
                IUSXAdmin(address(usx_proxy)).routes(address(layer_zero_bridge_proxy), LZ_TEST_CHAIN_IDS[i]),
                true,
                "Equivalence violation: LZ_TEST_CHAIN_IDS[i] is not initially true"
            );

            // Act
            IUSXAdmin(address(usx_proxy)).manageRoutes(
                address(layer_zero_bridge_proxy), LZ_TEST_CHAIN_IDS, LZ_TEST_PRIVILEGES
            );

            // Post-action assertions
            assertEq(
                IUSXAdmin(address(usx_proxy)).routes(address(layer_zero_bridge_proxy), LZ_TEST_CHAIN_IDS[i]),
                false,
                "Equivalence violation: LZ_TEST_CHAIN_IDS[i] was not updated to false"
            );
        }
    }

    function test_manageRoutes_wormhole() public {
        for (uint256 i; i < WH_TEST_CHAIN_IDS.length; i++) {
            // Expectations: update to false one by one
            WH_TEST_PRIVILEGES[i] = false;

            // Pre-action Assertions
            assertEq(
                IUSXAdmin(address(usx_proxy)).routes(address(wormhole_bridge_proxy), WH_TEST_CHAIN_IDS[i]),
                true,
                "Equivalence violation: WH_TEST_CHAIN_IDS[i] is not initially true"
            );

            // Act
            IUSXAdmin(address(usx_proxy)).manageRoutes(
                address(wormhole_bridge_proxy), WH_TEST_CHAIN_IDS, WH_TEST_PRIVILEGES
            );

            // Post-action assertions
            assertEq(
                IUSXAdmin(address(usx_proxy)).routes(address(wormhole_bridge_proxy), WH_TEST_CHAIN_IDS[i]),
                false,
                "Equivalence violation: LZ_TEST_CHAIN_IDS[i] was not updated to false"
            );
        }
    }

    function testCannot_manageRoutes_arrays_length() public {
        // Setup
        uint16[] memory dstChainIds = new uint16[](2);
        dstChainIds[0] = 4; // BSC
        dstChainIds[1] = 5; // Polygon

        bool[] memory privileges = new bool[](1);
        privileges[0] = true;

        // Expectations
        vm.expectRevert("Arrays must be equal length.");

        // Act
        IUSXAdmin(address(usx_proxy)).manageRoutes(address(wormhole_bridge_proxy), dstChainIds, privileges);
    }

    function testCannot_manageRoutes_unauthorized(address sender) public {
        // Setup
        vm.assume(sender != address(this));

        // Exptectations
        vm.expectRevert("Ownable: caller is not the owner");

        // Act
        vm.prank(sender);
        IUSXAdmin(address(usx_proxy)).manageRoutes(
            address(wormhole_bridge_proxy), WH_TEST_CHAIN_IDS, WH_TEST_PRIVILEGES
        );
    }
}
