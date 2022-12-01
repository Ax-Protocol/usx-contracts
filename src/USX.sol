// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

import "solmate/utils/SafeTransferLib.sol";
import "./utils/Initializable.sol";
import "./proxy/UUPSUpgradeable.sol";
import "./utils/Ownable.sol";
import "./bridging/OERC20.sol";
import "./interfaces/IUSX.sol";

contract USX is Initializable, UUPSUpgradeable, Ownable, OERC20, IUSX {
    function initialize(address _lzEndpoint, address _wormholeCoreBridgeAddress) public initializer {
        __ERC20_init("USX", "USX");
        __OERC20_init(_lzEndpoint, _wormholeCoreBridgeAddress);
        __Ownable_init();
        /// @dev No constructor, so initialize Ownable explicitly.
    }

    /// @dev Required by the UUPS module.
    function _authorizeUpgrade(address) internal override onlyOwner {}

    /**
     * @dev Callable by treasuries, this function mints USX.
     * @param _account The address of the account to mint to.
     * @param _amount The amount of USX to mint.
     */
    function mint(address _account, uint256 _amount) public {
        require(treasuries[msg.sender].mint, "Unauthorized.");
        _mint(_account, _amount);
    }

    /**
     * @dev Callable by treasuries, this function burns USX.
     * @param _account The address of the account to burn from.
     * @param _amount The amount of USX to burn.
     */
    function burn(address _account, uint256 _amount) public {
        require(treasuries[msg.sender].burn, "Unauthorized.");
        _burn(_account, _amount);
    }

    /* ****************************************************************************
    **
    **  Admin Functions
    **
    ******************************************************************************/

    /**
     * @dev This function allows contract admins to extract any ERC20 token.
     * @param _token The address of token to remove.
     */
    function extractERC20(address _token) public onlyOwner {
        uint256 balance = IERC20(_token).balanceOf(address(this));

        SafeTransferLib.safeTransfer(ERC20(_token), msg.sender, balance);
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage slots in the inheritance chain.
     * Storage slot management is necessary, as we're using an upgradable proxy contract.
     * For details, see: https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[50] private __gap;
}
