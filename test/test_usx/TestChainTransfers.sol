// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "forge-std/Test.sol";
import "../../src/USX.sol";
import "../../src/proxy/ERC1967Proxy.sol";
import "../../src/interfaces/ILayerZeroEndpoint.sol";
import "../mocks/MockLayerZeroEndpoint.t.sol";
import "../interfaces/IMessagePassing.t.sol";
import "../interfaces/IUSXTest.t.sol";
import "../common/constants.t.sol";

abstract contract SharedSetup is Test {
    /**
     *
     * @dev Other test contracts can use this set up by inheriting this abstract contract.
     */

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
            new ERC1967Proxy(address(usx_implementation), abi.encodeWithSignature("initialize(address)", LZ_ENDPOINT));

        // Set Treasury Admin
        IUSXTest(address(usx_proxy)).manageTreasuries(TREASURY, true, true);

        // Mint Initial Tokens
        vm.prank(TREASURY);
        IUSX(address(usx_proxy)).mint(address(this), INITIAL_TOKENS);

        // Mocks
        mockLayerZeroEndpoint = new MockLayerZeroEndpoint();
        bytes memory mockLayerZeroEndpointCode = address(mockLayerZeroEndpoint).code;
        vm.etch(address(LZ_ENDPOINT), mockLayerZeroEndpointCode);
        vm.mockCall(LZ_ENDPOINT, abi.encodeWithSelector(ILayerZeroEndpoint(LZ_ENDPOINT).send.selector), abi.encode());

        // Set Trusted Remote for LayerZero
        IMessagePassing(address(usx_proxy)).setTrustedRemote(
            TEST_CHAIN_ID, abi.encodePacked(address(usx_proxy), address(usx_proxy))
        );
    }
}

contract TestChainTransfers is Test, SharedSetup {
    function test_lzReceive() public {
        // Expectations
        vm.expectEmit(true, true, true, true, address(usx_proxy));
        emit ReceiveFromChain(
            TEST_CHAIN_ID, abi.encodePacked(address(usx_proxy), address(usx_proxy)), address(this), TEST_TRANSFER_AMOUNT
            );

        // Pre-action Assertions
        assertEq(IUSX(address(usx_proxy)).totalSupply(), INITIAL_TOKENS);
        assertEq(IUSX(address(usx_proxy)).balanceOf(address(this)), INITIAL_TOKENS);

        // Act
        vm.prank(LZ_ENDPOINT);
        IMessagePassing(address(usx_proxy)).lzReceive(
            TEST_CHAIN_ID,
            abi.encodePacked(address(usx_proxy), address(usx_proxy)),
            1,
            abi.encode(abi.encodePacked(address(this)), TEST_TRANSFER_AMOUNT)
        );

        // Post-action Assertions
        assertEq(IUSX(address(usx_proxy)).totalSupply(), INITIAL_TOKENS + TEST_TRANSFER_AMOUNT);
        assertEq(IUSX(address(usx_proxy)).balanceOf(address(this)), INITIAL_TOKENS + TEST_TRANSFER_AMOUNT);
    }

    function testFail_lzReceive_invalid_sender() public {
        // Act
        IMessagePassing(address(usx_proxy)).lzReceive(
            TEST_CHAIN_ID,
            abi.encode(address(this)),
            1,
            abi.encode(abi.encodePacked(address(this)), TEST_TRANSFER_AMOUNT)
        );
    }

    function testFail_lzReceive_invalid_source_address() public {
        // Act
        vm.prank(LZ_ENDPOINT);
        IMessagePassing(address(usx_proxy)).lzReceive(
            TEST_CHAIN_ID, abi.encode(address(0)), 1, abi.encode(abi.encodePacked(address(this)), TEST_TRANSFER_AMOUNT)
        );
    }

    function test_sendFrom() public {
        // Expectations
        vm.expectEmit(true, true, true, true, address(usx_proxy));
        emit SendToChain(TEST_CHAIN_ID, address(this), abi.encode(address(this)), TEST_TRANSFER_AMOUNT);

        // Pre-action Assertions
        assertEq(IUSX(address(usx_proxy)).totalSupply(), INITIAL_TOKENS);
        assertEq(IUSX(address(usx_proxy)).balanceOf(address(this)), INITIAL_TOKENS);

        // Act
        IUSX(address(usx_proxy)).sendFrom(
            address(this),
            TEST_CHAIN_ID,
            abi.encode(address(this)),
            TEST_TRANSFER_AMOUNT,
            payable(address(this)),
            address(0),
            bytes("")
        );

        // Post-action Assertions
        assertEq(IUSX(address(usx_proxy)).totalSupply(), INITIAL_TOKENS - TEST_TRANSFER_AMOUNT);
        assertEq(IUSX(address(usx_proxy)).balanceOf(address(this)), INITIAL_TOKENS - TEST_TRANSFER_AMOUNT);
    }

    function testFail_sendFrom_amount() public {
        // Act
        IUSX(address(usx_proxy)).sendFrom(
            address(this),
            TEST_CHAIN_ID,
            abi.encode(address(this)),
            INITIAL_TOKENS + 1,
            payable(address(this)),
            address(0),
            bytes("")
        );
    }

    function testFail_sendFrom_from_address() public {
        // Act
        IUSX(address(usx_proxy)).sendFrom(
            address(0),
            TEST_CHAIN_ID,
            abi.encode(address(this)),
            TEST_TRANSFER_AMOUNT,
            payable(address(this)),
            address(0),
            bytes("")
        );
    }

    function test_fail_sendFrom_paused() public {
        // Setup
        IUSXTest(address(usx_proxy)).manageCrossChainTransfers(true);

        // Expectations
        vm.expectRevert(IUSXTest(address(usx_proxy)).Paused.selector);

        // Act
        IUSX(address(usx_proxy)).sendFrom(
            address(this),
            TEST_CHAIN_ID,
            abi.encode(address(this)),
            TEST_TRANSFER_AMOUNT,
            payable(address(this)),
            address(0),
            bytes("")
        );
    }
}

contract TestAdmin is Test, SharedSetup {
    function test_fail_manageCrossChainTransfers_sender() public {
        // Expectations
        vm.expectRevert("Ownable: caller is not the owner");

        // Act - attempt pause
        vm.prank(TEST_ADDRESS);
        IUSXTest(address(usx_proxy)).manageCrossChainTransfers(true);

        // Expectations
        vm.expectRevert("Ownable: caller is not the owner");

        // Act - attempt unpause
        vm.prank(TEST_ADDRESS);
        IUSXTest(address(usx_proxy)).manageCrossChainTransfers(false);
    }

    function test_manageCrossChainTransfers_pause() public {
        // Pre-action assertions
        assertEq(IUSXTest(address(usx_proxy)).paused(), false);

        // Act - pause
        IUSXTest(address(usx_proxy)).manageCrossChainTransfers(true);

        // Post-action assertions
        assertEq(IUSXTest(address(usx_proxy)).paused(), true);
    }

    function test_manageCrossChainTransfers_unpause() public {
        // Setup
        IUSXTest(address(usx_proxy)).manageCrossChainTransfers(true);
        assertEq(IUSXTest(address(usx_proxy)).paused(), true);

        // Act - unpause
        IUSXTest(address(usx_proxy)).manageCrossChainTransfers(false);

        // Post-action assertions
        assertEq(IUSXTest(address(usx_proxy)).paused(), false);
    }
}

contract TestPause is Test, SharedSetup {
    /**
     *
     * @dev Integration tests.
     */

    function test_pause_integration() public {
        // Test Variables
        uint256 BALANCE_AFTER_FIRST_TRANSFER = INITIAL_TOKENS - TEST_TRANSFER_AMOUNT;
        uint256 BALANCE_AFTER_SECOND_TRANSFER = BALANCE_AFTER_FIRST_TRANSFER - TEST_TRANSFER_AMOUNT;

        // 1. Ensure cross-chain transfers work
        vm.expectEmit(true, true, true, true, address(usx_proxy));
        emit SendToChain(TEST_CHAIN_ID, address(this), abi.encode(address(this)), TEST_TRANSFER_AMOUNT);

        IUSX(address(usx_proxy)).sendFrom(
            address(this),
            TEST_CHAIN_ID,
            abi.encode(address(this)),
            TEST_TRANSFER_AMOUNT,
            payable(address(this)),
            address(0),
            bytes("")
        );

        assertEq(IUSX(address(usx_proxy)).totalSupply(), BALANCE_AFTER_FIRST_TRANSFER);
        assertEq(IUSX(address(usx_proxy)).balanceOf(address(this)), BALANCE_AFTER_FIRST_TRANSFER);

        // 2. Pause
        IUSXTest(address(usx_proxy)).manageCrossChainTransfers(true);

        // 3. Ensure cross-chain transfers are disabled
        vm.expectRevert(IUSXTest(address(usx_proxy)).Paused.selector);

        IUSX(address(usx_proxy)).sendFrom(
            address(this),
            TEST_CHAIN_ID,
            abi.encode(address(this)),
            TEST_TRANSFER_AMOUNT,
            payable(address(this)),
            address(0),
            bytes("")
        );

        // 4. Unpause
        IUSXTest(address(usx_proxy)).manageCrossChainTransfers(false);

        // 5. Ensure cross-chain transfers work again
        vm.expectEmit(true, true, true, true, address(usx_proxy));
        emit SendToChain(TEST_CHAIN_ID, address(this), abi.encode(address(this)), TEST_TRANSFER_AMOUNT);

        IUSX(address(usx_proxy)).sendFrom(
            address(this),
            TEST_CHAIN_ID,
            abi.encode(address(this)),
            TEST_TRANSFER_AMOUNT,
            payable(address(this)),
            address(0),
            bytes("")
        );

        assertEq(IUSX(address(usx_proxy)).totalSupply(), BALANCE_AFTER_SECOND_TRANSFER);
        assertEq(IUSX(address(usx_proxy)).balanceOf(address(this)), BALANCE_AFTER_SECOND_TRANSFER);
    }
}
