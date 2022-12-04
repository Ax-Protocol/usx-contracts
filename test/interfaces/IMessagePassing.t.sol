// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

interface IMessagePassing {
    function setTrustedRemote(uint16 _srcChainId, bytes calldata _srcAddress) external;

    function lzReceive(uint16 _srcChainId, bytes memory _srcAddress, uint64 _nonce, bytes memory _payload) external;

    function processMessage(bytes memory _vaa) external;

    function manageTrustedContracts(bytes32 _contract, bool _isTrusted) external;

    function manageTrustedRelayers(address _relayer, bool _isTrusted) external;
}