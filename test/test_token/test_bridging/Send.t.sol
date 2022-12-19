// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "forge-std/Test.sol";
import "../../../src/token/USX.sol";
import "./common/TestHelpers.t.sol";

import "../../../src/common/interfaces/IUSXAdmin.sol";

import "../../common/Constants.t.sol";

import "forge-std/console.sol";

contract SendTest is Test, BridgingSetup {
    function test_sendFrom_wormhole(uint256 transferAmount) public {
        // Setup
        vm.assume(transferAmount <= INITIAL_TOKENS);

        // Expectations
        vm.expectEmit(true, true, true, true, address(wormhole_bridge));
        emit SendToChain(TEST_WORM_CHAIN_ID, address(this), abi.encode(address(this)), transferAmount);

        // Pre-action Assertions
        assertEq(
            IUSXAdmin(address(usx_proxy)).totalSupply(),
            INITIAL_TOKENS,
            "Equivalence violation: total supply and initially minted tokens."
        );
        assertEq(
            IUSXAdmin(address(usx_proxy)).balanceOf(address(this)),
            INITIAL_TOKENS,
            "Equivalence violation: user balance and initially minted tokens."
        );

        // Act: send money using wormhole
        IUSXAdmin(address(usx_proxy)).sendFrom{value: 0.005 ether}(
            address(wormhole_bridge),
            payable(address(this)),
            TEST_WORM_CHAIN_ID,
            abi.encode(address(this)),
            transferAmount
        );

        console.log("totalSupply after:", IUSXAdmin(address(usx_proxy)).totalSupply());
        console.log("user balance:", IUSXAdmin(address(usx_proxy)).balanceOf(address(this)));
        // Post-action Assertions
        assertEq(
            IUSXAdmin(address(usx_proxy)).totalSupply(),
            INITIAL_TOKENS - transferAmount,
            "Equivalence violation: total supply must decrease by amount transferred."
        );
        assertEq(
            IUSXAdmin(address(usx_proxy)).balanceOf(address(this)),
            INITIAL_TOKENS - transferAmount,
            "Equivalence violation: user balance must decrease by amount transferred."
        );
    }

    function test_sendFrom_layerzero(uint256 transferAmount) public {
        // Setup
        vm.assume(transferAmount <= INITIAL_TOKENS);

        // Expectations
        vm.expectEmit(true, true, true, true, address(layer_zero_bridge));
        emit SendToChain(TEST_LZ_CHAIN_ID, address(this), abi.encode(address(this)), transferAmount);

        // Pre-action Assertions
        assertEq(
            IUSXAdmin(address(usx_proxy)).totalSupply(),
            INITIAL_TOKENS,
            "Equivalence violation: total supply and initially minted tokens."
        );
        assertEq(
            IUSXAdmin(address(usx_proxy)).balanceOf(address(this)),
            INITIAL_TOKENS,
            "Equivalence violation: user balance and initially minted tokens."
        );

        // Act
        IUSXAdmin(address(usx_proxy)).sendFrom{value: 0.0001 ether}(
            address(layer_zero_bridge),
            payable(address(this)),
            TEST_LZ_CHAIN_ID,
            abi.encode(address(this)),
            transferAmount
        );

        // Post-action Assertions
        assertEq(
            IUSXAdmin(address(usx_proxy)).totalSupply(),
            INITIAL_TOKENS - transferAmount,
            "Equivalence violation: total supply must decrease by amount transferred."
        );
        assertEq(
            IUSXAdmin(address(usx_proxy)).balanceOf(address(this)),
            INITIAL_TOKENS - transferAmount,
            "Equivalence violation: user balance must decrease by amount transferred."
        );
    }

    function testCannot_sendFrom_amount(uint256 transferAmount) public {
        // Assumptions
        vm.assume(transferAmount > INITIAL_TOKENS);

        address[2] memory bridges = [address(wormhole_bridge), address(layer_zero_bridge)];
        uint16[2] memory chainIds = [TEST_WORM_CHAIN_ID, TEST_LZ_CHAIN_ID];

        for (uint256 i = 0; i < bridges.length; i++) {
            // Expectation
            vm.expectRevert(stdError.arithmeticError);

            // Act: send more than balance
            IUSXAdmin(address(usx_proxy)).sendFrom(
                bridges[i], payable(address(this)), chainIds[i], abi.encode(address(this)), transferAmount
            );
        }
    }

    function testCannot_sendFrom_from_address(address sender, uint256 transferAmount) public {
        // Assumptions
        vm.assume(sender != address(this));
        vm.assume(transferAmount > 0 && transferAmount <= INITIAL_TOKENS);

        address[2] memory bridges = [address(wormhole_bridge), address(layer_zero_bridge)];
        uint16[2] memory chainIds = [TEST_WORM_CHAIN_ID, TEST_LZ_CHAIN_ID];

        for (uint256 i = 0; i < bridges.length; i++) {
            // Expectation
            vm.expectRevert("ERC20: insufficient allowance");

            // Act: send more than balance
            IUSXAdmin(address(usx_proxy)).sendFrom(
                bridges[i], payable(sender), chainIds[i], abi.encode(address(this)), transferAmount
            );
        }
    }

    function testCannot_sendFrom_paused(uint256 transferAmount) public {
        // Assumptions
        vm.assume(transferAmount > 0 && transferAmount <= INITIAL_TOKENS);

        // Setup
        IUSXAdmin(address(usx_proxy)).manageCrossChainTransfers(
            [address(wormhole_bridge), address(layer_zero_bridge)], [false, false]
        );

        address[2] memory bridges = [address(wormhole_bridge), address(layer_zero_bridge)];
        uint16[2] memory chainIds = [TEST_WORM_CHAIN_ID, TEST_LZ_CHAIN_ID];

        for (uint256 i = 0; i < bridges.length; i++) {
            // Expectations
            vm.expectRevert(IUSXAdmin.Paused.selector);

            // Act: send more than balance
            IUSXAdmin(address(usx_proxy)).sendFrom(
                bridges[i], payable(address(this)), chainIds[i], abi.encode(address(this)), transferAmount
            );
        }
    }

    /// @dev tests that each bridge can be singularly paused, with correct transfer implications
    function test_sendFrom_only_one_paused(uint256 transferAmount) public {
        // Assumptions
        vm.assume(transferAmount > 0 && transferAmount <= INITIAL_TOKENS);

        uint256 id = vm.snapshot();
        address[2] memory bridges = [address(wormhole_bridge), address(layer_zero_bridge)];
        uint16[2] memory chainIds = [TEST_WORM_CHAIN_ID, TEST_LZ_CHAIN_ID];
        bool[2] memory privileges = [true, true];

        // Iterate through privileges, each time revoking privileges for only one bridge
        for (uint256 pausedIndex = 0; pausedIndex < privileges.length; pausedIndex++) {
            privileges = [true, true];
            privileges[pausedIndex] = false;

            IUSXAdmin(address(usx_proxy)).manageCrossChainTransfers(
                [address(wormhole_bridge), address(layer_zero_bridge)], privileges
            );

            for (uint256 i = 0; i < bridges.length; i++) {
                if (i == pausedIndex) {
                    // Expectation: transfer should fail because bridge is paused
                    vm.expectRevert(IUSXAdmin.Paused.selector);

                    // Act: paused
                    IUSXAdmin(address(usx_proxy)).sendFrom(
                        bridges[i], payable(address(this)), chainIds[i], abi.encode(address(this)), transferAmount
                    );
                } else {
                    // Act: not paused
                    IUSXAdmin(address(usx_proxy)).sendFrom(
                        bridges[i], payable(address(this)), chainIds[i], abi.encode(address(this)), transferAmount
                    );

                    // Assertions
                    assertEq(
                        IUSXAdmin(address(usx_proxy)).totalSupply(),
                        INITIAL_TOKENS - transferAmount,
                        "Equivalence violation: total supply must decrease by amount transferred."
                    );
                    assertEq(
                        IUSXAdmin(address(usx_proxy)).balanceOf(address(this)),
                        INITIAL_TOKENS - transferAmount,
                        "Equivalence violation: user balance must decrease by amount transferred."
                    );
                }
            }

            // Revert chain state, such that each iteration is state-independent
            vm.revertTo(id);
        }
    }
}
