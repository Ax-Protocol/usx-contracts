// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0;

import "../../utils/Ownable.sol";
import "../../interfaces/IWormhole.sol";

abstract contract Wormhole is Ownable {
    IWormhole public wormholeCoreBridge;

    mapping(bytes32 => bool) public trustedContracts;
    mapping(address => bool) public trustedRelayers;
    mapping(bytes32 => bool) public processedMessages;
    bytes32[] private trustedContractsList;
    address[] private trustedRelayersList;

    function __Wormhole_init(address _wormholeCoreBridgeAddress) internal initializer {
        wormholeCoreBridge = IWormhole(_wormholeCoreBridgeAddress);
    }

    function _publishMessage(address _from, uint16 _dstChainId, bytes memory _toAddress, uint256 _amount)
        internal
        virtual
        returns (uint64 sequence)
    {
        bytes memory message = abi.encode(abi.encodePacked(_from), _dstChainId, _toAddress, _amount);

        sequence = wormholeCoreBridge.publishMessage(0, message, 200);
    }

    function processMessage(bytes memory _vaa) public {
        (IWormhole.VM memory vm, bool valid, string memory reason) = wormholeCoreBridge.parseAndVerifyVM(_vaa);

        // Ensure message verification succeeded.
        require(valid, reason);

        // Ensure the emitterAddress of this VAA is a trusted address.
        require(trustedContracts[vm.emitterAddress], "Unauthorized emitter address.");

        // Ensure that the VAA hasn't already been processed (replay protection).
        require(!processedMessages[vm.hash], "Message already processed.");

        // Enure relayer is trusted.
        require(trustedRelayers[msg.sender], "Unauthorized relayer.");

        // Add the VAA to processed messages, so it can't be replayed.
        processedMessages[vm.hash] = true;

        // The message content can now be trusted.
        (bytes memory srcAddress,, bytes memory toAddressBytes, uint256 amount) =
            abi.decode(vm.payload, (bytes, uint16, bytes, uint256));

        (address toAddress) = abi.decode(toAddressBytes, (address));

        receiveMessage(vm.emitterChainId, srcAddress, toAddress, amount);
    }

    /// @dev Abstract function: it's overriden in OERC20.sol
    function receiveMessage(uint16 _srcChainId, bytes memory _srcAddress, address toAddress, uint256 amount)
        internal
        virtual;

    /* ****************************************************************************
    **
    **  Admin Functions
    **
    ******************************************************************************/

    function manageTrustedContracts(bytes32 _contract, bool _isTrusted) public onlyOwner {
        trustedContracts[_contract] = _isTrusted;

        if (!_isTrusted) {
            for (uint256 i; i < trustedContractsList.length; i++) {
                if (trustedContractsList[i] == _contract) {
                    trustedContractsList[i] = trustedContractsList[trustedContractsList.length - 1];
                    trustedContractsList.pop();
                    break;
                }
            }
        } else {
            trustedContractsList.push(_contract);
        }
    }

    function manageTrustedRelayers(address _relayer, bool _isTrusted) public onlyOwner {
        trustedRelayers[_relayer] = _isTrusted;

        if (!_isTrusted) {
            for (uint256 i; i < trustedRelayersList.length; i++) {
                if (trustedRelayersList[i] == _relayer) {
                    trustedRelayersList[i] = trustedRelayersList[trustedRelayersList.length - 1];
                    trustedRelayersList.pop();
                    break;
                }
            }
        } else {
            trustedRelayersList.push(_relayer);
        }
    }

    function getTrustedContracts() public view onlyOwner returns (bytes32[] memory) {
        return trustedContractsList;
    }

    function getTrustedRelayers() public view onlyOwner returns (address[] memory) {
        return trustedRelayersList;
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage slots in the inheritance chain.
     * Storage slot management is necessary, as we're using an upgradable proxy contract.
     * For details, see: https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[50] private __gap;
}
