// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "../common/TestSetup.t.sol";

import { ILayerZeroBridge } from "../../../../src/bridging/interfaces/ILayerZeroBridge.sol";
import { IBridge } from "../../../../src/token/interfaces/IBridge.sol";
import { ILayerZeroEndpoint } from "../../../../src/bridging/interfaces/ILayerZeroEndpoint.sol";

import "../../common/Constants.t.sol";

contract LayerZeroSendTest is BridgingSetup {
    function test_setUp() public {
        assertEq(ILayerZeroBridge(address(layer_zero_bridge_proxy)).usx(), address(usx_proxy));
    }

    function test_sendMessage(uint256 transferAmount) public {
        uint256 iterations = 3;
        vm.startPrank(address(usx_proxy));
        vm.deal(address(usx_proxy), TEST_GAS_FEE * iterations);
        for (uint256 i; i < iterations; i++) {
            // Expectations
            uint64 preActNonce =
                ILayerZeroEndpoint(LZ_ENDPOINT).getOutboundNonce(TEST_LZ_CHAIN_ID, address(layer_zero_bridge_proxy));
            uint64 expectedNonce = preActNonce + 1;
            vm.expectEmit(true, true, true, true, address(layer_zero_bridge_proxy));
            emit SendToChain(TEST_LZ_CHAIN_ID, address(this), abi.encode(address(this)), transferAmount, expectedNonce);

            // Act
            uint64 nonce = IBridge(address(layer_zero_bridge_proxy)).sendMessage{ value: TEST_GAS_FEE }(
                payable(address(this)), TEST_LZ_CHAIN_ID, abi.encode(address(this)), transferAmount
            );

            // Post-action Assertions:
            assertEq(nonce, expectedNonce);
        }
        vm.stopPrank();
    }

    function testCannot_sendMessage_unauthorized(uint256 transferAmount, address sender) public {
        vm.assume(sender != address(usx_proxy));

        // Expectations
        vm.expectRevert("Unauthorized.");

        // Act: pranking as any non-USX address
        vm.prank(sender);
        IBridge(address(layer_zero_bridge_proxy)).sendMessage(
            payable(address(this)), TEST_LZ_CHAIN_ID, abi.encode(address(this)), transferAmount
        );
    }
}
