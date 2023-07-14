// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import { ILayerZeroReceiver } from "./ILayerZeroReceiver.sol";

interface IWormholeBridge {
    function sendFeeLookup(uint16 destChainId) external returns (uint256);

    function getTrustedContracts() external returns (bytes32[] memory);

    function getTrustedRelayers() external returns (address[] memory);

    function usx() external returns (address);

    function trustedContracts(bytes32) external returns (bool);

    function trustedRelayers(address) external returns (bool);

    // Admin functions
    function upgradeTo(address newImplementation) external;

    function processMessage(bytes memory _vaa) external;

    function feeSetter() external returns (address);

    function manageTrustedContracts(bytes32 _contract, bool _isTrusted) external;

    function manageTrustedRelayers(address _relayer, bool _isTrusted) external;

    function setFeeSetter(address _feeSetter) external;

    function setSendFees(uint16[] calldata _destChainIds, uint256[] calldata _fees) external;

    function extractERC20(address _token) external;

    function extractNative() external;
}
