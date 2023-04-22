// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import "forge-std/Script.sol";

import "../src/bridging/layer_zero/LayerZeroBridge.sol";
import "../src/proxy/ERC1967Proxy.sol";
import "../src/bridging/interfaces/ILayerZeroBridge.sol";
import "../src/common/interfaces/IUSXAdmin.sol";

import "./common/Constants.s.sol";

/// @dev a periphery chain is defined as a chain that does not have a treasury on it.
contract LayerZeroBridgeDeployer is Script, DeployerUtils {
    // Contracts
    LayerZeroBridge public layer_zero_bridge_implementation;
    ERC1967Proxy public layer_zero_bridge_proxy;

    function run(address usx_proxy) public {
        uint256 deployerPrivateKey = vm.envUint("LZ_BRIDGE_DEPLOYER_PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Deploy contracts
        deploy(usx_proxy);

        // Configure contracts
        configureBridge(usx_proxy);
    }

    function deploy(address usx_proxy) private {
        // Bridge contracts
        layer_zero_bridge_implementation = new LayerZeroBridge();
        layer_zero_bridge_proxy =
        new ERC1967Proxy(address(layer_zero_bridge_implementation), abi.encodeWithSignature("initialize(address,address)", vm.envAddress("LZ_ENDPOINT"), usx_proxy));
    }

    function configureBridge(address usx_proxy) private {
        // Set Trusted Remote for LayerZero (remove deployment chain's id from list)
        for (uint256 i; i < LZ_CHAIN_IDS.length; i++) {
            ILayerZeroBridge(address(layer_zero_bridge_proxy)).setTrustedRemote(
                LZ_CHAIN_IDS[i], abi.encodePacked(address(layer_zero_bridge_proxy), address(layer_zero_bridge_proxy))
            );
        }
        vm.stopBroadcast();

        // Set burn and mint privileges
        uint256 deployerPrivateKey = vm.envUint("USX_DEPLOYER_PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        IUSXAdmin(usx_proxy).manageTreasuries(address(layer_zero_bridge_proxy), true, false);
        vm.stopBroadcast();
    }
}
