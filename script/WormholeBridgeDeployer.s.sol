// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import "forge-std/Script.sol";
import "../src/bridging/wormhole/WormholeBridge.sol";
import "../src/proxy/ERC1967Proxy.sol";
import "../src/common/interfaces/IUSXAdmin.sol";
import "../src/bridging/interfaces/IWormholeBridge.sol";

import "./common/Constants.s.sol";

/// @dev a hub chain is defined as a chain that has a treasury on it.
contract WormholeBridgeDeployer is Script, DeployerUtils {
    // Contracts
    WormholeBridge public wormhole_bridge_implementation;
    ERC1967Proxy public wormhole_bridge_proxy;

    function run(address usx_proxy) public {
        uint256 deployerPrivateKey = vm.envUint("WH_BRIDGE_DEPLOYER_PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Deploy contracts
        deploy(usx_proxy);

        // Configure contracts
        configureBridge(usx_proxy);
    }

    function deploy(address usx_proxy) private {
        // Bridge contracts
        wormhole_bridge_implementation = new WormholeBridge();
        wormhole_bridge_proxy =
        new ERC1967Proxy(address(wormhole_bridge_implementation), abi.encodeWithSignature("initialize(address,address)", vm.envAddress("WORMHOLE_CORE_BRIDGE"), usx_proxy));
    }

    function configureBridge(address usx_proxy) private {
        // Set Trusted Entities for Wormhole
        IWormholeBridge(address(wormhole_bridge_proxy)).manageTrustedContracts(
            bytes32(abi.encode(address(wormhole_bridge_proxy))), true
        );
        IWormholeBridge(address(wormhole_bridge_proxy)).manageTrustedRelayers(
            vm.envAddress("WORMHOLE_TRUSTED_RELAYER"), true
        );
        vm.stopBroadcast();

        // Set burn and mint privileges
        uint256 deployerPrivateKey = vm.envUint("USX_DEPLOYER_PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        IUSXAdmin(usx_proxy).manageTreasuries(address(wormhole_bridge_proxy), true, false);
        vm.stopBroadcast();
    }
}
