// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import "forge-std/Script.sol";
import "../src/token/USX.sol";
import "../src/treasury/Treasury.sol";
import "../src/bridging/wormhole/WormholeBridge.sol";
import "../src/bridging/layer_zero/LayerZeroBridge.sol";
import "../src/proxy/ERC1967Proxy.sol";
import "../src/common/interfaces/IUSXAdmin.sol";
import "../src/treasury/interfaces/ITreasuryAdmin.sol";
import "../src/bridging/interfaces/ILayerZeroBridge.sol";
import "../src/bridging/interfaces/IWormholeBridge.sol";

import "./common/Constants.s.sol";

/// @dev a hub chain is defined as a chain that has a treasury on it.
contract DeployerHubChain is Script, DeployerUtils {
    // Contracts
    USX public usx_implementation;
    Treasury public treasury_implementation;
    WormholeBridge public wormhole_bridge_implementation;
    LayerZeroBridge public layer_zero_bridge_implementation;
    ERC1967Proxy public usx_proxy;
    ERC1967Proxy public treasury_proxy;
    ERC1967Proxy public layer_zero_bridge_proxy;
    ERC1967Proxy public wormhole_bridge_proxy;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        // Deploy contracts
        deploy();

        // Configure contracts
        configureTreasury();
        configureBridges();

        vm.stopBroadcast();
    }

    function deploy() private {
        // USX
        usx_implementation = new USX();
        usx_proxy = new ERC1967Proxy(address(usx_implementation), abi.encodeWithSignature("initialize()"));

        // Treasury
        treasury_implementation = new Treasury();
        treasury_proxy =
        new ERC1967Proxy(address(treasury_implementation), abi.encodeWithSignature("initialize(address)", address(usx_proxy)));

        // Bridge contracts
        wormhole_bridge_implementation = new WormholeBridge();
        wormhole_bridge_proxy =
        new ERC1967Proxy(address(wormhole_bridge_implementation), abi.encodeWithSignature("initialize(address,address)", vm.envAddress("WORMHOLE_CORE_BRIDGE"), address(usx_proxy)));

        layer_zero_bridge_implementation = new LayerZeroBridge();
        layer_zero_bridge_proxy =
        new ERC1967Proxy(address(layer_zero_bridge_implementation), abi.encodeWithSignature("initialize(address,address)", vm.envAddress("LZ_ENDPOINT"), address(usx_proxy)));
    }

    function configureTreasury() private {
        // Set burn and mint privileges
        IUSXAdmin(address(usx_proxy)).manageTreasuries(address(treasury_proxy), true, true);

        // Set supported stables
        ITreasuryAdmin(address(treasury_proxy)).addSupportedStable(vm.envAddress("DAI"), 0);
        ITreasuryAdmin(address(treasury_proxy)).addSupportedStable(vm.envAddress("USDC"), 1);
        ITreasuryAdmin(address(treasury_proxy)).addSupportedStable(vm.envAddress("USDT"), 2);
    }

    function configureBridges() private {
        // Set burn and mint privileges
        IUSXAdmin(address(usx_proxy)).manageTreasuries(address(wormhole_bridge_proxy), true, false);
        IUSXAdmin(address(usx_proxy)).manageTreasuries(address(layer_zero_bridge_proxy), true, false);

        // Set Trusted Remote for LayerZero
        for (uint256 i; i < LZ_CHAIN_IDS.length; i++) {
            ILayerZeroBridge(address(layer_zero_bridge_proxy)).setTrustedRemote(
                LZ_CHAIN_IDS[i], abi.encodePacked(address(layer_zero_bridge_proxy), address(layer_zero_bridge_proxy))
            );
        }

        // Set Trusted Entities for Wormhole
        IWormholeBridge(address(wormhole_bridge_proxy)).manageTrustedContracts(
            bytes32(abi.encode(address(wormhole_bridge_proxy))), true
        );
        IWormholeBridge(address(wormhole_bridge_proxy)).manageTrustedRelayers(
            vm.envAddress("WORMHOLE_TRUSTED_RELAYER"), true
        );

        // Grant Transfer priviliges
        IUSXAdmin(address(usx_proxy)).manageCrossChainTransfers(
            [address(wormhole_bridge_proxy), address(layer_zero_bridge_proxy)], [true, true]
        );
    }
}
