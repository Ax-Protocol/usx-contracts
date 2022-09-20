// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "ds-test/test.sol";
import "forge-std/Vm.sol";
import "forge-std/Test.sol";
import "../src/USX.sol";
import "../src/proxy/ERC1967Proxy.sol";

contract USXTest is Test {
    using stdStorage for StdStorage;

    USX public usx_implementation;
    ERC1967Proxy public usx_proxy;
    bytes public empty;

    function setUp() public {
        usx_implementation = new USX();
        usx_proxy = new ERC1967Proxy(address(usx_implementation),  abi.encodeWithSignature("initialize()"));
    }

    function test_symbol() public {
        assertEq(IUSX(address(usx_proxy)).symbol(), "USX");
    }
}
