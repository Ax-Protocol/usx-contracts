// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "forge-std/Test.sol";
import "../../../../src/usx/USX.sol";
import "../../../../src/proxy/ERC1967Proxy.sol";
import "../../../mocks/MockLayerZero.t.sol";

import "../../../../src/common/interfaces/IUSXAdmin.sol";

import "../../../common/Constants.t.sol";

// abstract contract CrossChainSetup is Test {
//     // Test Contracts
//     USX public usx_implementation;
//     ERC1967Proxy public usx_proxy;

//     // Test Constants
//     uint16 constant TEST_CHAIN_ID = 109;
//     address constant TEST_FROM_ADDRESS = 0x7e51587F7edA1b583Fde9b93ED92B289f985fe25;
//     address constant TEST_TO_ADDRESS = 0xA72Fb6506f162974dB9B6C702238cfB1Ccc60262;

//     // Events
//     event ReceiveFromChain(
//         uint16 indexed _srcChainId, bytes indexed _srcAddress, address indexed _toAddress, uint256 _amount
//     );
//     event SendToChain(uint16 indexed _dstChainId, address indexed _from, bytes indexed _toAddress, uint256 _amount);

//     function setUp() public {
//         // Deploy USX implementation, and link to proxy
//         usx_implementation = new USX();
//         usx_proxy =
//         new ERC1967Proxy(address(usx_implementation), abi.encodeWithSignature("initialize(address,address)", LZ_ENDPOINT, WORMHOLE_CORE_BRIDGE));

//         // Set Treasury admin
//         IUSXAdmin(address(usx_proxy)).manageTreasuries(TREASURY, true, true);

//         // Mint initial Tokens
//         vm.prank(TREASURY);
//         IUSXAdmin(address(usx_proxy)).mint(address(this), INITIAL_TOKENS);

//         // Mocks
//         bytes memory MockLayerZeroCode = address(new MockLayerZero()).code;
//         vm.etch(LZ_ENDPOINT, MockLayerZeroCode);

//         // Set Trusted Remote for LayerZero
//         // TODO: Fix, make call on bridge
//         IUSXAdmin(address(usx_proxy)).setTrustedRemote(
//             TEST_CHAIN_ID, abi.encodePacked(address(usx_proxy), address(usx_proxy))
//         );

//         // Set Trusted Entities for Wormhole
//         IUSXAdmin(address(usx_proxy)).manageTrustedContracts(TEST_TRUSTED_EMITTER_ADDRESS, true);
//         IUSXAdmin(address(usx_proxy)).manageTrustedRelayers(TRUSTED_WORMHOLE_RELAYER, true);

//         // Grant Transfer privliges
//         IUSXAdmin(address(usx_proxy)).manageCrossChainTransfers(
//             [BridgingProtocols.WORMHOLE, BridgingProtocols.LAYER_ZERO], [true, true]
//         );
//     }
// }
