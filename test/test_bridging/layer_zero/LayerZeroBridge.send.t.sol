// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "../common/TestSetup.t.sol";

import "../../../src/bridging/interfaces/IWormhole.sol";

import "../../common/Constants.t.sol";

contract LayerZeroSendTest is Test, BridgingSetup {
    function test_setUp() public {
        assertEq(wormhole_bridge.usx(), address(usx_proxy));
    }

    function test_sendMessage(uint256 transferAmount) public {
        uint256 iterations = 3;
        vm.startPrank(address(usx_proxy));
        vm.deal(address(usx_proxy), TEST_GAS_FEE * iterations);
        for (uint256 i = 0; i < iterations; i++) {
            // Expectations
            vm.expectEmit(true, true, true, true, address(layer_zero_bridge));
            emit SendToChain(TEST_LZ_CHAIN_ID, address(this), abi.encodePacked(address(this)), transferAmount);

            // Act
            uint64 sequence = IBridge(address(layer_zero_bridge)).sendMessage{value: TEST_GAS_FEE}(
                payable(address(this)), TEST_LZ_CHAIN_ID, abi.encodePacked(address(this)), transferAmount
            );

            // Post-action Assertions:
            assertEq(sequence, 0);
        }
        vm.stopPrank();
    }

    function testCannot_sendMessage_unauthorized(uint256 transferAmount, address sender) public {
        vm.assume(sender != address(usx_proxy));

        // Expectations
        vm.expectRevert("Unauthorized.");

        // Act: pranking as any non-USX address
        vm.prank(sender);
        IBridge(address(layer_zero_bridge)).sendMessage(
            payable(address(this)), TEST_LZ_CHAIN_ID, abi.encode(address(this)), transferAmount
        );
    }
}
