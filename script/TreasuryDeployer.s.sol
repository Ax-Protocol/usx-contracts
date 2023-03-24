// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import "forge-std/Script.sol";
import "../src/treasury/Treasury.sol";
import "../src/proxy/ERC1967Proxy.sol";
import "../src/common/interfaces/IUSXAdmin.sol";
import "../src/treasury/interfaces/ITreasuryAdmin.sol";

import "./common/Constants.s.sol";

/// @dev a hub chain is defined as a chain that has a treasury on it.
contract TreasuryDeployer is Script, DeployerUtils {
    // Contracts
    Treasury public treasury_implementation;
    ERC1967Proxy public treasury_proxy;

    function run(address usx_proxy) public {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Deploy contracts
        deploy(usx_proxy);

        // Configure contracts
        configureTreasury(usx_proxy);

        vm.stopBroadcast();
    }

    function deploy(address usx_proxy) private {
        // Treasury
        treasury_implementation = new Treasury();
        treasury_proxy =
        new ERC1967Proxy(address(treasury_implementation), abi.encodeWithSignature("initialize(address)", usx_proxy));
    }

    function configureTreasury(address usx_proxy) private {
        // Set burn and mint privileges
        IUSXAdmin(usx_proxy).manageTreasuries(address(treasury_proxy), true, true);

        // Set supported stables
        ITreasuryAdmin(address(treasury_proxy)).addSupportedStable(vm.envAddress("DAI"), 0);
        ITreasuryAdmin(address(treasury_proxy)).addSupportedStable(vm.envAddress("USDC"), 1);
        ITreasuryAdmin(address(treasury_proxy)).addSupportedStable(vm.envAddress("USDT"), 2);
    }
}
