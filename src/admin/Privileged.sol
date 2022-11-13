// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

import "../utils/Ownable.sol";

abstract contract Privileged is Ownable {
    struct Privileges {
        bool mint;
        bool burn;
    }

    bool public paused = false;

    mapping(address => Privileges) public treasuries;

    function manageTreasuries(address _treasury, bool _mint, bool _burn) public onlyOwner {
        treasuries[_treasury] = Privileges(_mint, _burn);
    }

    function manageCrossChainTransfers(bool _paused) public onlyOwner {
        paused = _paused;
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     */
    uint256[50] private __gap;
}
