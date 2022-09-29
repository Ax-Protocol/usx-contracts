// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

import "./utils/Initializable.sol";
import "./proxy/UUPSUpgradeable.sol";
import "./utils/Ownable.sol";
import "./bridging/OERC20.sol";
import "./interfaces/IUSX.sol";
import "solmate/utils/SafeTransferLib.sol";

contract USX is Initializable, UUPSUpgradeable, Ownable, OERC20, IUSX {
    ERC20 dai = ERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);

    function initialize() public initializer {
        __ERC20_init("USX", "USX");

        // @dev as there is no constructor, we need to initialise the Ownable explicitly
        __Ownable_init();
    }

    // @dev required by the UUPS module
    function _authorizeUpgrade(address) internal override onlyOwner {}

    // TODO(implement mint and burn by depositing collateral)
    function mint(uint256 amount) public {
        SafeTransferLib.safeTransferFrom(dai, msg.sender, address(this), amount);
        _mint(msg.sender, amount);
    }

    function burn(uint256 amount) public {
        SafeTransferLib.safeTransfer(dai, msg.sender, amount);
        _burn(msg.sender, amount);
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     */
    uint256[50] private __gap;
}
