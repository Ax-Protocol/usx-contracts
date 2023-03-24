// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "forge-std/Test.sol";

import "../../script/LayerZeroBridgeDeployer.s.sol";
import "../../src/token/USX.sol";
import "../../src/proxy/ERC1967Proxy.sol";

/// @dev needs access to .env
contract LayerZeroBridgeDeployerTest is Test, DeployerUtils {
    // Test Contracts
    LayerZeroBridgeDeployer public deployer;
    USX public usx_implementation;
    ERC1967Proxy public usx_proxy;

    function setUp() public {
        // USX
        vm.startPrank(vm.envAddress("DEPLOYER_ADDRESS"));
        usx_implementation = new USX();
        usx_proxy = new ERC1967Proxy(address(usx_implementation), abi.encodeWithSignature("initialize()"));
        vm.stopPrank();

        // Deployer
        deployer = new LayerZeroBridgeDeployer();
    }

    function test_run() public {
        // Pre-action assertions
        assertEq(address(deployer.layer_zero_bridge_implementation()), address(0), "Contract should have null address.");
        assertEq(address(deployer.layer_zero_bridge_proxy()), address(0), "Contract should have null address.");

        // Act
        deployer.run(address(usx_proxy));

        // Assert that contracts were deployed
        assert(address(deployer.layer_zero_bridge_implementation()) != address(0));
        assert(address(deployer.layer_zero_bridge_proxy()) != address(0));

        test_LayerZeroBridgeSetup();
    }

    function test_LayerZeroBridgeSetup() private {
        // Check mint and burn privileges
        (bool mint, bool burn) = IUSXAdmin(address(usx_proxy)).treasuries(address(deployer.layer_zero_bridge_proxy()));
        assertEq(mint, true, "Privilege failed: LayerZeroBridge should have mint privileges.");
        assertEq(burn, false, "Privilege failed: LayerZeroBridge should not have burn privileges.");

        // Check LayerZeroBridge trusted remote
        for (uint256 i; i < LZ_CHAIN_IDS.length; i++) {
            assertEq(
                ILayerZeroBridge(address(deployer.layer_zero_bridge_proxy())).isTrustedRemote(
                    LZ_CHAIN_IDS[i],
                    abi.encodePacked(
                        address(deployer.layer_zero_bridge_proxy()), address(deployer.layer_zero_bridge_proxy())
                    )
                ),
                true,
                "LayerZeroBridge trusted remote failed."
            );
        }
    }
}
