// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

import "./Initializable.sol";
import "./UUPSUpgradeable.sol";
import "./Ownable.sol";
import "./ERC20.sol";
import "./interfaces/IUSX.sol";

contract USX is Initializable, UUPSUpgradeable, Ownable, IUSX, ERC20 {
    function initialize() public initializer {
        __ERC20_init("USX", "USX");

        // @dev as there is no constructor, we need to initialise the Ownable explicitly
        __Ownable_init();
    }

    // @dev required by the UUPS module
    function _authorizeUpgrade(address) internal override onlyOwner {}

    // TODO(implement mint and burn)

    // TODO(implement cross chain bridge)
}
