// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "../common/TestSetup.t.sol";

import "../../../src/common/interfaces/IUSXAdmin.sol";
import "../../../src/bridging/interfaces/ILayerZeroBridge.sol";

import "../../common/Constants.t.sol";

contract LayerZeroReceiveTest is BridgingSetup {
    function test_lzReceive(uint256 transferAmount) public {
        vm.assume(transferAmount <= INITIAL_TOKENS);

        // Expectations
        vm.expectEmit(true, true, true, true, address(layer_zero_bridge_proxy));
        emit ReceiveFromChain(
            TEST_LZ_CHAIN_ID,
            abi.encodePacked(address(layer_zero_bridge_proxy), address(layer_zero_bridge_proxy)),
            address(this),
            transferAmount
            );

        // Pre-action Assertions
        assertEq(
            IUSXAdmin(address(usx_proxy)).totalSupply(),
            INITIAL_TOKENS,
            "Equivalence violation: total supply and initially minted tokens."
        );
        assertEq(
            IUSXAdmin(address(usx_proxy)).balanceOf(address(this)),
            INITIAL_TOKENS,
            "Equivalence violation: recipient balance and initially minted tokens."
        );

        // Act: send message, pranking as Layer Zero's contract
        vm.prank(LZ_ENDPOINT);
        ILayerZeroBridge(address(layer_zero_bridge_proxy)).lzReceive(
            TEST_LZ_CHAIN_ID,
            abi.encodePacked(address(layer_zero_bridge_proxy), address(layer_zero_bridge_proxy)),
            1,
            abi.encode(abi.encodePacked(address(this)), transferAmount)
        );

        // Assertions
        assertEq(
            IUSXAdmin(address(usx_proxy)).totalSupply(),
            INITIAL_TOKENS + transferAmount,
            "Equivalence violation: total supply must increase by amount transferred."
        );
        assertEq(
            IUSXAdmin(address(usx_proxy)).balanceOf(address(this)),
            INITIAL_TOKENS + transferAmount,
            "Equivalence violation: recipient balance must increase by amount transferred."
        );
    }

    function testCannot_lzReceive_invalid_unauthorized(uint256 transferAmount, address sender) public {
        // Assumptions
        vm.assume(transferAmount <= INITIAL_TOKENS);
        vm.assume(sender != LZ_ENDPOINT);

        // Expectation
        vm.expectRevert("LzApp: invalid endpoint caller");

        // Act: wrong prank
        vm.prank(sender);
        ILayerZeroBridge(address(layer_zero_bridge_proxy)).lzReceive(
            TEST_LZ_CHAIN_ID,
            abi.encodePacked(address(layer_zero_bridge_proxy), address(layer_zero_bridge_proxy)),
            1,
            abi.encode(abi.encodePacked(address(this)), transferAmount)
        );
    }

    function testCannot_lzReceive_invalid_source_address(uint256 transferAmount, address sourceAddress) public {
        // Assumptions
        vm.assume(transferAmount <= INITIAL_TOKENS);
        vm.assume(sourceAddress != address(layer_zero_bridge_proxy));

        // Expectation
        vm.expectRevert("LzApp: invalid source sending contract");

        // Act: source address not layer zero bridge
        vm.prank(LZ_ENDPOINT);
        ILayerZeroBridge(address(layer_zero_bridge_proxy)).lzReceive(
            TEST_LZ_CHAIN_ID,
            abi.encodePacked(sourceAddress, sourceAddress),
            1,
            abi.encode(abi.encodePacked(address(this)), transferAmount)
        );
    }
}
