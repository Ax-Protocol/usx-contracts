// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "forge-std/Test.sol";

import "../../script/Deployer.s.sol";

contract DeployerTest is Test, DeployerUtils {
    // Test Contracts
    Deployer public deployer;

    function setUp() public {
        deployer = new Deployer();
    }

    function test_run() public {
        // Pre-action assertions
        assertEq(address(deployer.usx_implementation()), address(0), "Contract should have null address.");
        assertEq(address(deployer.treasury_implementation()), address(0), "Contract should have null address.");
        assertEq(address(deployer.wormhole_bridge_implementation()), address(0), "Contract should have null address.");
        assertEq(address(deployer.layer_zero_bridge_implementation()), address(0), "Contract should have null address.");
        assertEq(address(deployer.usx_proxy()), address(0), "Contract should have null address.");
        assertEq(address(deployer.treasury_proxy()), address(0), "Contract should have null address.");
        assertEq(address(deployer.layer_zero_bridge_proxy()), address(0), "Contract should have null address.");
        assertEq(address(deployer.wormhole_bridge_proxy()), address(0), "Contract should have null address.");

        // Act
        deployer.run();

        // Assert that contracts were deployed
        assert(address(deployer.usx_implementation()) != address(0));
        assert(address(deployer.treasury_implementation()) != address(0));
        assert(address(deployer.wormhole_bridge_implementation()) != address(0));
        assert(address(deployer.layer_zero_bridge_implementation()) != address(0));
        assert(address(deployer.usx_proxy()) != address(0));
        assert(address(deployer.treasury_proxy()) != address(0));
        assert(address(deployer.layer_zero_bridge_proxy()) != address(0));
        assert(address(deployer.wormhole_bridge_proxy()) != address(0));

        test_treaurySetup();
        test_LayerZeroBridgeSetup();
        test_WormholeBridgeSetup();
    }

    function test_treaurySetup() private {
        // Check mint and burn privileges
        (bool mint, bool burn) = IUSXAdmin(address(deployer.usx_proxy())).treasuries(address(deployer.treasury_proxy()));
        assertEq(mint, true, "Privilege failed: Treasury should have mint privileges.");
        assertEq(burn, true, "Privilege failed: Treasury should have burn privileges.");

        // Check Treasury's supported stables
        (bool supported, int128 returnedTestCurveIndex) =
            ITreasuryAdmin(address(deployer.treasury_proxy())).supportedStables(DAI);
        assertEq(supported, true, "Error: failed to add supported stable.");
        (supported, returnedTestCurveIndex) = ITreasuryAdmin(address(deployer.treasury_proxy())).supportedStables(USDC);
        assertEq(supported, true, "Error: failed to add supported stable.");
        (supported, returnedTestCurveIndex) = ITreasuryAdmin(address(deployer.treasury_proxy())).supportedStables(USDT);
        assertEq(supported, true, "Error: failed to add supported stable.");
    }

    function test_LayerZeroBridgeSetup() private {
        // Check mint and burn privileges
        (bool mint, bool burn) =
            IUSXAdmin(address(deployer.usx_proxy())).treasuries(address(deployer.layer_zero_bridge_proxy()));
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

        // Cross-chain transfer privileges
        assertEq(
            IUSXAdmin(address(deployer.usx_proxy())).transferPrivileges(address(deployer.layer_zero_bridge_proxy())),
            true,
            "LayerZero cross-chain transfer privileges failed."
        );
    }

    function test_WormholeBridgeSetup() private {
        // Check mint and burn privileges
        (bool mint, bool burn) =
            IUSXAdmin(address(deployer.usx_proxy())).treasuries(address(deployer.wormhole_bridge_proxy()));
        assertEq(mint, true, "Privilege failed: WormholeBridge should have mint privileges.");
        assertEq(burn, false, "Privilege failed: WormholeBridge should not have burn privileges.");

        // Check WormholeBridge trusted entities
        assertEq(
            IWormholeBridge(address(deployer.wormhole_bridge_proxy())).trustedContracts(TEST_TRUSTED_EMITTER),
            true,
            "WormholeBridge manageTrustedContracts failed."
        );
        assertEq(
            IWormholeBridge(address(deployer.wormhole_bridge_proxy())).trustedRelayers(TRUSTED_WORMHOLE_RELAYER),
            true,
            "WormholeBridge manageTrustedRelayers failed."
        );

        // Cross-chain Transfer Privileges
        assertEq(
            IUSXAdmin(address(deployer.usx_proxy())).transferPrivileges(address(deployer.wormhole_bridge_proxy())),
            true,
            "Wormhole cross-chain transfer privileges failed."
        );
    }
}
