// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "forge-std/Test.sol";
import "../../../src/token/USX.sol";
import "../../../src/proxy/ERC1967Proxy.sol";
import "../../../src/bridging/wormhole/WormholeBridge.sol";

import "../../../src/bridging/interfaces/IWormholeBridge.sol";

import "../../common/Constants.t.sol";

contract AdminTest is Test {
    // Test Contracts
    USX public usx_implementation;
    ERC1967Proxy public usx_proxy;
    WormholeBridge public wormhole_bridge;

    function setUp() public {
        usx_implementation = new USX();
        usx_proxy = new ERC1967Proxy(address(usx_implementation), abi.encodeWithSignature("initialize()"));
        wormhole_bridge = new WormholeBridge(WORMHOLE_CORE_BRIDGE, address(usx_proxy));
    }

    function test_manageTrustedContracts() public {
        assertEq(IWormholeBridge(address(wormhole_bridge)).trustedContracts(TEST_TRUSTED_EMITTER_ADDRESS), false);

        // Act
        IWormholeBridge(address(wormhole_bridge)).manageTrustedContracts(TEST_TRUSTED_EMITTER_ADDRESS, true);

        assertEq(IWormholeBridge(address(wormhole_bridge)).trustedContracts(TEST_TRUSTED_EMITTER_ADDRESS), true);
    }

    function testCannot_manageTrustedContracts_sender(address sender) public {
        vm.assume(sender != address(this));

        vm.expectRevert("Ownable: caller is not the owner");

        // Act
        vm.prank(sender);
        IWormholeBridge(address(wormhole_bridge)).manageTrustedContracts(TEST_TRUSTED_EMITTER_ADDRESS, true);
    }

    function test_manageTrustedRelayers() public {
        assertEq(IWormholeBridge(address(wormhole_bridge)).trustedRelayers(TRUSTED_WORMHOLE_RELAYER), false);

        // Act
        IWormholeBridge(address(wormhole_bridge)).manageTrustedRelayers(TRUSTED_WORMHOLE_RELAYER, true);

        assertEq(IWormholeBridge(address(wormhole_bridge)).trustedRelayers(TRUSTED_WORMHOLE_RELAYER), true);
    }

    function testCannot_manageTrustedRelayers_sender(address sender) public {
        vm.assume(sender != address(this));

        vm.expectRevert("Ownable: caller is not the owner");

        // Act
        vm.prank(sender);
        IWormholeBridge(address(wormhole_bridge)).manageTrustedRelayers(TRUSTED_WORMHOLE_RELAYER, true);
    }

    function test_getTrustedContracts() public {
        // Setup
        bytes32[3] memory testTrustedEmitters = [
            bytes32(abi.encode(0xc144b96b42924EBb9e5f7eF7B27957E576A6D102)),
            bytes32(abi.encode(0xD3Ba011d21C200a8520f72A67494269Fc259921E)),
            bytes32(abi.encode(0xB78535ca0CFA787455e65BFFC0f4446472F5E297))
        ];

        for (uint256 i = 0; i < testTrustedEmitters.length; i++) {
            IWormholeBridge(address(wormhole_bridge)).manageTrustedContracts(testTrustedEmitters[i], true);
        }

        // Act
        bytes32[] memory trustedEmitters = IWormholeBridge(address(wormhole_bridge)).getTrustedContracts();

        // Assertions
        for (uint256 i = 0; i < testTrustedEmitters.length; i++) {
            assertEq(trustedEmitters[i], testTrustedEmitters[i]);
        }
    }

    function testCannot_getTrustedContracts_sender(address sender) public {
        vm.assume(sender != address(this));

        vm.expectRevert("Ownable: caller is not the owner");

        vm.prank(sender);
        IWormholeBridge(address(wormhole_bridge)).getTrustedContracts();
    }

    function test_getTrustedRelayers() public {
        // Setup
        address[3] memory testTrustedRelayers = [
            0x456BeD4bE47d36221f017FB850b1dd41c4678490,
            0xeeCE0Ce45f3562263fc70Ff796b672f5818ED436,
            0x8A65B1aB965dE3D1f1d90BE7999eB15D490fb271
        ];

        for (uint256 i = 0; i < testTrustedRelayers.length; i++) {
            IWormholeBridge(address(wormhole_bridge)).manageTrustedRelayers(testTrustedRelayers[i], true);
        }

        // Act
        address[] memory trustedRelayers = IWormholeBridge(address(wormhole_bridge)).getTrustedRelayers();

        // Assertions
        for (uint256 i = 0; i < testTrustedRelayers.length; i++) {
            assertEq(trustedRelayers[i], testTrustedRelayers[i]);
        }
    }

    function testCannot_getTrustedRelayers(address sender) public {
        vm.assume(sender != address(this));

        vm.expectRevert("Ownable: caller is not the owner");

        vm.prank(sender);
        IWormholeBridge(address(wormhole_bridge)).getTrustedRelayers();
    }
}
