// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "forge-std/Test.sol";
import "../../../src/USX.sol";
import "../../../src/proxy/ERC1967Proxy.sol";
import "../../../src/interfaces/ILayerZeroEndpoint.sol";
import "../../interfaces/IUSXTest.t.sol";
import "../../mocks/MockLayerZeroEndpoint.t.sol";
import "../../mocks/MockWormholeCoreBridge.t.sol";
import "../../common/constants.t.sol";


import "forge-std/console.sol";

abstract contract SharedSetup is Test {
    // Test Contracts
    USX public usx_implementation;
    ERC1967Proxy public usx_proxy;
    MockLayerZeroEndpoint public mockLayerZeroEndpoint;

    // Test Constants
    uint16 constant TEST_CHAIN_ID = 109;
    address constant TEST_FROM_ADDRESS = 0x7e51587F7edA1b583Fde9b93ED92B289f985fe25;
    address constant TEST_TO_ADDRESS = 0xA72Fb6506f162974dB9B6C702238cfB1Ccc60262;

    // Events
    event ReceiveFromChain(
        uint16 indexed _srcChainId, bytes indexed _srcAddress, address indexed _toAddress, uint256 _amount
    );
    event SendToChain(uint16 indexed _dstChainId, address indexed _from, bytes indexed _toAddress, uint256 _amount);

    function setUp() public {
        // Deploy USX implementation, and link to proxy
        usx_implementation = new USX();
        usx_proxy =
            new ERC1967Proxy(address(usx_implementation), abi.encodeWithSignature("initialize(address,address)", LZ_ENDPOINT, WORMHOLE_CORE_BRIDGE));

        // Set Treasury admin
        IUSXTest(address(usx_proxy)).manageTreasuries(TREASURY, true, true);

        // Mint initial Tokens
        vm.prank(TREASURY);
        IUSXTest(address(usx_proxy)).mint(address(this), INITIAL_TOKENS);

        // Mocks
        mockLayerZeroEndpoint = new MockLayerZeroEndpoint();
        bytes memory mockLayerZeroEndpointCode = address(mockLayerZeroEndpoint).code;
        vm.etch(LZ_ENDPOINT, mockLayerZeroEndpointCode);

        // Set Trusted Remote for LayerZero
        IUSXTest(address(usx_proxy)).setTrustedRemote(
            TEST_CHAIN_ID, abi.encodePacked(address(usx_proxy), address(usx_proxy))
        );

        // Set Trusted Entities for Wormhole
        IUSXTest(address(usx_proxy)).manageTrustedContracts(TRUSTED_EMITTER_ADDRESS, true);
        IUSXTest(address(usx_proxy)).manageTrustedRelayers(TRUSTED_WORMHOLE_RELAYER, true);

        // Grant Transfer privliges
        IUSXTest(address(usx_proxy)).manageCrossChainTransfers([BridgingProtocols.WORMHOLE,BridgingProtocols.LAYER_ZERO], [true,true]);
    }
}

contract TestCrossChainReceive is Test, SharedSetup {
    /// @dev Test Layer Zero message receiving
    function test_lzReceive(uint256 transferAmount) public {
        vm.assume(transferAmount <= INITIAL_TOKENS);
        // Expectations
        vm.expectEmit(true, true, true, true, address(usx_proxy));
        emit ReceiveFromChain(
            TEST_CHAIN_ID, abi.encodePacked(address(usx_proxy), address(usx_proxy)), address(this), transferAmount
            );

        // Pre-action Assertions
        assertEq(IUSXTest(address(usx_proxy)).totalSupply(), INITIAL_TOKENS);
        assertEq(IUSXTest(address(usx_proxy)).balanceOf(address(this)), INITIAL_TOKENS);

        // Act
        vm.prank(LZ_ENDPOINT);
        IUSXTest(address(usx_proxy)).lzReceive(
            TEST_CHAIN_ID,
            abi.encodePacked(address(usx_proxy), address(usx_proxy)),
            1,
            abi.encode(abi.encodePacked(address(this)), transferAmount)
        );

        // Post-action Assertions
        assertEq(IUSXTest(address(usx_proxy)).totalSupply(), INITIAL_TOKENS + transferAmount);
        assertEq(IUSXTest(address(usx_proxy)).balanceOf(address(this)), INITIAL_TOKENS + transferAmount);
    }

    /// @dev Test Wormhole message receiving
    function test_processMessage() public {
        // Setup
        vm.startPrank(TREASURY);
        IUSXTest(address(usx_proxy)).burn(address(this), INITIAL_TOKENS);
        IUSXTest(address(usx_proxy)).mint(TEST_USER, INITIAL_TOKENS);
        vm.stopPrank();

        // Mocks
        bytes memory mockWormholeCoreBridgeCode = address(new MockWormholeCoreBridge()).code;
        vm.etch(WORMHOLE_CORE_BRIDGE, mockWormholeCoreBridgeCode);
        
        // Expectations
        vm.expectEmit(true, true, true, true, address(usx_proxy));
        emit ReceiveFromChain(
            TEST_WORMHOLE_CHAIN_ID, abi.encodePacked(TEST_USER), TEST_USER, TEST_TRANSFER_AMOUNT
        );

        // Pre-action Assertions
        assertEq(IUSXTest(address(usx_proxy)).totalSupply(), INITIAL_TOKENS);
        assertEq(IUSXTest(address(usx_proxy)).balanceOf(TEST_USER), INITIAL_TOKENS);

        // Act
        vm.prank(TRUSTED_WORMHOLE_RELAYER);
        IUSXTest(address(usx_proxy)).processMessage(bytes(""));

        // Post-action Assertions
        assertEq(IUSXTest(address(usx_proxy)).totalSupply(), INITIAL_TOKENS + TEST_TRANSFER_AMOUNT);
        assertEq(IUSXTest(address(usx_proxy)).balanceOf(TEST_USER), INITIAL_TOKENS + TEST_TRANSFER_AMOUNT);
    }

    function testCannot_lzReceive_invalid_sender() public {
        vm.expectRevert("LzApp: invalid endpoint caller");

        // Act
        IUSXTest(address(usx_proxy)).lzReceive(
            TEST_CHAIN_ID,
            abi.encode(address(this)),
            1,
            abi.encode(abi.encodePacked(address(this)), TEST_TRANSFER_AMOUNT)
        );
    }

    function testCannot_lzReceive_invalid_source_address() public {
        vm.expectRevert("LzApp: invalid source sending contract");
        
        // Act
        vm.prank(LZ_ENDPOINT);
        IUSXTest(address(usx_proxy)).lzReceive(
            TEST_CHAIN_ID, abi.encode(address(0)), 1, abi.encode(abi.encodePacked(address(this)), TEST_TRANSFER_AMOUNT)
        );
    }
}


contract TestCrossChainSendFrom is Test, SharedSetup {
    function test_sendFrom(uint256 transferAmount) public {
        // Setup
        vm.assume(transferAmount <= INITIAL_TOKENS);

        for (uint8 index = uint8(BridgingProtocols.WORMHOLE); index <= uint8(BridgingProtocols.LAYER_ZERO); index++) {
            // Expectations
            vm.expectEmit(true, true, true, true, address(usx_proxy));
            emit SendToChain(TEST_CHAIN_ID, address(this), abi.encode(address(this)), transferAmount);

            // Pre-action Assertions
            assertEq(IUSXTest(address(usx_proxy)).totalSupply(), INITIAL_TOKENS);
            assertEq(IUSXTest(address(usx_proxy)).balanceOf(address(this)), INITIAL_TOKENS);

            // Act
            uint256 id = vm.snapshot();
            IUSXTest(address(usx_proxy)).sendFrom(
                index,
                address(this),
                TEST_CHAIN_ID,
                abi.encode(address(this)),
                transferAmount,
                payable(address(this))
            );

            // Post-action Assertions
            assertEq(IUSXTest(address(usx_proxy)).totalSupply(), INITIAL_TOKENS - transferAmount);
            assertEq(IUSXTest(address(usx_proxy)).balanceOf(address(this)), INITIAL_TOKENS - transferAmount);

            // Revert to previous state, so subsequent protocols have access to funds to send
            vm.revertTo(id); 
        }
    }

    function testCannot_sendFrom_amount() public {
        vm.expectRevert(stdError.arithmeticError);

        // Act
        IUSXTest(address(usx_proxy)).sendFrom(
            0,
            address(this),
            TEST_CHAIN_ID,
            abi.encode(address(this)),
            INITIAL_TOKENS + 1,
            payable(address(this))
        );
    }

    function testCannot_sendFrom_from_address() public {
        vm.expectRevert("ERC20: insufficient allowance");

        // Act
        IUSXTest(address(usx_proxy)).sendFrom(
            0,
            address(0),
            TEST_CHAIN_ID,
            abi.encode(address(this)),
            TEST_TRANSFER_AMOUNT,
            payable(address(this))
        );
    }

    function testCannot_sendFrom_paused() public {
        // Setup
        IUSXTest(address(usx_proxy)).manageCrossChainTransfers([BridgingProtocols.WORMHOLE,BridgingProtocols.LAYER_ZERO], [false,false]);


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
        for (uint pausedIndex = 0; pausedIndex < privileges.length; pausedIndex++) {
            privileges = [true, true];
            privileges[pausedIndex] = false;
            
            IUSXTest(address(usx_proxy)).manageCrossChainTransfers([BridgingProtocols.WORMHOLE,BridgingProtocols.LAYER_ZERO], privileges);
            
            // Given this iteration's privilege settings, iterate through both bridges to ensure privileges are active
            for (uint8 bridgeID = uint8(BridgingProtocols.WORMHOLE); bridgeID <= uint8(BridgingProtocols.LAYER_ZERO); bridgeID++) {
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

contract TestAdmin is Test, SharedSetup {
    function test_fail_manageCrossChainTransfers_sender() public {
        // Expectations
        vm.expectRevert("Ownable: caller is not the owner");

        // Act - attempt pause
        vm.prank(TEST_ADDRESS);
        IUSXTest(address(usx_proxy)).manageCrossChainTransfers([BridgingProtocols.WORMHOLE,BridgingProtocols.LAYER_ZERO], [false,false]);

        // Expectations
        vm.expectRevert("Ownable: caller is not the owner");

        // Act - attempt unpause
        vm.prank(TEST_ADDRESS);
        IUSXTest(address(usx_proxy)).manageCrossChainTransfers([BridgingProtocols.WORMHOLE,BridgingProtocols.LAYER_ZERO], [true,true]);
    }

    function test_manageCrossChainTransfers_pause_both() public {
        // Pre-action assertions
        assertEq(IUSXTest(address(usx_proxy)).transferPrivileges(uint8(BridgingProtocols.WORMHOLE)), true);
        assertEq(IUSXTest(address(usx_proxy)).transferPrivileges(uint8(BridgingProtocols.LAYER_ZERO)), true);

        // Act - pause
        IUSXTest(address(usx_proxy)).manageCrossChainTransfers([BridgingProtocols.WORMHOLE,BridgingProtocols.LAYER_ZERO], [false,false]);

        // Post-action assertions
        assertEq(IUSXTest(address(usx_proxy)).transferPrivileges(uint8(BridgingProtocols.WORMHOLE)), false);
        assertEq(IUSXTest(address(usx_proxy)).transferPrivileges(uint8(BridgingProtocols.LAYER_ZERO)), false);
    }

    function test_manageCrossChainTransfers_unpause_both() public {
        // Setup
        IUSXTest(address(usx_proxy)).manageCrossChainTransfers([BridgingProtocols.WORMHOLE,BridgingProtocols.LAYER_ZERO], [false,false]);
        assertEq(IUSXTest(address(usx_proxy)).transferPrivileges(uint8(BridgingProtocols.WORMHOLE)), false);
        assertEq(IUSXTest(address(usx_proxy)).transferPrivileges(uint8(BridgingProtocols.LAYER_ZERO)), false);

        // Act - unpause
        IUSXTest(address(usx_proxy)).manageCrossChainTransfers([BridgingProtocols.WORMHOLE,BridgingProtocols.LAYER_ZERO], [true,true]);

        // Post-action assertions
        assertEq(IUSXTest(address(usx_proxy)).transferPrivileges(uint8(BridgingProtocols.WORMHOLE)), true);
        assertEq(IUSXTest(address(usx_proxy)).transferPrivileges(uint8(BridgingProtocols.LAYER_ZERO)), true);
    }

    /// @dev tests that each bridge can be singularly paused
    function test_manageCrossChainTransfers_pause_one() public {
        uint256 id = vm.snapshot();
        bool[2] memory privileges = [true, true];
        
        // Iterate through privileges, each time revoking privileges for only one bridge
        for (uint pausedIndex = 0; pausedIndex < privileges.length; pausedIndex++) {
            // Pre-action assertions
            assertEq(IUSXTest(address(usx_proxy)).transferPrivileges(uint8(BridgingProtocols.WORMHOLE)), true);
            assertEq(IUSXTest(address(usx_proxy)).transferPrivileges(uint8(BridgingProtocols.LAYER_ZERO)), true);

            privileges = [true, true];
            privileges[pausedIndex] = false;

            // Act - pause
            IUSXTest(address(usx_proxy)).manageCrossChainTransfers([BridgingProtocols.WORMHOLE,BridgingProtocols.LAYER_ZERO], privileges);

            // Given this iteration's privilege settings, iterate through both bridges to ensure privileges are active
            for (uint8 bridgeID = uint8(BridgingProtocols.WORMHOLE); bridgeID <= uint8(BridgingProtocols.LAYER_ZERO); bridgeID++) {
                if (bridgeID == pausedIndex) {
                    assertEq(IUSXTest(address(usx_proxy)).transferPrivileges(bridgeID), false);
                } else {
                    assertEq(IUSXTest(address(usx_proxy)).transferPrivileges(bridgeID), true);
                }
            }
            // Revert chain state, such that each iteration is state-independent
            vm.revertTo(id); 
        }
    }
}

contract TestPauseIntegration is Test, SharedSetup {
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

        assertEq(IUSXTest(address(usx_proxy)).totalSupply(), BALANCE_AFTER_FIRST_TRANSFER);
        assertEq(IUSXTest(address(usx_proxy)).balanceOf(address(this)), BALANCE_AFTER_FIRST_TRANSFER);

        // 2. Pause
        IUSXTest(address(usx_proxy)).manageCrossChainTransfers([BridgingProtocols.WORMHOLE,BridgingProtocols.LAYER_ZERO], [false,true]);

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

        assertEq(IUSXTest(address(usx_proxy)).totalSupply(), BALANCE_AFTER_SECOND_TRANSFER);
        assertEq(IUSXTest(address(usx_proxy)).balanceOf(address(this)), BALANCE_AFTER_SECOND_TRANSFER);
        vm.revertTo(id);

        // 5. Unpause
        IUSXTest(address(usx_proxy)).manageCrossChainTransfers([BridgingProtocols.WORMHOLE,BridgingProtocols.LAYER_ZERO], [true,true]);

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

        assertEq(IUSXTest(address(usx_proxy)).totalSupply(), BALANCE_AFTER_SECOND_TRANSFER);
        assertEq(IUSXTest(address(usx_proxy)).balanceOf(address(this)), BALANCE_AFTER_SECOND_TRANSFER);
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

        assertEq(IUSXTest(address(usx_proxy)).totalSupply(), BALANCE_AFTER_FIRST_TRANSFER);
        assertEq(IUSXTest(address(usx_proxy)).balanceOf(address(this)), BALANCE_AFTER_FIRST_TRANSFER);

        // 2. Pause
        IUSXTest(address(usx_proxy)).manageCrossChainTransfers([BridgingProtocols.WORMHOLE,BridgingProtocols.LAYER_ZERO], [true,false]);

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

        assertEq(IUSXTest(address(usx_proxy)).totalSupply(), BALANCE_AFTER_SECOND_TRANSFER);
        assertEq(IUSXTest(address(usx_proxy)).balanceOf(address(this)), BALANCE_AFTER_SECOND_TRANSFER);
        vm.revertTo(id);

        // 5. Unpause
        IUSXTest(address(usx_proxy)).manageCrossChainTransfers([BridgingProtocols.WORMHOLE,BridgingProtocols.LAYER_ZERO], [true,true]);

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

        assertEq(IUSXTest(address(usx_proxy)).totalSupply(), BALANCE_AFTER_SECOND_TRANSFER);
        assertEq(IUSXTest(address(usx_proxy)).balanceOf(address(this)), BALANCE_AFTER_SECOND_TRANSFER);
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

        assertEq(IUSXTest(address(usx_proxy)).totalSupply(), BALANCE_AFTER_FIRST_TRANSFER);
        assertEq(IUSXTest(address(usx_proxy)).balanceOf(address(this)), BALANCE_AFTER_FIRST_TRANSFER);
        vm.revertTo(id_1);

        IUSXTest(address(usx_proxy)).sendFrom(
            uint8(BridgingProtocols.WORMHOLE),
            address(this),
            TEST_CHAIN_ID,
            abi.encode(address(this)),
            transferAmount,
            payable(address(this))
        );

        assertEq(IUSXTest(address(usx_proxy)).totalSupply(), BALANCE_AFTER_FIRST_TRANSFER);
        assertEq(IUSXTest(address(usx_proxy)).balanceOf(address(this)), BALANCE_AFTER_FIRST_TRANSFER);

        // 2. Pause
        IUSXTest(address(usx_proxy)).manageCrossChainTransfers([BridgingProtocols.WORMHOLE,BridgingProtocols.LAYER_ZERO], [false,false]);

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
        IUSXTest(address(usx_proxy)).manageCrossChainTransfers([BridgingProtocols.WORMHOLE,BridgingProtocols.LAYER_ZERO], [true,true]);

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

        assertEq(IUSXTest(address(usx_proxy)).totalSupply(), BALANCE_AFTER_SECOND_TRANSFER);
        assertEq(IUSXTest(address(usx_proxy)).balanceOf(address(this)), BALANCE_AFTER_SECOND_TRANSFER);
        vm.revertTo(id_2);

        IUSXTest(address(usx_proxy)).sendFrom(
            uint8(BridgingProtocols.WORMHOLE),
            address(this),
            TEST_CHAIN_ID,
            abi.encode(address(this)),
            transferAmount,
            payable(address(this))
        );

        assertEq(IUSXTest(address(usx_proxy)).totalSupply(), BALANCE_AFTER_SECOND_TRANSFER);
        assertEq(IUSXTest(address(usx_proxy)).balanceOf(address(this)), BALANCE_AFTER_SECOND_TRANSFER);
    }
}
