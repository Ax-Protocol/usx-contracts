// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "forge-std/Test.sol";
import "../../../../src/USX.sol";
import "../../../../src/proxy/ERC1967Proxy.sol";
import "../../../interfaces/IUSXTest.t.sol";
import "../../../common/Constants.t.sol";

abstract contract SupplyRegulationSetup is Test {
    // Test Contracts
    USX public usx_implementation;
    ERC1967Proxy public usx_proxy;

    // Events
    event Transfer(address indexed from, address indexed to, uint256 amount);

    function setUp() public {
        // Deploy USX implementation, and link to proxy
        usx_implementation = new USX();
        usx_proxy =
        new ERC1967Proxy(address(usx_implementation), abi.encodeWithSignature("initialize(address,address)", LZ_ENDPOINT, WORMHOLE_CORE_BRIDGE));

        // Set Treasury Admin
        IUSXTest(address(usx_proxy)).manageTreasuries(TREASURY, true, true);
    }
}
