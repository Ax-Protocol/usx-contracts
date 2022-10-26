// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

import "./utils/Initializable.sol";
import "./proxy/UUPSUpgradeable.sol";
import "./utils/Ownable.sol";
import "./bridging/OERC20.sol";
import "./interfaces/IUSX.sol";

contract USX is Initializable, UUPSUpgradeable, Ownable, OERC20, IUSX {
    function initialize(address _lzEndpoint) public initializer {
        __ERC20_init("USX", "USX");
        __OERC20_init(_lzEndpoint);
        __Ownable_init(); // @dev as there is no constructor, we need to initialise the Ownable explicitly
    }

    // @dev required by the UUPS module
    function _authorizeUpgrade(address) internal override onlyOwner {}

    // TODO: mint and burn will be revised to account for curve LP token interaction
    function mint(uint256 amount) public {
        require(amount > 0, "Mint amount must be greater than zero.");
        _mint(msg.sender, amount);
    }

    function burn(uint256 amount) public {
        require(balanceOf[msg.sender] >= amount, "Burn amount exceeds balance.");
        _burn(msg.sender, amount);
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     */
    uint256[50] private __gap;
}
