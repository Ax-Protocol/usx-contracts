// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "./ILayerZeroReceiver.sol";

interface IWormholeBridge {
    function processMessage(bytes memory _vaa) external;

    function usx() external returns (address);

    function trustedContracts(bytes32) external returns (bool);

    function trustedRelayers(address) external returns (bool);

    // Admin functions
    function manageTrustedContracts(bytes32 _contract, bool _isTrusted) external;

    function manageTrustedRelayers(address _relayer, bool _isTrusted) external;

    function getTrustedContracts() external returns (bytes32[] memory);

    function getTrustedRelayers() external returns (address[] memory);

    function setSendFees(uint16[] memory _destChainIds, uint256[] memory _fees) external;

    function sendFeeLookup(uint16 destChainId) external returns (uint256);

    function extractERC20(address _token) external;

    function extractNative() external;
}
