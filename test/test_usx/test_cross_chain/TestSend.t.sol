// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "forge-std/Test.sol";
import "../../../src/USX.sol";
import "../../interfaces/IUSXTest.t.sol";
import "../../common/constants.t.sol";
import "./common/TestHelpers.t.sol";

contract TestCrossChainSendFrom is Test, CrossChainSetup {
    function test_sendFrom(uint256 transferAmount) public {
        // Setup
        vm.assume(transferAmount <= INITIAL_TOKENS);

        for (uint8 index = uint8(BridgingProtocols.WORMHOLE); index <= uint8(BridgingProtocols.LAYER_ZERO); index++) {
            // Expectations
            vm.expectEmit(true, true, true, true, address(usx_proxy));
            emit SendToChain(TEST_CHAIN_ID, address(this), abi.encode(address(this)), transferAmount);

            // Pre-action Assertions
            assertEq(
                IUSXTest(address(usx_proxy)).totalSupply(),
                INITIAL_TOKENS,
                "Equivalence violation: total supply and initially minted tokens."
            );
            assertEq(
                IUSXTest(address(usx_proxy)).balanceOf(address(this)),
                INITIAL_TOKENS,
                "Equivalence violation: user balance and initially minted tokens."
            );

            // Act
            uint256 id = vm.snapshot();
            IUSXTest(address(usx_proxy)).sendFrom(
                index, address(this), TEST_CHAIN_ID, abi.encode(address(this)), transferAmount, payable(address(this))
            );

            // Post-action Assertions
            assertEq(
                IUSXTest(address(usx_proxy)).totalSupply(),
                INITIAL_TOKENS - transferAmount,
                "Equivalence violation: total supply must decrease by amount transferred."
            );
            assertEq(
                IUSXTest(address(usx_proxy)).balanceOf(address(this)),
                INITIAL_TOKENS - transferAmount,
                "Equivalence violation: user balance must decrease by amount transferred."
            );

            // Revert to previous state, so subsequent protocols have access to funds to send
            vm.revertTo(id);
        }
    }

    function testCannot_sendFrom_amount() public {
        vm.expectRevert(stdError.arithmeticError);

        // Act
        IUSXTest(address(usx_proxy)).sendFrom(
            0, address(this), TEST_CHAIN_ID, abi.encode(address(this)), INITIAL_TOKENS + 1, payable(address(this))
        );
    }

    function testCannot_sendFrom_from_address() public {
        vm.expectRevert("ERC20: insufficient allowance");

        // Act
        IUSXTest(address(usx_proxy)).sendFrom(
            0, address(0), TEST_CHAIN_ID, abi.encode(address(this)), TEST_TRANSFER_AMOUNT, payable(address(this))
        );
    }

    function testCannot_sendFrom_paused() public {
        // Setup
        IUSXTest(address(usx_proxy)).manageCrossChainTransfers(
            [BridgingProtocols.WORMHOLE, BridgingProtocols.LAYER_ZERO], [false, false]
        );

        for (uint8 index = uint8(BridgingProtocols.WORMHOLE); index <= uint8(BridgingProtocols.LAYER_ZERO); index++) {
            // Expectations
            vm.expectRevert(IUSXTest.Paused.selector);

            // Act
            IUSXTest(address(usx_proxy)).sendFrom(
                index,
                address(this),
                TEST_CHAIN_ID,
                abi.encode(address(this)),
                TEST_TRANSFER_AMOUNT,
                payable(address(this))
            );
        }
    }

    /// @dev tests that each bridge can be singularly paused, with correct transfer implications
    function test_sendFrom_only_one_paused() public {
        uint256 id = vm.snapshot();
        bool[2] memory privileges = [true, true];
        // Iterate through privileges, each time revoking privileges for only one bridge
        for (uint256 pausedIndex = 0; pausedIndex < privileges.length; pausedIndex++) {
            privileges = [true, true];
            privileges[pausedIndex] = false;

            IUSXTest(address(usx_proxy)).manageCrossChainTransfers(
                [BridgingProtocols.WORMHOLE, BridgingProtocols.LAYER_ZERO], privileges
            );

            // Given this iteration's privilege settings, iterate through both bridges to ensure privileges are active
            for (
                uint8 bridgeID = uint8(BridgingProtocols.WORMHOLE);
                bridgeID <= uint8(BridgingProtocols.LAYER_ZERO);
                bridgeID++
            ) {
                if (bridgeID == pausedIndex) {
                    // Expectation: transfer should fail
                    vm.expectRevert(IUSXTest.Paused.selector);
                    IUSXTest(address(usx_proxy)).sendFrom(
                        bridgeID,
                        address(this),
                        TEST_CHAIN_ID,
                        abi.encode(address(this)),
                        TEST_TRANSFER_AMOUNT,
                        payable(address(this))
                    );
                } else {
                    // Expectation: transfer should succeed
                    IUSXTest(address(usx_proxy)).sendFrom(
                        bridgeID,
                        address(this),
                        TEST_CHAIN_ID,
                        abi.encode(address(this)),
                        TEST_TRANSFER_AMOUNT,
                        payable(address(this))
                    );
                }
            }
            // Revert chain state, such that each iteration is state-independent
            vm.revertTo(id);
        }
    }
}
