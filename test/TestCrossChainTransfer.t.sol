// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;


import "forge-std/Test.sol";
import "../src/USX.sol";
import "../src/proxy/ERC1967Proxy.sol";
import "../src/interfaces/ILayerZeroEndpoint.sol";
import "./mocks/MockLayerZeroEndpoint.t.sol";
import "./interfaces/IMessagePassing.t.sol";


contract TestCrossChainTransfer is Test {
    using stdStorage for StdStorage;

    // Test Contracts
    USX public usx_implementation;
    ERC1967Proxy public usx_proxy;
    MockLayerZeroEndpoint public mockLayerZeroEndpoint;

    // Test Constants
    address constant LZ_ENDPOINT       = 0xbfD2135BFfbb0B5378b56643c2Df8a87552Bfa23;
    address constant TEST_FROM_ADDRESS = 0x7e51587F7edA1b583Fde9b93ED92B289f985fe25;
    address constant TEST_TO_ADDRESS   = 0xA72Fb6506f162974dB9B6C702238cfB1Ccc60262;
    uint constant INITIAL_TOKENS       = 100e18;
    uint16 constant TEST_CHAIN_ID      = 109;
    uint constant TEST_TRANSFER_AMOUNT = 20e18;

    // Events
    event ReceiveFromChain(
        uint16 indexed _srcChainId, bytes indexed _srcAddress, address indexed _toAddress, uint256 _amount
    );
    event SendToChain(uint16 indexed _dstChainId, address indexed _from, bytes indexed _toAddress, uint256 _amount);

    function setUp() public {
        usx_implementation = new USX();
        usx_proxy = new ERC1967Proxy(address(usx_implementation), abi.encodeWithSignature("initialize()"));
        mockLayerZeroEndpoint = new MockLayerZeroEndpoint();
        IUSX(address(usx_proxy)).mint(INITIAL_TOKENS);
        IMessagePassing(address(usx_proxy)).setTrustedRemote(TEST_CHAIN_ID, abi.encode(address(this)));
    }

    function test_lzReceive() public {
        // Expectations
        vm.expectEmit(true, true, true, true, address(usx_proxy));
        emit ReceiveFromChain(TEST_CHAIN_ID, abi.encode(address(this)), address(this), TEST_TRANSFER_AMOUNT);

        // Pre-action Assertions
        assertEq(IUSX(address(usx_proxy)).totalSupply(), INITIAL_TOKENS);
        assertEq(IUSX(address(usx_proxy)).balanceOf(address(this)), INITIAL_TOKENS);

        // Act
        vm.prank(LZ_ENDPOINT);
        IMessagePassing(address(usx_proxy)).lzReceive(
            TEST_CHAIN_ID,
            abi.encode(address(this)),
            1,
            abi.encode(abi.encodePacked(address(this)), TEST_TRANSFER_AMOUNT)
        );

        // Post-action Assertions
        assertEq(IUSX(address(usx_proxy)).totalSupply(), INITIAL_TOKENS + TEST_TRANSFER_AMOUNT);
        assertEq(IUSX(address(usx_proxy)).balanceOf(address(this)), INITIAL_TOKENS + TEST_TRANSFER_AMOUNT);
    }

    function test_sendFrom() public {
        // Expectations
        vm.expectEmit(true, true, true, true, address(usx_proxy));
        emit SendToChain(TEST_CHAIN_ID, address(this), abi.encode(address(this)), TEST_TRANSFER_AMOUNT);

        // Pre-action Assertions
        assertEq(IUSX(address(usx_proxy)).totalSupply(), INITIAL_TOKENS);
        assertEq(IUSX(address(usx_proxy)).balanceOf(address(this)), INITIAL_TOKENS);
        
        // Mocks
        bytes memory mockShaaveChildCode = address(mockLayerZeroEndpoint).code;
        vm.etch(address(LZ_ENDPOINT), mockShaaveChildCode);

        vm.mockCall(
            LZ_ENDPOINT,
            abi.encodeWithSelector(ILayerZeroEndpoint(LZ_ENDPOINT).send.selector),
            abi.encode()
        );

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

    function test_fail_sendFrom_amount() public {
        // Expectations
        vm.expectRevert("OERC20: burn amount exceeds balance.");
        
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

    function test_fail_sendFrom_address() public {
        // Failing From Address Expectations
        vm.expectRevert("OERC20: _from must be a nonzero address.");

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

        // Failing To Address Expectations
        vm.expectRevert("OERC20: toAddress must be a nonzero address.");

        // Act
        IUSX(address(usx_proxy)).sendFrom(
            address(this),
            TEST_CHAIN_ID,
            abi.encode(address(0)),
            TEST_TRANSFER_AMOUNT,
            payable(address(this)),
            address(0),
            bytes("")
        );
    }
}