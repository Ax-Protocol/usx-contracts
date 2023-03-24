// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "forge-std/Test.sol";

import "../../script/WormholeBridgeDeployer.s.sol";
import "../../src/token/USX.sol";
import "../../src/proxy/ERC1967Proxy.sol";

/// @dev needs access to .env
contract WormholeBridgeDeployerTest is Test, DeployerUtils {
    // Test Contracts
    WormholeBridgeDeployer public deployer;
    USX public usx_implementation;
    ERC1967Proxy public usx_proxy;

    function setUp() public {
        // USX
        vm.startPrank(vm.envAddress("DEPLOYER_ADDRESS"));
        usx_implementation = new USX();
        usx_proxy = new ERC1967Proxy(address(usx_implementation), abi.encodeWithSignature("initialize()"));
        vm.stopPrank();

        // Deployer
        deployer = new WormholeBridgeDeployer();
    }

    function test_run() public {
        // Pre-action assertions
        assertEq(address(deployer.wormhole_bridge_implementation()), address(0), "Contract should have null address.");
        assertEq(address(deployer.wormhole_bridge_proxy()), address(0), "Contract should have null address.");

        // Act
        deployer.run(address(usx_proxy));

        // Assert that contracts were deployed
        assert(address(deployer.wormhole_bridge_implementation()) != address(0));
        assert(address(deployer.wormhole_bridge_proxy()) != address(0));

        test_WormholeBridgeSetup();
    }

    function test_WormholeBridgeSetup() private {
        // Check mint and burn privileges
        (bool mint, bool burn) = IUSXAdmin(address(usx_proxy)).treasuries(address(deployer.wormhole_bridge_proxy()));
        assertEq(mint, true, "Privilege failed: WormholeBridge should have mint privileges.");
        assertEq(burn, false, "Privilege failed: WormholeBridge should not have burn privileges.");

        // Check WormholeBridge trusted entities
        assertEq(
            IWormholeBridge(address(deployer.wormhole_bridge_proxy())).trustedContracts(
                bytes32(abi.encode(address(deployer.wormhole_bridge_proxy())))
            ),
            true,
            "WormholeBridge manageTrustedContracts failed."
        );
        assertEq(
            IWormholeBridge(address(deployer.wormhole_bridge_proxy())).trustedRelayers(
                vm.envAddress("WORMHOLE_TRUSTED_RELAYER")
            ),
            true,
            "WormholeBridge manageTrustedRelayers failed."
        );
    }
}
