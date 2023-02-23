// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

// Contracts
import "solmate/utils/SafeTransferLib.sol";
import "../common/utils/Initializable.sol";
import "../common/utils/Ownable.sol";
import "../proxy/UUPSUpgradeable.sol";
import "./bridging/OERC20.sol";

// Interfaces
import "../common/interfaces/IUSX.sol";

contract USX is Initializable, UUPSUpgradeable, Ownable, OERC20, IUSX {
    // Storage Variables: follow storage slot restrictions
    struct TreasuryPrivileges {
        bool mint;
        bool burn;
    }

    mapping(address => TreasuryPrivileges) public treasuries;

    function initialize() public initializer {
        /// @dev No constructor, so initialize Ownable explicitly.
        // TODO: Replace 0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496 with prod contract deployer address.
        //       Unit tests must know this address.
        require(msg.sender == address(0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496), "Invalid caller");
        __Ownable_init();
        __ERC20_init("USX", "USX");
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
     * @dev Manages cross-chain transfer privileges for each message passing protocol.
     * @param _treasury - The address of the USX Treasury contract.
     * @param _mint - Whether or not this treasury can mint USX.
     * @param _burn - Whether or not this treasury can burn USX.
     */
    function manageTreasuries(address _treasury, bool _mint, bool _burn) public onlyOwner {
        treasuries[_treasury] = TreasuryPrivileges(_mint, _burn);
    }

    /**
     * @dev This function allows contract admins to extract any ERC20 token.
     * @param _token The address of token to remove.
     */
    function extractERC20(address _token) public onlyOwner {
        uint256 balance = IERC20(_token).balanceOf(address(this));

        SafeTransferLib.safeTransfer(ERC20(_token), msg.sender, balance);
    }

    /**
     * @dev Allow contract admins to extract native token.
     */
    function extractNative() public onlyOwner {
        payable(msg.sender).transfer(address(this).balance);
    }

    /**
     * @dev Allow a treasury to revoke its own mint and burn privileges.
     */
    function treasuryKillSwitch() public {
        TreasuryPrivileges memory privileges = treasuries[msg.sender];

        require(privileges.mint || privileges.burn, "Unauthorized.");

        treasuries[msg.sender] = TreasuryPrivileges(false, false);
    }

    receive() external payable {}

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage slots in the inheritance chain.
     * Storage slot management is necessary, as we're using an upgradable proxy contract.
     * For details, see: https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[50] private __gap;
}
