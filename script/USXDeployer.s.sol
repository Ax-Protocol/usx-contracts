// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import "forge-std/Script.sol";
import "../src/token/USX.sol";
import "../src/proxy/ERC1967Proxy.sol";

import "./common/Constants.s.sol";

contract USXDeployer is Script, DeployerUtils {
    // Contracts
    USX public usx_implementation;
    ERC1967Proxy public usx_proxy;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        // Deploy contracts
        deploy();

        vm.stopBroadcast();
    }

    function deploy() private {
        // USX
        usx_implementation = new USX();
        usx_proxy = new ERC1967Proxy(address(usx_implementation), abi.encodeWithSignature("initialize()"));
    }
}
