// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "forge-std/Test.sol";
import "../../../../src/token/USX.sol";
import "./../common/TestSetup.t.sol";
import "../../../../src/proxy/ERC1967Proxy.sol";

import "../../../../src/common/interfaces/IUSXAdmin.sol";

import "../../../common/Constants.t.sol";

contract TreasuryPrivilegesTest is Test, SupplyRegulationSetup {
    /// @dev Integration tests.

    function test_manageTreasuries_mint_integration() public {
        // Test Variables
        uint256 BALANCE_AFTER_FIRST_MINT = TEST_MINT_AMOUNT;
        uint256 BALANCE_AFTER_SECOND_MINT = BALANCE_AFTER_FIRST_MINT + TEST_MINT_AMOUNT;

        // 1. Ensure can mint
        vm.expectEmit(true, true, true, true, address(usx_proxy));
        emit Transfer(address(0), address(this), TEST_MINT_AMOUNT);

        vm.prank(TREASURY);
        IUSX(address(usx_proxy)).mint(address(this), TEST_MINT_AMOUNT);

        assertEq(
            IUSX(address(usx_proxy)).totalSupply(),
            BALANCE_AFTER_FIRST_MINT,
            "Equivalence violation: total supply and BALANCE_AFTER_FIRST_MINT."
        );
        assertEq(
            IUSX(address(usx_proxy)).balanceOf(address(this)),
            BALANCE_AFTER_FIRST_MINT,
            "Equivalence violation: user balance and BALANCE_AFTER_FIRST_MINT."
        );

        // 2. Revoke mint privileges
        IUSXAdmin(address(usx_proxy)).manageTreasuries(TREASURY, false, true);

        // 3. Ensure cannot mint
        vm.expectRevert("Unauthorized.");
        vm.prank(TREASURY);
        IUSX(address(usx_proxy)).mint(address(this), TEST_MINT_AMOUNT);

        // 4. Reinstate mint privileges
        IUSXAdmin(address(usx_proxy)).manageTreasuries(TREASURY, true, true);

        // 5. Ensure can mint again
        vm.expectEmit(true, true, true, true, address(usx_proxy));
        emit Transfer(address(0), address(this), TEST_MINT_AMOUNT);

        vm.prank(TREASURY);
        IUSX(address(usx_proxy)).mint(address(this), TEST_MINT_AMOUNT);

        assertEq(
            IUSX(address(usx_proxy)).totalSupply(),
            BALANCE_AFTER_SECOND_MINT,
            "Equivalence violation: total supply and BALANCE_AFTER_SECOND_MINT."
        );
        assertEq(
            IUSX(address(usx_proxy)).balanceOf(address(this)),
            BALANCE_AFTER_SECOND_MINT,
            "Equivalence violation: user balance and BALANCE_AFTER_SECOND_MINT."
        );
    }

    function test_manageTreasuries_burn_integration(uint256) public {
        // Test Variables
        uint256 BALANCE_AFTER_FIRST_BURN = TEST_MINT_AMOUNT - TEST_BURN_AMOUNT;
        uint256 BALANCE_AFTER_SECOND_BURN = BALANCE_AFTER_FIRST_BURN - TEST_BURN_AMOUNT;

        // 1. Ensure can burn
        vm.prank(TREASURY);
        IUSX(address(usx_proxy)).mint(address(this), TEST_MINT_AMOUNT);

        vm.expectEmit(true, true, true, true, address(usx_proxy));
        emit Transfer(address(this), address(0), TEST_BURN_AMOUNT);

        vm.prank(TREASURY);
        IUSX(address(usx_proxy)).burn(address(this), TEST_BURN_AMOUNT);

        assertEq(
            IUSX(address(usx_proxy)).totalSupply(),
            BALANCE_AFTER_FIRST_BURN,
            "Equivalence violation: total supply and BALANCE_AFTER_FIRST_BURN."
        );
        assertEq(
            IUSX(address(usx_proxy)).balanceOf(address(this)),
            BALANCE_AFTER_FIRST_BURN,
            "Equivalence violation: user balance and BALANCE_AFTER_FIRST_BURN."
        );

        // 2. Revoke burn privileges
        IUSXAdmin(address(usx_proxy)).manageTreasuries(TREASURY, true, false);

        // 3. Ensure cannot burn
        vm.expectRevert("Unauthorized.");
        vm.prank(TREASURY);
        IUSX(address(usx_proxy)).burn(address(this), TEST_BURN_AMOUNT);

        // 4. Reinstate burn privileges
        IUSXAdmin(address(usx_proxy)).manageTreasuries(TREASURY, true, true);

        // 5. Ensure can burn again
        vm.expectEmit(true, true, true, true, address(usx_proxy));
        emit Transfer(address(this), address(0), TEST_BURN_AMOUNT);

        vm.prank(TREASURY);
        IUSX(address(usx_proxy)).burn(address(this), TEST_BURN_AMOUNT);

        assertEq(
            IUSX(address(usx_proxy)).totalSupply(),
            BALANCE_AFTER_SECOND_BURN,
            "Equivalence violation: total supply and BALANCE_AFTER_SECOND_BURN."
        );
        assertEq(
            IUSX(address(usx_proxy)).balanceOf(address(this)),
            BALANCE_AFTER_SECOND_BURN,
            "Equivalence violation: user balance and BALANCE_AFTER_SECOND_BURN."
        );
    }
}
