// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "forge-std/Test.sol";

import "../../../src/token/USX.sol";
import "../../../src/proxy/ERC1967Proxy.sol";
import "../../../src/bridging/layer_zero/LayerZeroBridge.sol";

import "../../../src/bridging/interfaces/ILayerZeroBridge.sol";

import "../../common/Constants.t.sol";

contract AdminTest is Test {
    // Test Contracts
    USX public usx_implementation;
    ERC1967Proxy public usx_proxy;
    LayerZeroBridge public layer_zero_bridge;

    function setUp() public {
        usx_implementation = new USX();
        usx_proxy = new ERC1967Proxy(address(usx_implementation), abi.encodeWithSignature("initialize()"));
        layer_zero_bridge = new LayerZeroBridge(LZ_ENDPOINT, address(usx_proxy));
    }

    function test_setUseCustomAdapterParams() public {
        assertEq(ILayerZeroBridge(address(layer_zero_bridge)).useCustomAdapterParams(), false);

        ILayerZeroBridge(address(layer_zero_bridge)).setUseCustomAdapterParams(true);

        assertEq(ILayerZeroBridge(address(layer_zero_bridge)).useCustomAdapterParams(), true);
    }

    function testCannot_setUseCustomAdapterParams_sender(address sender) public {
        vm.assume(sender != address(this));

        vm.expectRevert("Ownable: caller is not the owner");

        vm.prank(sender);
        ILayerZeroBridge(address(layer_zero_bridge)).setUseCustomAdapterParams(true);
    }
}
