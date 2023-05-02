// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import "forge-std/Script.sol";
import "../src/token/USX.sol";
import "../src/treasury/Treasury.sol";
import "../src/bridging/wormhole/WormholeBridge.sol";
import "../src/bridging/layer_zero/LayerZeroBridge.sol";
import "../src/common/interfaces/IUSXAdmin.sol";
import "../src/treasury/interfaces/ITreasuryAdmin.sol";
import "../src/bridging/interfaces/IWormholeBridge.sol";
import "../src/bridging/interfaces/ILayerZeroBridge.sol";
import "./common/Constants.s.sol";

contract ProxyUpgrader is Script, DeployerUtils {
    // Contracts
    USX public usx_implementation;
    Treasury public treasury_implementation;
    WormholeBridge public wormhole_bridge_implementation;
    LayerZeroBridge public layer_zero_bridge_implementation;

    function run(address proxy_contract) public {
        uint256 adminPrivateKey;

        if (proxy_contract == USX_PROXY) {
            adminPrivateKey = vm.envUint("USX_DEPLOYER_PRIVATE_KEY");
        } else if (proxy_contract == TREASURY_PROXY) {
            adminPrivateKey = vm.envUint("TREASURY_DEPLOYER_PRIVATE_KEY");
        } else if (proxy_contract == WH_BRIDGE_PROXY) {
            adminPrivateKey = vm.envUint("WH_BRIDGE_DEPLOYER_PRIVATE_KEY");
        } else if (proxy_contract == LZ_BRIDGE_PROXY) {
            adminPrivateKey = vm.envUint("LZ_BRIDGE_DEPLOYER_PRIVATE_KEY");
        }

        vm.startBroadcast(adminPrivateKey);

        // Deploy new implementation and upgrade current proxy contract
        deployAndUpgrade(proxy_contract);

        vm.stopBroadcast();
    }

    function deployAndUpgrade(address proxy_contract) private {
        if (proxy_contract == USX_PROXY) {
            usx_implementation = new USX();
            IUSXAdmin(address(proxy_contract)).upgradeTo(address(usx_implementation));
        } else if (proxy_contract == TREASURY_PROXY) {
            treasury_implementation = new Treasury();
            ITreasuryAdmin(address(proxy_contract)).upgradeTo(address(treasury_implementation));
        } else if (proxy_contract == WH_BRIDGE_PROXY) {
            wormhole_bridge_implementation = new WormholeBridge();
            IWormholeBridge(address(proxy_contract)).upgradeTo(address(wormhole_bridge_implementation));
        } else if (proxy_contract == LZ_BRIDGE_PROXY) {
            layer_zero_bridge_implementation = new LayerZeroBridge();
            ILayerZeroBridge(address(proxy_contract)).upgradeTo(address(layer_zero_bridge_implementation));
        }
    }
}
