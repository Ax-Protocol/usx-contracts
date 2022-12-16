// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

import "solmate/utils/SafeTransferLib.sol";
import "../../common/utils/InitOwnable.sol";
import "../../common/interfaces/IERC20.sol";

abstract contract Privileged is InitOwnable {
    struct TreasuryPrivileges {
        bool mint;
        bool burn;
    }

    mapping(address => TreasuryPrivileges) public treasuries;
    mapping(address => bool) public transferPrivileges;

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
     * @dev Manages cross-chain transfer privileges for each message passing protocol.
     * @param _bridgeAddresses - An array of supported bridge IDs; the order must match `_privilges` array.
     * @param _privileges - An array of protocol privileges; the order must match `_bridgeIds` array.
     */
    function manageCrossChainTransfers(address[2] calldata _bridgeAddresses, bool[2] calldata _privileges)
        public
        onlyOwner
    {
        require(_bridgeAddresses.length == _privileges.length, "Arrays must be equal length.");

        for (uint256 i = 0; i < _bridgeAddresses.length; i++) {
            transferPrivileges[_bridgeAddresses[i]] = _privileges[i];
        }
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
     * @dev Allow a treasury to revoke its own mint and burn privileges.
     */
    function treasuryKillSwitch() public {
        TreasuryPrivileges memory privileges = treasuries[msg.sender];

        require(privileges.mint || privileges.burn, "Unauthorized.");

        treasuries[msg.sender] = TreasuryPrivileges(false, false);
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage slots in the inheritance chain.
     * Storage slot management is necessary, as we're using an upgradable proxy contract.
     * For details, see: https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[50] private __gap;
}
