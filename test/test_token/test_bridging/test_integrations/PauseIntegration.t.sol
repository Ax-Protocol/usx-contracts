// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "forge-std/Test.sol";
import "./../common/TestHelpers.t.sol";
import "../../../../src/token/USX.sol";

import "../../../../src/common/interfaces/IUSXAdmin.sol";

import "../../../common/Constants.t.sol";

contract PauseIntegrationTest is Test, BridgingSetup {
    /// @dev Integration tests.

    function test_pause_wormhole_integration(uint256 transferAmount) public {
        vm.assume(transferAmount > 0 && transferAmount <= INITIAL_TOKENS / 2);

        // Test Variables
        uint256 BALANCE_AFTER_FIRST_TRANSFER = INITIAL_TOKENS - transferAmount;
        uint256 BALANCE_AFTER_SECOND_TRANSFER = BALANCE_AFTER_FIRST_TRANSFER - transferAmount;

        // 1. Ensure Wormhole transfers work
        vm.expectEmit(true, true, true, true, address(wormhole_bridge));
        emit SendToChain(TEST_WORM_CHAIN_ID, address(this), abi.encode(address(this)), transferAmount);

        IUSXAdmin(address(usx_proxy)).sendFrom{value: 0.005 ether}(
            address(wormhole_bridge),
            payable(address(this)),
            TEST_WORM_CHAIN_ID,
            abi.encode(address(this)),
            transferAmount
        );

        assertEq(
            IUSXAdmin(address(usx_proxy)).totalSupply(),
            BALANCE_AFTER_FIRST_TRANSFER,
            "Equivalence violation: total supply and BALANCE_AFTER_FIRST_TRANSFER (WH)."
        );
        assertEq(
            IUSXAdmin(address(usx_proxy)).balanceOf(address(this)),
            BALANCE_AFTER_FIRST_TRANSFER,
            "Equivalence violation: sender balance and BALANCE_AFTER_FIRST_TRANSFER (WH)."
        );

        // 2. Pause
        IUSXAdmin(address(usx_proxy)).manageCrossChainTransfers(
            [address(wormhole_bridge), address(layer_zero_bridge)], [false, true]
        );

        // 3. Ensure Wormhole transfers are disabled
        vm.expectRevert(IUSXAdmin.Paused.selector);

        IUSXAdmin(address(usx_proxy)).sendFrom{value: 0.005 ether}(
            address(wormhole_bridge),
            payable(address(this)),
            TEST_WORM_CHAIN_ID,
            abi.encode(address(this)),
            transferAmount
        );

        // 4. Ensure Layer Zero transfers still work
        uint256 id = vm.snapshot();
        IUSXAdmin(address(usx_proxy)).sendFrom{value: 0.005 ether}(
            address(layer_zero_bridge),
            payable(address(this)),
            TEST_LZ_CHAIN_ID,
            abi.encode(address(this)),
            transferAmount
        );

        assertEq(
            IUSXAdmin(address(usx_proxy)).totalSupply(),
            BALANCE_AFTER_SECOND_TRANSFER,
            "Equivalence violation: total supply and BALANCE_AFTER_SECOND_TRANSFER (LZ)."
        );
        assertEq(
            IUSXAdmin(address(usx_proxy)).balanceOf(address(this)),
            BALANCE_AFTER_SECOND_TRANSFER,
            "Equivalence violation: sender balance and BALANCE_AFTER_SECOND_TRANSFER (LZ)."
        );
        vm.revertTo(id);

        // 5. Unpause
        IUSXAdmin(address(usx_proxy)).manageCrossChainTransfers(
            [address(wormhole_bridge), address(layer_zero_bridge)], [true, true]
        );

        // 6. Ensure cross-chain transfers work again
        vm.expectEmit(true, true, true, true, address(wormhole_bridge));
        emit SendToChain(TEST_WORM_CHAIN_ID, address(this), abi.encode(address(this)), transferAmount);

        IUSXAdmin(address(usx_proxy)).sendFrom{value: 0.005 ether}(
            address(wormhole_bridge),
            payable(address(this)),
            TEST_WORM_CHAIN_ID,
            abi.encode(address(this)),
            transferAmount
        );

        assertEq(
            IUSXAdmin(address(usx_proxy)).totalSupply(),
            BALANCE_AFTER_SECOND_TRANSFER,
            "Equivalence violation: total supply and BALANCE_AFTER_SECOND_TRANSFER (WH)."
        );
        assertEq(
            IUSXAdmin(address(usx_proxy)).balanceOf(address(this)),
            BALANCE_AFTER_SECOND_TRANSFER,
            "Equivalence violation: sender balance and BALANCE_AFTER_SECOND_TRANSFER (WH)."
        );
    }

    function test_pause_layer_zero_integration(uint256 transferAmount) public {
        vm.assume(transferAmount > 0 && transferAmount <= INITIAL_TOKENS / 2);

        // Test Variables
        uint256 BALANCE_AFTER_FIRST_TRANSFER = INITIAL_TOKENS - transferAmount;
        uint256 BALANCE_AFTER_SECOND_TRANSFER = BALANCE_AFTER_FIRST_TRANSFER - transferAmount;

        // 1. Ensure cross-chain transfers work
        vm.expectEmit(true, true, true, true, address(layer_zero_bridge));
        emit SendToChain(TEST_LZ_CHAIN_ID, address(this), abi.encode(address(this)), transferAmount);

        IUSXAdmin(address(usx_proxy)).sendFrom{value: 0.005 ether}(
            address(layer_zero_bridge),
            payable(address(this)),
            TEST_LZ_CHAIN_ID,
            abi.encode(address(this)),
            transferAmount
        );

        assertEq(
            IUSXAdmin(address(usx_proxy)).totalSupply(),
            BALANCE_AFTER_FIRST_TRANSFER,
            "Equivalence violation: total supply and BALANCE_AFTER_FIRST_TRANSFER (LZ)."
        );
        assertEq(
            IUSXAdmin(address(usx_proxy)).balanceOf(address(this)),
            BALANCE_AFTER_FIRST_TRANSFER,
            "Equivalence violation: sender balance and BALANCE_AFTER_FIRST_TRANSFER (LZ)."
        );

        // 2. Pause
        IUSXAdmin(address(usx_proxy)).manageCrossChainTransfers(
            [address(wormhole_bridge), address(layer_zero_bridge)], [true, false]
        );

        // 3. Ensure Layer Zero transfers are disabled
        vm.expectRevert(IUSXAdmin.Paused.selector);

        IUSXAdmin(address(usx_proxy)).sendFrom{value: 0.005 ether}(
            address(layer_zero_bridge),
            payable(address(this)),
            TEST_LZ_CHAIN_ID,
            abi.encode(address(this)),
            transferAmount
        );

        // 4. Ensure Wormhole transfers still work
        uint256 id = vm.snapshot();
        IUSXAdmin(address(usx_proxy)).sendFrom{value: 0.005 ether}(
            address(wormhole_bridge),
            payable(address(this)),
            TEST_WORM_CHAIN_ID,
            abi.encode(address(this)),
            transferAmount
        );

        assertEq(
            IUSXAdmin(address(usx_proxy)).totalSupply(),
            BALANCE_AFTER_SECOND_TRANSFER,
            "Equivalence violation: total supply and BALANCE_AFTER_SECOND_TRANSFER (WH)."
        );
        assertEq(
            IUSXAdmin(address(usx_proxy)).balanceOf(address(this)),
            BALANCE_AFTER_SECOND_TRANSFER,
            "Equivalence violation: sender balance and BALANCE_AFTER_SECOND_TRANSFER (WH)."
        );
        vm.revertTo(id);

        // 5. Unpause
        IUSXAdmin(address(usx_proxy)).manageCrossChainTransfers(
            [address(wormhole_bridge), address(layer_zero_bridge)], [true, true]
        );

        // 6. Ensure Layer Zero transfers work again
        vm.expectEmit(true, true, true, true, address(layer_zero_bridge));
        emit SendToChain(TEST_LZ_CHAIN_ID, address(this), abi.encode(address(this)), transferAmount);

        IUSXAdmin(address(usx_proxy)).sendFrom{value: 0.005 ether}(
            address(layer_zero_bridge),
            payable(address(this)),
            TEST_LZ_CHAIN_ID,
            abi.encode(address(this)),
            transferAmount
        );

        assertEq(
            IUSXAdmin(address(usx_proxy)).totalSupply(),
            BALANCE_AFTER_SECOND_TRANSFER,
            "Equivalence violation: total supply and BALANCE_AFTER_SECOND_TRANSFER (LZ)."
        );
        assertEq(
            IUSXAdmin(address(usx_proxy)).balanceOf(address(this)),
            BALANCE_AFTER_SECOND_TRANSFER,
            "Equivalence violation: sender balance and BALANCE_AFTER_SECOND_TRANSFER (LZ)."
        );
    }

    function test_pause_all_integration(uint256 transferAmount) public {
        vm.assume(transferAmount > 0 && transferAmount <= INITIAL_TOKENS / 2);
        // Test Variables
        uint256 BALANCE_AFTER_FIRST_TRANSFER = INITIAL_TOKENS - transferAmount;
        uint256 BALANCE_AFTER_SECOND_TRANSFER = BALANCE_AFTER_FIRST_TRANSFER - transferAmount;

        // 1. Ensure all messaging protocols' transfers work
        // Expectation
        vm.expectEmit(true, true, true, true, address(layer_zero_bridge));
        emit SendToChain(TEST_LZ_CHAIN_ID, address(this), abi.encode(address(this)), transferAmount);

        uint256 id_1 = vm.snapshot();
        IUSXAdmin(address(usx_proxy)).sendFrom{value: 0.005 ether}(
            address(layer_zero_bridge),
            payable(address(this)),
            TEST_LZ_CHAIN_ID,
            abi.encode(address(this)),
            transferAmount
        );

        assertEq(
            IUSXAdmin(address(usx_proxy)).totalSupply(),
            BALANCE_AFTER_FIRST_TRANSFER,
            "Equivalence violation: total supply and BALANCE_AFTER_FIRST_TRANSFER (LZ)."
        );
        assertEq(
            IUSXAdmin(address(usx_proxy)).balanceOf(address(this)),
            BALANCE_AFTER_FIRST_TRANSFER,
            "Equivalence violation: sender balance and BALANCE_AFTER_FIRST_TRANSFER (LZ)."
        );
        vm.revertTo(id_1);

        // Expectation
        vm.expectEmit(true, true, true, true, address(wormhole_bridge));
        emit SendToChain(TEST_WORM_CHAIN_ID, address(this), abi.encode(address(this)), transferAmount);

        IUSXAdmin(address(usx_proxy)).sendFrom{value: 0.005 ether}(
            address(wormhole_bridge),
            payable(address(this)),
            TEST_WORM_CHAIN_ID,
            abi.encode(address(this)),
            transferAmount
        );

        assertEq(
            IUSXAdmin(address(usx_proxy)).totalSupply(),
            BALANCE_AFTER_FIRST_TRANSFER,
            "Equivalence violation: total supply and BALANCE_AFTER_FIRST_TRANSFER (WH)."
        );
        assertEq(
            IUSXAdmin(address(usx_proxy)).balanceOf(address(this)),
            BALANCE_AFTER_FIRST_TRANSFER,
            "Equivalence violation: total supply and BALANCE_AFTER_FIRST_TRANSFER (WH)."
        );

        // 2. Pause
        IUSXAdmin(address(usx_proxy)).manageCrossChainTransfers(
            [address(wormhole_bridge), address(layer_zero_bridge)], [false, false]
        );

        // 3. Ensure all messaging protocols' transfers are disabled
        vm.expectRevert(IUSXAdmin.Paused.selector);

        IUSXAdmin(address(usx_proxy)).sendFrom{value: 0.005 ether}(
            address(layer_zero_bridge),
            payable(address(this)),
            TEST_LZ_CHAIN_ID,
            abi.encode(address(this)),
            transferAmount
        );

        vm.expectRevert(IUSXAdmin.Paused.selector);

        IUSXAdmin(address(usx_proxy)).sendFrom{value: 0.005 ether}(
            address(wormhole_bridge),
            payable(address(this)),
            TEST_WORM_CHAIN_ID,
            abi.encode(address(this)),
            transferAmount
        );

        // 4. Unpause
        IUSXAdmin(address(usx_proxy)).manageCrossChainTransfers(
            [address(wormhole_bridge), address(layer_zero_bridge)], [true, true]
        );

        // 5. Ensure all messaging protocols' transfers work again
        vm.expectEmit(true, true, true, true, address(layer_zero_bridge));
        emit SendToChain(TEST_LZ_CHAIN_ID, address(this), abi.encode(address(this)), transferAmount);

        uint256 id_2 = vm.snapshot();
        IUSXAdmin(address(usx_proxy)).sendFrom{value: 0.005 ether}(
            address(layer_zero_bridge),
            payable(address(this)),
            TEST_LZ_CHAIN_ID,
            abi.encode(address(this)),
            transferAmount
        );

        assertEq(
            IUSXAdmin(address(usx_proxy)).totalSupply(),
            BALANCE_AFTER_SECOND_TRANSFER,
            "Equivalence violation: total supply and BALANCE_AFTER_SECOND_TRANSFER (LZ)."
        );
        assertEq(
            IUSXAdmin(address(usx_proxy)).balanceOf(address(this)),
            BALANCE_AFTER_SECOND_TRANSFER,
            "Equivalence violation: sender balance and BALANCE_AFTER_SECOND_TRANSFER (LZ)."
        );
        vm.revertTo(id_2);

        vm.expectEmit(true, true, true, true, address(wormhole_bridge));
        emit SendToChain(TEST_WORM_CHAIN_ID, address(this), abi.encode(address(this)), transferAmount);

        IUSXAdmin(address(usx_proxy)).sendFrom{value: 0.005 ether}(
            address(wormhole_bridge),
            payable(address(this)),
            TEST_WORM_CHAIN_ID,
            abi.encode(address(this)),
            transferAmount
        );

        assertEq(
            IUSXAdmin(address(usx_proxy)).totalSupply(),
            BALANCE_AFTER_SECOND_TRANSFER,
            "Equivalence violation: total supply and BALANCE_AFTER_SECOND_TRANSFER (WM)."
        );
        assertEq(
            IUSXAdmin(address(usx_proxy)).balanceOf(address(this)),
            BALANCE_AFTER_SECOND_TRANSFER,
            "Equivalence violation: sender balance and BALANCE_AFTER_SECOND_TRANSFER (WM)."
        );
    }
}
