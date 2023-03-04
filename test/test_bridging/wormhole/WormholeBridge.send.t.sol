// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "../common/TestSetup.t.sol";

import "../../../src/bridging/interfaces/IWormhole.sol";
import "../../../src/bridging/interfaces/IWormholeBridge.sol";
import "../../../src/token/interfaces/IBridge.sol";

import "../../common/Constants.t.sol";

contract WormholeSendTest is BridgingSetup {
    function test_setUp() public {
        assertEq(IWormholeBridge(address(wormhole_bridge_proxy)).usx(), address(usx_proxy));
    }

    function test_sendMessage(uint256 transferAmount, uint256 gasFee) public {
        // Setup
        uint256 iterations = 3;
        vm.startPrank(address(usx_proxy));
        uint256 destGasFee = IWormholeBridge(address(wormhole_bridge_proxy)).sendFeeLookup(TEST_WORMHOLE_CHAIN_ID);
        gasFee = bound(gasFee, destGasFee, 5e16);
        vm.deal(address(usx_proxy), gasFee * iterations);

        for (uint256 i; i < iterations; i++) {
            // Expectations
            vm.expectEmit(true, true, true, true, address(wormhole_bridge_proxy));
            emit SendToChain(TEST_WORMHOLE_CHAIN_ID, address(this), abi.encodePacked(address(this)), transferAmount);

            // Act
            uint64 sequence = IBridge(address(wormhole_bridge_proxy)).sendMessage{ value: gasFee }(
                payable(address(this)), TEST_WORMHOLE_CHAIN_ID, abi.encodePacked(address(this)), transferAmount
            );

            // Post-action Assertions
            assertEq(sequence, i, "Equivalence violation: sequence and i.");
        }
        vm.stopPrank();
    }

    function testCannot_sendMessage_unauthorized(uint256 transferAmount, address sender) public {
        vm.assume(sender != address(usx_proxy));

        // Expectations
        vm.expectRevert("Unauthorized.");

        // Act: pranking as any non-USX address
        vm.prank(sender);
        IBridge(address(wormhole_bridge_proxy)).sendMessage(
            payable(address(this)), TEST_WORMHOLE_CHAIN_ID, abi.encodePacked(address(this)), transferAmount
        );
    }

    function testCannot_sendMessage_not_enough_fees(uint256 transferAmount, uint256 gasFee) public {
        // Setup
        uint256 destGasFee = IWormholeBridge(address(wormhole_bridge_proxy)).sendFeeLookup(TEST_WORMHOLE_CHAIN_ID);
        vm.assume(gasFee < destGasFee);
        vm.startPrank(address(usx_proxy));
        vm.deal(address(usx_proxy), gasFee);

        // Expectations
        vm.expectRevert("Not enough native token for gas.");

        // Act: gasFee is less than required destGasFee
        IBridge(address(wormhole_bridge_proxy)).sendMessage{ value: gasFee }(
            payable(address(this)), TEST_WORMHOLE_CHAIN_ID, abi.encodePacked(address(this)), transferAmount
        );
    }
}
