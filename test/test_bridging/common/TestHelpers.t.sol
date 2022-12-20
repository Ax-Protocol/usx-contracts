// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "forge-std/Test.sol";
import "../../../src/token/USX.sol";
import "../../../src/bridging/wormhole/WormholeBridge.sol";
import "../../../src/bridging/layer_zero/LayerZeroBridge.sol";
import "../../../src/proxy/ERC1967Proxy.sol";
import "../../mocks/MockLayerZero.t.sol";

import "../../../src/common/interfaces/IUSXAdmin.sol";

import "../../common/Constants.t.sol";

abstract contract BridgingSetup is Test {
    // Test Contracts
    USX public usx_implementation;
    ERC1967Proxy public usx_proxy;
    LayerZeroBridge public layer_zero_bridge;
    WormholeBridge public wormhole_bridge;

    // Test Constants
    uint16 constant TEST_LZ_CHAIN_ID = 109;
    uint16 constant TEST_WORM_CHAIN_ID = 5;

    // Events
    event ReceiveFromChain(
        uint16 indexed _srcChainId, bytes indexed _srcAddress, address indexed _toAddress, uint256 _amount
    );
    event SendToChain(uint16 indexed _dstChainId, address indexed _from, bytes indexed _toAddress, uint256 _amount);

    function setUp() public {
        // Deploy USX implementation, and link to proxy
        usx_implementation = new USX();
        usx_proxy = new ERC1967Proxy(address(usx_implementation), abi.encodeWithSignature("initialize()"));

        // Deploy Bridge contracts
        wormhole_bridge = new WormholeBridge(WORMHOLE_CORE_BRIDGE, address(usx_proxy));
        layer_zero_bridge = new LayerZeroBridge(LZ_ENDPOINT, address(usx_proxy));

        // Set Treasury admins
        IUSXAdmin(address(usx_proxy)).manageTreasuries(TREASURY, true, true);
        IUSXAdmin(address(usx_proxy)).manageTreasuries(address(wormhole_bridge), true, false);
        IUSXAdmin(address(usx_proxy)).manageTreasuries(address(layer_zero_bridge), true, false);

        // Mint initial Tokens
        vm.prank(TREASURY);
        IUSXAdmin(address(usx_proxy)).mint(address(this), INITIAL_TOKENS);

        // Set Trusted Remote for LayerZero
        layer_zero_bridge.setTrustedRemote(
            TEST_LZ_CHAIN_ID, abi.encodePacked(address(layer_zero_bridge), address(layer_zero_bridge))
        );

        // Mocks
        bytes memory MockLayerZeroCode = address(new MockLayerZero()).code;
        vm.etch(LZ_ENDPOINT, MockLayerZeroCode);

        // Set Trusted Entities for Wormhole
        wormhole_bridge.manageTrustedContracts(TEST_TRUSTED_EMITTER_ADDRESS, true);
        wormhole_bridge.manageTrustedRelayers(TRUSTED_WORMHOLE_RELAYER, true);

        // Grant Transfer privliges
        IUSXAdmin(address(usx_proxy)).manageCrossChainTransfers(
            [address(wormhole_bridge), address(layer_zero_bridge)], [true, true]
        );
    }
}
