// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "forge-std/Test.sol";

import "../../script/TreasuryDeployer.s.sol";
import "../../src/token/USX.sol";
import "../../src/proxy/ERC1967Proxy.sol";

contract TreasuryDeployerTest is Test, DeployerUtils {
    // Test Contracts
    TreasuryDeployer public deployer;
    USX public usx_implementation;
    ERC1967Proxy public usx_proxy;

    function setUp() public {
        // USX
        vm.startPrank(vm.envAddress("DEPLOYER_ADDRESS"));
        usx_implementation = new USX();
        usx_proxy = new ERC1967Proxy(address(usx_implementation), abi.encodeWithSignature("initialize()"));
        vm.stopPrank();

        // Deployer
        deployer = new TreasuryDeployer();
    }

    function test_run() public {
        // Pre-action assertions
        assertEq(address(deployer.treasury_implementation()), address(0), "Contract should have null address.");
        assertEq(address(deployer.treasury_proxy()), address(0), "Contract should have null address.");

        // Act
        deployer.run(address(usx_proxy));

        // Assert that contracts were deployed
        assert(address(deployer.treasury_implementation()) != address(0));
        assert(address(deployer.treasury_proxy()) != address(0));

        test_treaurySetup();
    }

    function test_treaurySetup() private {
        // Check mint and burn privileges
        (bool mint, bool burn) = IUSXAdmin(address(usx_proxy)).treasuries(address(deployer.treasury_proxy()));
        assertEq(mint, true, "Privilege failed: Treasury should have mint privileges.");
        assertEq(burn, true, "Privilege failed: Treasury should have burn privileges.");

        // Check Treasury's supported stables
        (bool supported, int128 returnedTestCurveIndex) =
            ITreasuryAdmin(address(deployer.treasury_proxy())).supportedStables(vm.envAddress("DAI"));
        assertEq(supported, true, "Error: failed to add supported stable.");
        (supported, returnedTestCurveIndex) =
            ITreasuryAdmin(address(deployer.treasury_proxy())).supportedStables(vm.envAddress("USDC"));
        assertEq(supported, true, "Error: failed to add supported stable.");
        (supported, returnedTestCurveIndex) =
            ITreasuryAdmin(address(deployer.treasury_proxy())).supportedStables(vm.envAddress("USDT"));
        assertEq(supported, true, "Error: failed to add supported stable.");
    }
}
