// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "../../../../src/token/USX.sol";

import "../../../../src/common/interfaces/IUSXAdmin.sol";

import "./common/TestSetup.t.sol";
import "../../common/Constants.t.sol";

contract AdminTest is BridgingSetup, TestUtils {
    function testCannot_manageCrossChainTransfers_unauthorized() public {
        bool[2][4] memory trials = [[true, true], [true, false], [false, true], [false, false]];

        for (uint256 i; i < trials.length; i++) {
            // Expectations
            vm.expectRevert("Ownable: caller is not the owner");

            // Act: attempt unauthorized privilege update
            vm.prank(TEST_ADDRESS);
            IUSXAdmin(address(usx_proxy)).manageCrossChainTransfers(
                [address(wormhole_bridge_proxy), address(layer_zero_bridge_proxy)], trials[i]
            );
        }
    }

    function test_manageCrossChainTransfers_pause_both() public {
        // Pre-action assertions
        assertEq(
            IUSXAdmin(address(usx_proxy)).transferPrivileges(address(wormhole_bridge_proxy)),
            true,
            "Privilege failed: Wormhole."
        );
        assertEq(
            IUSXAdmin(address(usx_proxy)).transferPrivileges(address(layer_zero_bridge_proxy)),
            true,
            "Privilege failed: Layer Zero."
        );

        // Act: pause
        IUSXAdmin(address(usx_proxy)).manageCrossChainTransfers(
            [address(wormhole_bridge_proxy), address(layer_zero_bridge_proxy)], [false, false]
        );

        // Post-action assertions
        assertEq(
            IUSXAdmin(address(usx_proxy)).transferPrivileges(address(wormhole_bridge_proxy)),
            false,
            "Pause failed: Wormhole."
        );
        assertEq(
            IUSXAdmin(address(usx_proxy)).transferPrivileges(address(layer_zero_bridge_proxy)),
            false,
            "Pause failed: Layer Zero."
        );
    }

    function test_manageCrossChainTransfers_unpause_both() public {
        // Setup
        IUSXAdmin(address(usx_proxy)).manageCrossChainTransfers(
            [address(wormhole_bridge_proxy), address(layer_zero_bridge_proxy)], [false, false]
        );
        assertEq(
            IUSXAdmin(address(usx_proxy)).transferPrivileges(address(wormhole_bridge_proxy)),
            false,
            "Pause failed: Wormhole."
        );
        assertEq(
            IUSXAdmin(address(usx_proxy)).transferPrivileges(address(layer_zero_bridge_proxy)),
            false,
            "Pause failed: Layer Zero."
        );

        // Act: unpause
        IUSXAdmin(address(usx_proxy)).manageCrossChainTransfers(
            [address(wormhole_bridge_proxy), address(layer_zero_bridge_proxy)], [true, true]
        );

        // Post-action assertions
        assertEq(
            IUSXAdmin(address(usx_proxy)).transferPrivileges(address(wormhole_bridge_proxy)),
            true,
            "Unpaused failed: Wormhole."
        );
        assertEq(
            IUSXAdmin(address(usx_proxy)).transferPrivileges(address(layer_zero_bridge_proxy)),
            true,
            "Unpaused failed: Layer Zero."
        );
    }

    /// @dev Test that each bridge can be singularly paused
    function test_manageCrossChainTransfers_pause_one() public {
        uint256 id = vm.snapshot();
        address[2] memory bridgeContracts = [address(wormhole_bridge_proxy), address(layer_zero_bridge_proxy)];
        bool[2] memory privileges = [true, true];

        // Iterate through privileges, each time revoking privileges for only one bridge
        for (uint256 pausedIndex; pausedIndex < privileges.length; pausedIndex++) {
            // Pre-action assertions
            assertEq(
                IUSXAdmin(address(usx_proxy)).transferPrivileges(address(wormhole_bridge_proxy)),
                true,
                "Privilege failed: Wormhole."
            );
            assertEq(
                IUSXAdmin(address(usx_proxy)).transferPrivileges(address(layer_zero_bridge_proxy)),
                true,
                "Privilege failed: Layer Zero."
            );

            privileges = [true, true];
            privileges[pausedIndex] = false;

            // Act: pause
            IUSXAdmin(address(usx_proxy)).manageCrossChainTransfers(
                [address(wormhole_bridge_proxy), address(layer_zero_bridge_proxy)], privileges
            );

            // Given this iteration's privilege settings, iterate through both bridges to ensure privileges are active
            for (uint256 i; i < bridgeContracts.length; i++) {
                if (i == pausedIndex) {
                    assertEq(
                        IUSXAdmin(address(usx_proxy)).transferPrivileges(bridgeContracts[i]), false, "Pause failed."
                    );
                } else {
                    assertEq(
                        IUSXAdmin(address(usx_proxy)).transferPrivileges(bridgeContracts[i]), true, "Privilege failed."
                    );
                }
            }
            // Revert chain state, such that each iteration is state-independent
            vm.revertTo(id);
        }
    }

    function testCannot_manageRoutes_LayerZero(uint256 transferAmount) public {
        // Setup
        vm.assume(transferAmount <= INITIAL_TOKENS / LZ_TEST_CHAIN_IDS.length);
        uint256 tokenBalance = INITIAL_TOKENS;

        IUSXAdmin(address(usx_proxy)).manageRoutes(
            address(layer_zero_bridge_proxy), LZ_TEST_CHAIN_IDS, LZ_TEST_PRIVILEGES
        );

        // Pre-action Assertions
        for (uint256 i; i < LZ_TEST_CHAIN_IDS.length; i++) {
            ILayerZeroBridge(address(layer_zero_bridge_proxy)).setTrustedRemote(
                LZ_TEST_CHAIN_IDS[i],
                abi.encodePacked(address(layer_zero_bridge_proxy), address(layer_zero_bridge_proxy))
            );
            vm.expectEmit(true, true, true, true, address(layer_zero_bridge_proxy));
            emit SendToChain(LZ_TEST_CHAIN_IDS[i], address(this), abi.encode(address(this)), transferAmount);

            assertEq(
                IUSXAdmin(address(usx_proxy)).routes(address(layer_zero_bridge_proxy), LZ_TEST_CHAIN_IDS[i]),
                true,
                "Equivalence violation: LZ_TEST_CHAIN_IDS[i] is not initially true"
            );
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

            uint64 sequence = IUSXAdmin(address(usx_proxy)).sendFrom{ value: TEST_GAS_FEE }(
                address(layer_zero_bridge_proxy),
                payable(address(this)),
                LZ_TEST_CHAIN_IDS[i],
                abi.encode(address(this)),
                transferAmount
            );

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

        for (uint256 i; i < LZ_TEST_CHAIN_IDS.length; i++) {
            // Act
            LZ_TEST_PRIVILEGES[i] = false;
            IUSXAdmin(address(usx_proxy)).manageRoutes(
                address(layer_zero_bridge_proxy), LZ_TEST_CHAIN_IDS, LZ_TEST_PRIVILEGES
            );

            // Post-action assertions
            assertEq(
                IUSXAdmin(address(usx_proxy)).routes(address(layer_zero_bridge_proxy), LZ_TEST_CHAIN_IDS[i]),
                false,
                "Equivalence violation: LZ_TEST_CHAIN_IDS[i] was not updated to false"
            );

            vm.expectRevert(IUSXAdmin.Paused.selector);

            IUSXAdmin(address(usx_proxy)).sendFrom{ value: TEST_GAS_FEE }(
                address(layer_zero_bridge_proxy),
                payable(address(this)),
                LZ_TEST_CHAIN_IDS[i],
                abi.encode(address(this)),
                transferAmount
            );
        }
    }

    function testCannot_manageRoutes_Wormhole(uint256 transferAmount, uint256 gasFee) public {
        // Setup
        vm.assume(transferAmount <= INITIAL_TOKENS / WH_TEST_CHAIN_IDS.length);

        uint256 tokenBalance = INITIAL_TOKENS;

        IUSXAdmin(address(usx_proxy)).manageRoutes(
            address(wormhole_bridge_proxy), WH_TEST_CHAIN_IDS, WH_TEST_PRIVILEGES
        );

        // Pre-action Assertions
        for (uint256 i; i < WH_TEST_CHAIN_IDS.length; i++) {
            uint256 destGasFee = IWormholeBridge(address(wormhole_bridge_proxy)).sendFeeLookup(WH_TEST_CHAIN_IDS[i]);
            gasFee = bound(gasFee, destGasFee, 5e16);

            vm.expectEmit(true, true, true, true, address(wormhole_bridge_proxy));
            emit SendToChain(WH_TEST_CHAIN_IDS[i], address(this), abi.encode(address(this)), transferAmount);

            assertEq(
                IUSXAdmin(address(usx_proxy)).routes(address(wormhole_bridge_proxy), WH_TEST_CHAIN_IDS[i]),
                true,
                "Equivalence violation: WH_TEST_CHAIN_IDS[i] is not initially true"
            );
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

            uint64 sequence = IUSXAdmin(address(usx_proxy)).sendFrom{ value: gasFee }(
                address(wormhole_bridge_proxy),
                payable(address(this)),
                WH_TEST_CHAIN_IDS[i],
                abi.encode(address(this)),
                transferAmount
            );

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

        for (uint256 i; i < WH_TEST_CHAIN_IDS.length; i++) {
            // Act
            WH_TEST_PRIVILEGES[i] = false;
            IUSXAdmin(address(usx_proxy)).manageRoutes(
                address(wormhole_bridge_proxy), WH_TEST_CHAIN_IDS, WH_TEST_PRIVILEGES
            );

            // Post-action assertions
            assertEq(
                IUSXAdmin(address(usx_proxy)).routes(address(wormhole_bridge_proxy), WH_TEST_CHAIN_IDS[i]),
                false,
                "Equivalence violation: WH_TEST_CHAIN_IDS[i] was not updated to false"
            );

            vm.expectRevert(IUSXAdmin.Paused.selector);

            IUSXAdmin(address(usx_proxy)).sendFrom{ value: gasFee }(
                address(wormhole_bridge_proxy),
                payable(address(this)),
                WH_TEST_CHAIN_IDS[i],
                abi.encode(address(this)),
                transferAmount
            );
        }
    }

    function testCannot_manageRoutes_arrays_length() public {
        // Setup
        uint16[] memory dstChainIds = new uint16[](2);
        dstChainIds[0] = 4; // BSC
        dstChainIds[1] = 5; // Polygon

        bool[] memory privileges = new bool[](1);
        privileges[0] = true;

        // Expectations
        vm.expectRevert("Arrays must be equal length.");

        // Act
        IUSXAdmin(address(usx_proxy)).manageRoutes(address(wormhole_bridge_proxy), dstChainIds, privileges);
    }

    function testCannot_manageRoutes_unauthorized(address sender) public {
        // Setup
        vm.assume(sender != address(this));

        // Exptectations
        vm.expectRevert("Ownable: caller is not the owner");

        // Act
        vm.prank(sender);
        IUSXAdmin(address(usx_proxy)).manageRoutes(
            address(wormhole_bridge_proxy), WH_TEST_CHAIN_IDS, WH_TEST_PRIVILEGES
        );
    }
}
