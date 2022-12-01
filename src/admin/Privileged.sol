// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

import "../utils/Ownable.sol";

abstract contract Privileged is Ownable {
    enum BridgingProtocols {
        WORMHOLE,
        LAYER_ZERO
    }

    struct TreasuryPrivileges {
        bool mint;
        bool burn;
    }

    mapping(address => TreasuryPrivileges) public treasuries;
    mapping(uint8 => bool) public transferPrivileges;

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
     * @param _bridgeIds - An array of supported bridge IDs; the order must match `_privilges` array.
     * @param _privileges - An array of protocol privileges; the order must match `_bridgeIds` array.
     */
    function manageCrossChainTransfers(BridgingProtocols[] calldata _bridgeIds, bool[] calldata _privileges)
        public
        onlyOwner
    {
        require(_bridgeIds.length == _privileges.length, "Arrays must be equal length.");

        for (uint256 i = 0; i < _bridgeIds.length; i++) {
            transferPrivileges[uint8(_bridgeIds[i])] = _privileges[i];
        }
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage slots in the inheritance chain.
     * Storage slot management is necessary, as we're using an upgradable proxy contract.
     * For details, see: https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[50] private __gap;
}
