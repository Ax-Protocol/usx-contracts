// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "forge-std/Test.sol";
import "../../../src/token/USX.sol";
import "../../../src/bridging/wormhole/WormholeBridge.sol";
import "../../../src/bridging/layer_zero/LayerZeroBridge.sol";
import "../../../src/proxy/ERC1967Proxy.sol";

import "../../../src/common/interfaces/IUSXAdmin.sol";

import "../../common/Constants.t.sol";

abstract contract BridgingSetup is Test {
    // Test Contracts
    USX public usx_implementation;
    ERC1967Proxy public usx_proxy;
    LayerZeroBridge public layer_zero_bridge;
    WormholeBridge public wormhole_bridge;

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

        // Set Trusted Entities for Wormhole
        wormhole_bridge.manageTrustedContracts(TEST_TRUSTED_EMITTER_ADDRESS, true);
        wormhole_bridge.manageTrustedRelayers(TRUSTED_WORMHOLE_RELAYER, true);

        // Set Destination Gas Fees for Wormhole
        _setDestinationFees();

        // Grant Transfer privliges
        IUSXAdmin(address(usx_proxy)).manageCrossChainTransfers(
            [address(wormhole_bridge), address(layer_zero_bridge)], [true, true]
        );
    }

    function _setDestinationFees() internal {
        // Setup
        uint256 testCases = 5;

        for (uint256 i = 1; i < (testCases + 1); i++) {
            destChainIds.push(uint16(i));
            fees.push(i * 1e15);
        }

        // Act: update
        wormhole_bridge.setSendFees(destChainIds, fees);
    }

    // Need this to receive funds from layer zero
    receive() external payable {}
}
