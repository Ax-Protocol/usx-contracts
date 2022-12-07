// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "forge-std/Test.sol";
import "../../../src/USX.sol";
import "../../../src/proxy/ERC1967Proxy.sol";
import "../../interfaces/IUSXTest.t.sol";
import "../../common/constants.t.sol";
import "./common/TestHelpers.t.sol";

contract TestAdminUSX is Test, SupplyRegulationSetup {
    function test_manageTreasuries() public {
        // Pre-action assertions
        (bool mint, bool burn) = IUSXTest(address(usx_proxy)).treasuries(TREASURY);
        assertEq(mint, true, "Privilege failed: should have mint privileges.");
        assertEq(burn, true, "Privilege failed: should have mint privileges.");

        // Act 1 - revoke privileges
        IUSXTest(address(usx_proxy)).manageTreasuries(TREASURY, false, false);

        // Post-action 1 assertions
        (mint, burn) = IUSXTest(address(usx_proxy)).treasuries(TREASURY);
        assertEq(mint, false, "Privilege failed: should not have mint privileges.");
        assertEq(burn, false, "Privilege failed: should not have burn privileges.");

        // Act 2 - add burn privilege
        IUSXTest(address(usx_proxy)).manageTreasuries(TREASURY, false, true);

        // Post-action 2 assertions
        (mint, burn) = IUSXTest(address(usx_proxy)).treasuries(TREASURY);
        assertEq(mint, false, "Privilege failed: should not have mint privileges.");
        assertEq(burn, true, "Privilege failed: should have burn privileges.");
    }

    function testCannot_manageTreasuries_sender() public {
        // Expectations
        vm.expectRevert("Ownable: caller is not the owner");

        // Act
        vm.prank(TEST_ADDRESS);
        IUSXTest(address(usx_proxy)).manageTreasuries(TREASURY, false, false);
    }
}
