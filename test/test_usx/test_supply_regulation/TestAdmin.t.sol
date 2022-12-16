// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "forge-std/Test.sol";
import "./common/TestHelpers.t.sol";
import "../../../src/token/USX.sol";
import "../../../src/proxy/ERC1967Proxy.sol";

import "../../../src/common/interfaces/IUSXAdmin.sol";

import "../../common/Constants.t.sol";
import "./common/Constants.t.sol";

contract TestAdminUSX is Test, SupplyRegulationSetup {
    function test_manageTreasuries() public {
        // Pre-action assertions
        (bool mint, bool burn) = IUSXAdmin(address(usx_proxy)).treasuries(TREASURY);
        assertEq(mint, true, "Privilege failed: should have mint privileges.");
        assertEq(burn, true, "Privilege failed: should have mint privileges.");

        // Act 1 - revoke privileges
        IUSXAdmin(address(usx_proxy)).manageTreasuries(TREASURY, false, false);

        // Post-action 1 assertions
        (mint, burn) = IUSXAdmin(address(usx_proxy)).treasuries(TREASURY);
        assertEq(mint, false, "Privilege failed: should not have mint privileges.");
        assertEq(burn, false, "Privilege failed: should not have burn privileges.");

        // Act 2 - add burn privilege
        IUSXAdmin(address(usx_proxy)).manageTreasuries(TREASURY, false, true);

        // Post-action 2 assertions
        (mint, burn) = IUSXAdmin(address(usx_proxy)).treasuries(TREASURY);
        assertEq(mint, false, "Privilege failed: should not have mint privileges.");
        assertEq(burn, true, "Privilege failed: should have burn privileges.");
    }

    function testCannot_manageTreasuries_sender() public {
        // Expectations
        vm.expectRevert("Ownable: caller is not the owner");

        // Act
        vm.prank(TEST_ADDRESS);
        IUSXAdmin(address(usx_proxy)).manageTreasuries(TREASURY, false, false);
    }

    function test_extractERC20_usx(uint256 amount) public {
        vm.assume(amount > 0 && amount < 1e6);

        // Send the treasury an ERC20 token
        deal(TEST_USDC, address(usx_proxy), amount);

        // Pre-action assertions
        assertEq(
            IERC20(TEST_USDC).balanceOf(address(usx_proxy)),
            amount,
            "Equivalence violation: treausury test coin balance and amount"
        );

        // Act
        IUSXAdmin(address(usx_proxy)).extractERC20(TEST_USDC);

        // Post-action assertions
        assertEq(
            IERC20(TEST_USDC).balanceOf(address(usx_proxy)),
            0,
            "Equivalence violation: treausury test coin balance is not zero"
        );
        assertEq(
            IERC20(TEST_USDC).balanceOf(address(this)),
            amount,
            "Equivalence violation: owner TEST_USDC balance and amount"
        );
    }
}
