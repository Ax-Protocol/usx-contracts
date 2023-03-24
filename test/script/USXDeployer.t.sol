// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "forge-std/Test.sol";

import "../../script/USXDeployer.s.sol";

/// @dev needs access to .env
contract USXDeployerTest is Test, DeployerUtils {
    // Test Contracts
    USXDeployer public deployer;

    function setUp() public {
        deployer = new USXDeployer();
    }

    function test_run() public {
        // Pre-action assertions
        assertEq(address(deployer.usx_implementation()), address(0), "Contract should have null address.");
        assertEq(address(deployer.usx_proxy()), address(0), "Contract should have null address.");

        // Act
        deployer.run();

        // Assert that contracts were deployed
        assert(address(deployer.usx_implementation()) != address(0));
        assert(address(deployer.usx_proxy()) != address(0));

        test_metadata();
    }

    function test_metadata() private {
        assertEq(IUSX(address(deployer.usx_proxy())).name(), "USX", "Incorrect name.");
        assertEq(IUSX(address(deployer.usx_proxy())).symbol(), "USX", "Incorrect symbol.");
        assertEq(IUSX(address(deployer.usx_proxy())).decimals(), 18, "Incorrect decimals.");
    }
}
