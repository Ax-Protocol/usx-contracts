// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "forge-std/Test.sol";
import "../../../src/USX.sol";
import "../../../src/proxy/ERC1967Proxy.sol";
import "../../interfaces/IUSXTest.t.sol";
import "../../common/constants.t.sol";
import "./common/TestHelpers.t.sol";

contract TestBurnUSX is Test, SupplyRegulationSetup {
    function test_burn(uint256 testBurnAmount) public {
        // Assumptions
        vm.assume(testBurnAmount <= TEST_MINT_AMOUNT);

        // Setup
        vm.prank(TREASURY);
        IUSX(address(usx_proxy)).mint(address(this), TEST_MINT_AMOUNT);

        // Pre-action Assertions
        assertEq(IUSX(address(usx_proxy)).totalSupply(), TEST_MINT_AMOUNT);
        assertEq(IUSX(address(usx_proxy)).balanceOf(address(this)), TEST_MINT_AMOUNT);

        // Expectations
        vm.expectEmit(true, true, true, true, address(usx_proxy));
        emit Transfer(address(this), address(0), testBurnAmount);

        // Act
        vm.prank(TREASURY);
        IUSX(address(usx_proxy)).burn(address(this), testBurnAmount);

        // Post-action Assertions
        assertEq(IUSX(address(usx_proxy)).totalSupply(), TEST_MINT_AMOUNT - testBurnAmount);
        assertEq(IUSX(address(usx_proxy)).balanceOf(address(this)), TEST_MINT_AMOUNT - testBurnAmount);
    }

    function testFail_burn_amount(uint256 testInvalidBurnAmount) public {
        // Assumptions
        vm.assume(testInvalidBurnAmount > TEST_MINT_AMOUNT);

        // Setup
        vm.prank(TREASURY);
        IUSX(address(usx_proxy)).mint(address(this), TEST_MINT_AMOUNT);

        // Act
        vm.prank(TREASURY);
        IUSX(address(usx_proxy)).burn(address(this), testInvalidBurnAmount);
    }

    function test_fail_burn_unauthorized(uint256 testBurnAmount) public {
        // Assumptions
        vm.assume(testBurnAmount <= TEST_MINT_AMOUNT);

        // Setup
        vm.prank(TREASURY);
        IUSX(address(usx_proxy)).mint(address(this), TEST_MINT_AMOUNT);

        // Expectations
        vm.expectRevert("Unauthorized.");

        // Act
        IUSX(address(usx_proxy)).burn(address(this), testBurnAmount);
    }
}
