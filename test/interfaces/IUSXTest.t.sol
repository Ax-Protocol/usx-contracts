// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

import "../../src/interfaces/IUSX.sol";
import "./IMessagePassing.t.sol";

interface IUSXTest is IUSX, IMessagePassing {
    function permit(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s)
        external;

    function nonces(address owner) external returns (uint256);

    function DOMAIN_SEPARATOR() external returns (bytes32);

    function upgradeTo(address newImplementation) external;

    function manageTreasuries(address _treasury, bool _mint, bool _burn) external;

    function treasuries(address _treasury) external returns (bool mint, bool burn);

    function manageCrossChainTransfers(bool _paused) external;

    function paused() external returns (bool);

    function Paused() external;
}
