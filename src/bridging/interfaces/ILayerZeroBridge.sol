// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import { ILayerZeroReceiver } from "./ILayerZeroReceiver.sol";

interface ILayerZeroBridge is ILayerZeroReceiver {
    function usx() external returns (address);

    function isTrustedRemote(uint16 _srcChainId, bytes calldata _srcAddress) external returns (bool);

    // Admin functions
    function upgradeTo(address newImplementation) external;

    function setTrustedRemote(uint16 _srcChainId, bytes calldata _srcAddress) external;

    function setUseCustomAdapterParams(bool _useCustomAdapterParams) external;

    function useCustomAdapterParams() external returns (bool);

    function extractERC20(address _token) external;

    function extractNative() external;
}
