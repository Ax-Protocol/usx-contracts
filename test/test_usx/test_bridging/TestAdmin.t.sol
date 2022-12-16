// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "forge-std/Test.sol";
import "../../../src/usx/USX.sol";
import "./common/TestHelpers.t.sol";

import "../../../src/common/interfaces/IUSXAdmin.sol";

import "../../common/Constants.t.sol";

// contract TestAdmin is Test, CrossChainSetup {
//     function testCannot_manageCrossChainTransfers_sender() public {
//         bool[2][4] memory trials = [[true, true], [true, false], [false, true], [false, false]];

//         for (uint256 i = 0; i < trials.length; i++) {
//             // Expectations
//             vm.expectRevert("Ownable: caller is not the owner");

//             // Act: attempt unauthorized privilege update
//             vm.prank(TEST_ADDRESS);
//             IUSXAdmin(address(usx_proxy)).manageCrossChainTransfers(
//                 [BridgingProtocols.WORMHOLE, BridgingProtocols.LAYER_ZERO], trials[i]
//             );
//         }
//     }

//     function test_manageCrossChainTransfers_pause_both() public {
//         // Pre-action assertions
//         assertEq(
//             IUSXAdmin(address(usx_proxy)).transferPrivileges(uint8(BridgingProtocols.WORMHOLE)),
//             true,
//             "Privilege failed: Wormhole."
//         );
//         assertEq(
//             IUSXAdmin(address(usx_proxy)).transferPrivileges(uint8(BridgingProtocols.LAYER_ZERO)),
//             true,
//             "Privilege failed: Layer Zero."
//         );

//         // Act: pause
//         IUSXAdmin(address(usx_proxy)).manageCrossChainTransfers(
//             [BridgingProtocols.WORMHOLE, BridgingProtocols.LAYER_ZERO], [false, false]
//         );

//         // Post-action assertions
//         assertEq(
//             IUSXAdmin(address(usx_proxy)).transferPrivileges(uint8(BridgingProtocols.WORMHOLE)),
//             false,
//             "Pause failed: Wormhole."
//         );
//         assertEq(
//             IUSXAdmin(address(usx_proxy)).transferPrivileges(uint8(BridgingProtocols.LAYER_ZERO)),
//             false,
//             "Pause failed: Layer Zero."
//         );
//     }

//     function test_manageCrossChainTransfers_unpause_both() public {
//         // Setup
//         IUSXAdmin(address(usx_proxy)).manageCrossChainTransfers(
//             [BridgingProtocols.WORMHOLE, BridgingProtocols.LAYER_ZERO], [false, false]
//         );
//         assertEq(
//             IUSXAdmin(address(usx_proxy)).transferPrivileges(uint8(BridgingProtocols.WORMHOLE)),
//             false,
//             "Pause failed: Wormhole."
//         );
//         assertEq(
//             IUSXAdmin(address(usx_proxy)).transferPrivileges(uint8(BridgingProtocols.LAYER_ZERO)),
//             false,
//             "Pause failed: Layer Zero."
//         );

//         // Act: unpause
//         IUSXAdmin(address(usx_proxy)).manageCrossChainTransfers(
//             [BridgingProtocols.WORMHOLE, BridgingProtocols.LAYER_ZERO], [true, true]
//         );

//         // Post-action assertions
//         assertEq(
//             IUSXAdmin(address(usx_proxy)).transferPrivileges(uint8(BridgingProtocols.WORMHOLE)),
//             true,
//             "Unpaused failed: Wormhole."
//         );
//         assertEq(
//             IUSXAdmin(address(usx_proxy)).transferPrivileges(uint8(BridgingProtocols.LAYER_ZERO)),
//             true,
//             "Unpaused failed: Layer Zero."
//         );
//     }

//     /// @dev Test that each bridge can be singularly paused
//     function test_manageCrossChainTransfers_pause_one() public {
//         uint256 id = vm.snapshot();
//         bool[2] memory privileges = [true, true];

//         // Iterate through privileges, each time revoking privileges for only one bridge
//         for (uint256 pausedIndex = 0; pausedIndex < privileges.length; pausedIndex++) {
//             // Pre-action assertions
//             assertEq(
//                 IUSXAdmin(address(usx_proxy)).transferPrivileges(uint8(BridgingProtocols.WORMHOLE)),
//                 true,
//                 "Privilege failed: Wormhole."
//             );
//             assertEq(
//                 IUSXAdmin(address(usx_proxy)).transferPrivileges(uint8(BridgingProtocols.LAYER_ZERO)),
//                 true,
//                 "Privilege failed: Layer Zero."
//             );

//             privileges = [true, true];
//             privileges[pausedIndex] = false;

//             // Act: pause
//             IUSXAdmin(address(usx_proxy)).manageCrossChainTransfers(
//                 [BridgingProtocols.WORMHOLE, BridgingProtocols.LAYER_ZERO], privileges
//             );

//             // Given this iteration's privilege settings, iterate through both bridges to ensure privileges are active
//             for (
//                 uint8 bridgeID = uint8(BridgingProtocols.WORMHOLE);
//                 bridgeID <= uint8(BridgingProtocols.LAYER_ZERO);
//                 bridgeID++
//             ) {
//                 if (bridgeID == pausedIndex) {
//                     assertEq(IUSXAdmin(address(usx_proxy)).transferPrivileges(bridgeID), false, "Pause failed.");
//                 } else {
//                     assertEq(IUSXAdmin(address(usx_proxy)).transferPrivileges(bridgeID), true, "Privilege failed.");
//                 }
//             }
//             // Revert chain state, such that each iteration is state-independent
//             vm.revertTo(id);
//         }
//     }
// }
