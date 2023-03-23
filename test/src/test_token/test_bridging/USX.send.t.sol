// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "../../../../src/token/USX.sol";

import "../../../../src/common/interfaces/IUSXAdmin.sol";
import "../../../../src/bridging/interfaces/IWormholeBridge.sol";

import "./common/TestSetup.t.sol";
import "../../common/Constants.t.sol";

contract SendTest is BridgingSetup {
    function test_sendFrom_wormhole(uint256 transferAmount, uint256 gasFee) public {
        // Setup
        uint256 iterations = 4;
        vm.assume(transferAmount <= INITIAL_TOKENS / iterations);
        uint256 destGasFee = IWormholeBridge(address(wormhole_bridge_proxy)).sendFeeLookup(TEST_WORMHOLE_CHAIN_ID);
        gasFee = bound(gasFee, destGasFee, 5e16);
        vm.deal(address(wormhole_bridge_proxy), gasFee * iterations);

        uint256 tokenBalance = INITIAL_TOKENS;
        for (uint256 i; i < iterations; i++) {
            // Expectations
            vm.expectEmit(true, true, true, true, address(wormhole_bridge_proxy));
            emit SendToChain(TEST_WORMHOLE_CHAIN_ID, address(this), abi.encode(address(this)), transferAmount);

            // Pre-action Assertions
            assertEq(
                IUSXAdmin(address(usx_proxy)).totalSupply(),
                tokenBalance,
                "Equivalence violation: total supply and initially minted tokens."
            );
            assertEq(
                IUSXAdmin(address(usx_proxy)).balanceOf(address(this)),
                tokenBalance,
                "Equivalence violation: user balance and initially minted tokens."
            );

            // Act: send money using wormhole
            uint64 sequence = IUSXAdmin(address(usx_proxy)).sendFrom{ value: gasFee }(
                address(wormhole_bridge_proxy),
                payable(address(this)),
                TEST_WORMHOLE_CHAIN_ID,
                abi.encode(address(this)),
                transferAmount
            );

            // Post-action Assertions
            assertEq(sequence, i);
            assertEq(
                IUSXAdmin(address(usx_proxy)).totalSupply(),
                tokenBalance - transferAmount,
                "Equivalence violation: total supply must decrease by amount transferred."
            );
            assertEq(
                IUSXAdmin(address(usx_proxy)).balanceOf(address(this)),
                tokenBalance - transferAmount,
                "Equivalence violation: user balance must decrease by amount transferred."
            );
            tokenBalance -= transferAmount;
        }
    }

    function testCannot_sendFrom_wormhole_not_enough_fees(uint256 gasFee, uint256 transferAmount) public {
        // Setup
        uint256 destGasFee = IWormholeBridge(address(wormhole_bridge_proxy)).sendFeeLookup(TEST_WORMHOLE_CHAIN_ID);

        // Assumptions
        vm.assume(transferAmount <= INITIAL_TOKENS);
        vm.assume(gasFee < destGasFee);

        // Expectations
        vm.expectRevert("Not enough native token for gas.");

        // Act: gasFee is less than required destGasFee
        IUSXAdmin(address(usx_proxy)).sendFrom{ value: gasFee }(
            address(wormhole_bridge_proxy),
            payable(address(this)),
            TEST_WORMHOLE_CHAIN_ID,
            abi.encode(address(this)),
            transferAmount
        );
    }

    function test_sendFrom_layerzero(uint256 transferAmount) public {
        // Setup
        uint256 iterations = 4;
        vm.assume(transferAmount <= INITIAL_TOKENS / iterations);

        uint256 tokenBalance = INITIAL_TOKENS;
        for (uint256 i; i < iterations; i++) {
            // Expectations
            vm.expectEmit(true, true, true, true, address(layer_zero_bridge_proxy));
            emit SendToChain(TEST_LZ_CHAIN_ID, address(this), abi.encode(address(this)), transferAmount);

            // Pre-action Assertions
            assertEq(
                IUSXAdmin(address(usx_proxy)).totalSupply(),
                tokenBalance,
                "Equivalence violation: total supply and initially minted tokens."
            );
            assertEq(
                IUSXAdmin(address(usx_proxy)).balanceOf(address(this)),
                tokenBalance,
                "Equivalence violation: user balance and initially minted tokens."
            );

            // Act
            // TODO: Need to reach out to LayerZero and get the actual min fee.
            uint64 sequence = IUSXAdmin(address(usx_proxy)).sendFrom{ value: 0.001 ether }(
                address(layer_zero_bridge_proxy),
                payable(address(this)),
                TEST_LZ_CHAIN_ID,
                abi.encode(address(this)),
                transferAmount
            );

            // Post-action Assertions
            assertEq(sequence, 0); // should stay zero for layer zero
            assertEq(
                IUSXAdmin(address(usx_proxy)).totalSupply(),
                tokenBalance - transferAmount,
                "Equivalence violation: total supply must decrease by amount transferred."
            );
            assertEq(
                IUSXAdmin(address(usx_proxy)).balanceOf(address(this)),
                tokenBalance - transferAmount,
                "Equivalence violation: user balance must decrease by amount transferred."
            );
            tokenBalance -= transferAmount;
        }
    }

    function testCannot_sendFrom_amount(uint256 transferAmount) public {
        // Assumptions
        vm.assume(transferAmount > INITIAL_TOKENS);

        address[2] memory bridges = [address(wormhole_bridge_proxy), address(layer_zero_bridge_proxy)];
        uint16[2] memory chainIds = [TEST_WORMHOLE_CHAIN_ID, TEST_LZ_CHAIN_ID];

        for (uint256 i; i < bridges.length; i++) {
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

        address[2] memory bridges = [address(wormhole_bridge_proxy), address(layer_zero_bridge_proxy)];
        uint16[2] memory chainIds = [TEST_WORMHOLE_CHAIN_ID, TEST_LZ_CHAIN_ID];

        for (uint256 i; i < bridges.length; i++) {
            // Expectation
            vm.expectRevert("ERC20: insufficient allowance.");

            // Act: cannot spend without allowance
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
            [address(wormhole_bridge_proxy), address(layer_zero_bridge_proxy)], [false, false]
        );

        address[2] memory bridges = [address(wormhole_bridge_proxy), address(layer_zero_bridge_proxy)];
        uint16[2] memory chainIds = [TEST_WORMHOLE_CHAIN_ID, TEST_LZ_CHAIN_ID];

        for (uint256 i; i < bridges.length; i++) {
            // Expectations
            vm.expectRevert(IUSXAdmin.Paused.selector);

            // Act: both bridges are paused
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
        address[2] memory bridges = [address(wormhole_bridge_proxy), address(layer_zero_bridge_proxy)];
        uint16[2] memory chainIds = [TEST_WORMHOLE_CHAIN_ID, TEST_LZ_CHAIN_ID];
        bool[2] memory privileges = [true, true];

        // Iterate through privileges, each time revoking privileges for only one bridge
        for (uint256 pausedIndex; pausedIndex < privileges.length; pausedIndex++) {
            privileges = [true, true];
            privileges[pausedIndex] = false;

            IUSXAdmin(address(usx_proxy)).manageCrossChainTransfers(
                [address(wormhole_bridge_proxy), address(layer_zero_bridge_proxy)], privileges
            );

            for (uint256 i; i < bridges.length; i++) {
                if (i == pausedIndex) {
                    // Expectation: transfer should fail because bridge is paused
                    vm.expectRevert(IUSXAdmin.Paused.selector);

                    // Act: paused
                    IUSXAdmin(address(usx_proxy)).sendFrom{ value: TEST_GAS_FEE }(
                        bridges[i], payable(address(this)), chainIds[i], abi.encode(address(this)), transferAmount
                    );
                } else {
                    // Act: not paused
                    IUSXAdmin(address(usx_proxy)).sendFrom{ value: TEST_GAS_FEE }(
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
