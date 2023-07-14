// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "forge-std/Test.sol";
import "../../../../../src/token/USX.sol";
import "../../../../../src/bridging/wormhole/WormholeBridge.sol";
import "../../../../../src/bridging/layer_zero/LayerZeroBridge.sol";
import "../../../../../src/proxy/ERC1967Proxy.sol";

import "../../../../../src/common/interfaces/IUSXAdmin.sol";
import "../../../../../src/bridging/interfaces/IWormholeBridge.sol";
import "../../../../../src/bridging/interfaces/ILayerZeroBridge.sol";

import "../../../common/Constants.t.sol";

abstract contract BridgingSetup is Test, TestUtils {
    // Test Contracts
    USX public usx_implementation;
    LayerZeroBridge public layer_zero_bridge;
    WormholeBridge public wormhole_bridge;
    ERC1967Proxy public usx_proxy;
    ERC1967Proxy public wormhole_bridge_proxy;
    ERC1967Proxy public layer_zero_bridge_proxy;

    // Test Variables
    uint16[] public destChainIds;
    uint256[] public fees;

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
        wormhole_bridge = new WormholeBridge();
        wormhole_bridge_proxy =
        new ERC1967Proxy(address(wormhole_bridge), abi.encodeWithSignature("initialize(address,address)", WORMHOLE_CORE_BRIDGE, address(usx_proxy)));
        layer_zero_bridge = new LayerZeroBridge();
        layer_zero_bridge_proxy =
        new ERC1967Proxy(address(layer_zero_bridge), abi.encodeWithSignature("initialize(address,address)", LZ_ENDPOINT, address(usx_proxy)));

        // Set Treasury admins
        IUSXAdmin(address(usx_proxy)).manageTreasuries(TREASURY, true, true);
        IUSXAdmin(address(usx_proxy)).manageTreasuries(address(wormhole_bridge_proxy), true, false);
        IUSXAdmin(address(usx_proxy)).manageTreasuries(address(layer_zero_bridge_proxy), true, false);

        // Mint initial Tokens
        vm.prank(TREASURY);
        IUSXAdmin(address(usx_proxy)).mint(address(this), INITIAL_TOKENS);

        // Set Trusted Remote for LayerZero
        _setTrustedRemote();

        // Set Trusted Entities for Wormhole
        IWormholeBridge(address(wormhole_bridge_proxy)).manageTrustedContracts(TEST_TRUSTED_EMITTER, true);
        IWormholeBridge(address(wormhole_bridge_proxy)).manageTrustedRelayers(TRUSTED_WORMHOLE_RELAYER, true);
        IWormholeBridge(address(wormhole_bridge_proxy)).setFeeSetter(FEE_SETTER);

        // Set Destination Gas Fees for Wormhole
        _setDestinationFees();

        // Grant Transfer privliges
        IUSXAdmin(address(usx_proxy)).manageCrossChainTransfers(
            [address(wormhole_bridge_proxy), address(layer_zero_bridge_proxy)], [true, true]
        );

        // Enable routes
        IUSXAdmin(address(usx_proxy)).manageRoutes(
            address(layer_zero_bridge_proxy), LZ_TEST_CHAIN_IDS, LZ_TEST_PRIVILEGES
        );
        IUSXAdmin(address(usx_proxy)).manageRoutes(
            address(wormhole_bridge_proxy), WH_TEST_CHAIN_IDS, WH_TEST_PRIVILEGES
        );
    }

    function _setTrustedRemote() internal {
        for (uint256 i; i < LZ_TEST_CHAIN_IDS.length; i++) {
            ILayerZeroBridge(address(layer_zero_bridge_proxy)).setTrustedRemote(
                LZ_TEST_CHAIN_IDS[i],
                abi.encodePacked(address(layer_zero_bridge_proxy), address(layer_zero_bridge_proxy))
            );
        }
    }

    function _setDestinationFees() internal {
        // Setup
        uint256 testCases = 5;

        for (uint256 i = 1; i < (testCases + 1); i++) {
            destChainIds.push(uint16(i));
            fees.push(i * 1e15);
        }

        vm.prank(FEE_SETTER);

        // Act: update
        IWormholeBridge(address(wormhole_bridge_proxy)).setSendFees(destChainIds, fees);
    }

    // Need this to receive funds from layer zero
    receive() external payable { }
}
