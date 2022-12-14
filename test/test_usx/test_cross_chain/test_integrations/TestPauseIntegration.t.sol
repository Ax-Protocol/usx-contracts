// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "forge-std/Test.sol";
import "../../../../src/USX.sol";
import "../../../interfaces/IUSXTest.t.sol";
import "../../../common/Constants.t.sol";
import "./../common/TestHelpers.t.sol";

contract TestPauseIntegration is Test, CrossChainSetup {
    /// @dev Integration tests.

    function test_pause_wormhole_integration(uint256 transferAmount) public {
        vm.assume(transferAmount <= (50 * INITIAL_TOKENS) / 100); // Divide by two
        // Test Variables
        uint256 BALANCE_AFTER_FIRST_TRANSFER = INITIAL_TOKENS - transferAmount;
        uint256 BALANCE_AFTER_SECOND_TRANSFER = BALANCE_AFTER_FIRST_TRANSFER - transferAmount;

        // 1. Ensure Wormhole transfers work
        vm.expectEmit(true, true, true, true, address(usx_proxy));
        emit SendToChain(TEST_CHAIN_ID, address(this), abi.encode(address(this)), transferAmount);

        IUSXTest(address(usx_proxy)).sendFrom(
            uint8(BridgingProtocols.WORMHOLE),
            address(this),
            TEST_CHAIN_ID,
            abi.encode(address(this)),
            transferAmount,
            payable(address(this))
        );

        assertEq(
            IUSXTest(address(usx_proxy)).totalSupply(),
            BALANCE_AFTER_FIRST_TRANSFER,
            "Equivalence violation: total supply and BALANCE_AFTER_FIRST_TRANSFER (WH)."
        );
        assertEq(
            IUSXTest(address(usx_proxy)).balanceOf(address(this)),
            BALANCE_AFTER_FIRST_TRANSFER,
            "Equivalence violation: sender balance and BALANCE_AFTER_FIRST_TRANSFER (WH)."
        );

        // 2. Pause
        IUSXTest(address(usx_proxy)).manageCrossChainTransfers(
            [BridgingProtocols.WORMHOLE, BridgingProtocols.LAYER_ZERO], [false, true]
        );

        // 3. Ensure Wormhole transfers are disabled
        vm.expectRevert(IUSXTest.Paused.selector);

        IUSXTest(address(usx_proxy)).sendFrom(
            uint8(BridgingProtocols.WORMHOLE),
            address(this),
            TEST_CHAIN_ID,
            abi.encode(address(this)),
            transferAmount,
            payable(address(this))
        );

        // 4. Ensure Layer Zero transfers still work
        uint256 id = vm.snapshot();
        IUSXTest(address(usx_proxy)).sendFrom(
            uint8(BridgingProtocols.LAYER_ZERO),
            address(this),
            TEST_CHAIN_ID,
            abi.encode(address(this)),
            transferAmount,
            payable(address(this))
        );

        assertEq(
            IUSXTest(address(usx_proxy)).totalSupply(),
            BALANCE_AFTER_SECOND_TRANSFER,
            "Equivalence violation: total supply and BALANCE_AFTER_SECOND_TRANSFER (LZ)."
        );
        assertEq(
            IUSXTest(address(usx_proxy)).balanceOf(address(this)),
            BALANCE_AFTER_SECOND_TRANSFER,
            "Equivalence violation: sender balance and BALANCE_AFTER_SECOND_TRANSFER (LZ)."
        );
        vm.revertTo(id);

        // 5. Unpause
        IUSXTest(address(usx_proxy)).manageCrossChainTransfers(
            [BridgingProtocols.WORMHOLE, BridgingProtocols.LAYER_ZERO], [true, true]
        );

        // 6. Ensure cross-chain transfers work again
        vm.expectEmit(true, true, true, true, address(usx_proxy));
        emit SendToChain(TEST_CHAIN_ID, address(this), abi.encode(address(this)), transferAmount);

        IUSXTest(address(usx_proxy)).sendFrom(
            uint8(BridgingProtocols.WORMHOLE),
            address(this),
            TEST_CHAIN_ID,
            abi.encode(address(this)),
            transferAmount,
            payable(address(this))
        );

        assertEq(
            IUSXTest(address(usx_proxy)).totalSupply(),
            BALANCE_AFTER_SECOND_TRANSFER,
            "Equivalence violation: total supply and BALANCE_AFTER_SECOND_TRANSFER (WH)."
        );
        assertEq(
            IUSXTest(address(usx_proxy)).balanceOf(address(this)),
            BALANCE_AFTER_SECOND_TRANSFER,
            "Equivalence violation: sender balance and BALANCE_AFTER_SECOND_TRANSFER (WH)."
        );
    }

    function test_pause_layer_zero_integration(uint256 transferAmount) public {
        vm.assume(transferAmount <= (50 * INITIAL_TOKENS) / 100); // Divide by two
        // Test Variables
        uint256 BALANCE_AFTER_FIRST_TRANSFER = INITIAL_TOKENS - transferAmount;
        uint256 BALANCE_AFTER_SECOND_TRANSFER = BALANCE_AFTER_FIRST_TRANSFER - transferAmount;

        // 1. Ensure cross-chain transfers work
        vm.expectEmit(true, true, true, true, address(usx_proxy));
        emit SendToChain(TEST_CHAIN_ID, address(this), abi.encode(address(this)), transferAmount);

        IUSXTest(address(usx_proxy)).sendFrom(
            uint8(BridgingProtocols.LAYER_ZERO),
            address(this),
            TEST_CHAIN_ID,
            abi.encode(address(this)),
            transferAmount,
            payable(address(this))
        );

        assertEq(
            IUSXTest(address(usx_proxy)).totalSupply(),
            BALANCE_AFTER_FIRST_TRANSFER,
            "Equivalence violation: total supply and BALANCE_AFTER_FIRST_TRANSFER (LZ)."
        );
        assertEq(
            IUSXTest(address(usx_proxy)).balanceOf(address(this)),
            BALANCE_AFTER_FIRST_TRANSFER,
            "Equivalence violation: sender balance and BALANCE_AFTER_FIRST_TRANSFER (LZ)."
        );

        // 2. Pause
        IUSXTest(address(usx_proxy)).manageCrossChainTransfers(
            [BridgingProtocols.WORMHOLE, BridgingProtocols.LAYER_ZERO], [true, false]
        );

        // 3. Ensure Layer Zero transfers are disabled
        vm.expectRevert(IUSXTest.Paused.selector);

        IUSXTest(address(usx_proxy)).sendFrom(
            uint8(BridgingProtocols.LAYER_ZERO),
            address(this),
            TEST_CHAIN_ID,
            abi.encode(address(this)),
            transferAmount,
            payable(address(this))
        );

        // 4. Ensure Wormhole transfers still work
        uint256 id = vm.snapshot();
        IUSXTest(address(usx_proxy)).sendFrom(
            uint8(BridgingProtocols.WORMHOLE),
            address(this),
            TEST_CHAIN_ID,
            abi.encode(address(this)),
            transferAmount,
            payable(address(this))
        );

        assertEq(
            IUSXTest(address(usx_proxy)).totalSupply(),
            BALANCE_AFTER_SECOND_TRANSFER,
            "Equivalence violation: total supply and BALANCE_AFTER_SECOND_TRANSFER (WH)."
        );
        assertEq(
            IUSXTest(address(usx_proxy)).balanceOf(address(this)),
            BALANCE_AFTER_SECOND_TRANSFER,
            "Equivalence violation: sender balance and BALANCE_AFTER_SECOND_TRANSFER (WH)."
        );
        vm.revertTo(id);

        // 5. Unpause
        IUSXTest(address(usx_proxy)).manageCrossChainTransfers(
            [BridgingProtocols.WORMHOLE, BridgingProtocols.LAYER_ZERO], [true, true]
        );

        // 6. Ensure Layer Zero transfers work again
        vm.expectEmit(true, true, true, true, address(usx_proxy));
        emit SendToChain(TEST_CHAIN_ID, address(this), abi.encode(address(this)), transferAmount);

        IUSXTest(address(usx_proxy)).sendFrom(
            uint8(BridgingProtocols.LAYER_ZERO),
            address(this),
            TEST_CHAIN_ID,
            abi.encode(address(this)),
            transferAmount,
            payable(address(this))
        );

        assertEq(
            IUSXTest(address(usx_proxy)).totalSupply(),
            BALANCE_AFTER_SECOND_TRANSFER,
            "Equivalence violation: total supply and BALANCE_AFTER_SECOND_TRANSFER (LZ)."
        );
        assertEq(
            IUSXTest(address(usx_proxy)).balanceOf(address(this)),
            BALANCE_AFTER_SECOND_TRANSFER,
            "Equivalence violation: sender balance and BALANCE_AFTER_SECOND_TRANSFER (LZ)."
        );
    }

    function test_pause_all_integration(uint256 transferAmount) public {
        vm.assume(transferAmount <= (50 * INITIAL_TOKENS) / 100); // Divide by two
        // Test Variables
        uint256 BALANCE_AFTER_FIRST_TRANSFER = INITIAL_TOKENS - transferAmount;
        uint256 BALANCE_AFTER_SECOND_TRANSFER = BALANCE_AFTER_FIRST_TRANSFER - transferAmount;

        // 1. Ensure all messaging protocols' transfers work
        vm.expectEmit(true, true, true, true, address(usx_proxy));
        emit SendToChain(TEST_CHAIN_ID, address(this), abi.encode(address(this)), transferAmount);

        uint256 id_1 = vm.snapshot();
        IUSXTest(address(usx_proxy)).sendFrom(
            uint8(BridgingProtocols.LAYER_ZERO),
            address(this),
            TEST_CHAIN_ID,
            abi.encode(address(this)),
            transferAmount,
            payable(address(this))
        );

        assertEq(
            IUSXTest(address(usx_proxy)).totalSupply(),
            BALANCE_AFTER_FIRST_TRANSFER,
            "Equivalence violation: total supply and BALANCE_AFTER_FIRST_TRANSFER (LZ)."
        );
        assertEq(
            IUSXTest(address(usx_proxy)).balanceOf(address(this)),
            BALANCE_AFTER_FIRST_TRANSFER,
            "Equivalence violation: sender balance and BALANCE_AFTER_FIRST_TRANSFER (LZ)."
        );
        vm.revertTo(id_1);

        IUSXTest(address(usx_proxy)).sendFrom(
            uint8(BridgingProtocols.WORMHOLE),
            address(this),
            TEST_CHAIN_ID,
            abi.encode(address(this)),
            transferAmount,
            payable(address(this))
        );

        assertEq(
            IUSXTest(address(usx_proxy)).totalSupply(),
            BALANCE_AFTER_FIRST_TRANSFER,
            "Equivalence violation: total supply and BALANCE_AFTER_FIRST_TRANSFER (WH)."
        );
        assertEq(
            IUSXTest(address(usx_proxy)).balanceOf(address(this)),
            BALANCE_AFTER_FIRST_TRANSFER,
            "Equivalence violation: total supply and BALANCE_AFTER_FIRST_TRANSFER (WH)."
        );

        // 2. Pause
        IUSXTest(address(usx_proxy)).manageCrossChainTransfers(
            [BridgingProtocols.WORMHOLE, BridgingProtocols.LAYER_ZERO], [false, false]
        );

        // 3. Ensure all messaging protocols' transfers are disabled
        vm.expectRevert(IUSXTest.Paused.selector);

        IUSXTest(address(usx_proxy)).sendFrom(
            uint8(BridgingProtocols.LAYER_ZERO),
            address(this),
            TEST_CHAIN_ID,
            abi.encode(address(this)),
            transferAmount,
            payable(address(this))
        );

        vm.expectRevert(IUSXTest.Paused.selector);

        IUSXTest(address(usx_proxy)).sendFrom(
            uint8(BridgingProtocols.WORMHOLE),
            address(this),
            TEST_CHAIN_ID,
            abi.encode(address(this)),
            transferAmount,
            payable(address(this))
        );

        // 4. Unpause
        IUSXTest(address(usx_proxy)).manageCrossChainTransfers(
            [BridgingProtocols.WORMHOLE, BridgingProtocols.LAYER_ZERO], [true, true]
        );

        // 5. Ensure all messaging protocols' transfers work again
        vm.expectEmit(true, true, true, true, address(usx_proxy));
        emit SendToChain(TEST_CHAIN_ID, address(this), abi.encode(address(this)), transferAmount);

        uint256 id_2 = vm.snapshot();
        IUSXTest(address(usx_proxy)).sendFrom(
            uint8(BridgingProtocols.LAYER_ZERO),
            address(this),
            TEST_CHAIN_ID,
            abi.encode(address(this)),
            transferAmount,
            payable(address(this))
        );

        assertEq(
            IUSXTest(address(usx_proxy)).totalSupply(),
            BALANCE_AFTER_SECOND_TRANSFER,
            "Equivalence violation: total supply and BALANCE_AFTER_SECOND_TRANSFER (LZ)."
        );
        assertEq(
            IUSXTest(address(usx_proxy)).balanceOf(address(this)),
            BALANCE_AFTER_SECOND_TRANSFER,
            "Equivalence violation: sender balance and BALANCE_AFTER_SECOND_TRANSFER (LZ)."
        );
        vm.revertTo(id_2);

        IUSXTest(address(usx_proxy)).sendFrom(
            uint8(BridgingProtocols.WORMHOLE),
            address(this),
            TEST_CHAIN_ID,
            abi.encode(address(this)),
            transferAmount,
            payable(address(this))
        );

        assertEq(
            IUSXTest(address(usx_proxy)).totalSupply(),
            BALANCE_AFTER_SECOND_TRANSFER,
            "Equivalence violation: total supply and BALANCE_AFTER_SECOND_TRANSFER (WM)."
        );
        assertEq(
            IUSXTest(address(usx_proxy)).balanceOf(address(this)),
            BALANCE_AFTER_SECOND_TRANSFER,
            "Equivalence violation: sender balance and BALANCE_AFTER_SECOND_TRANSFER (WM)."
        );
    }
}
