// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0;

import "solmate/utils/SafeTransferLib.sol";
import "../utils/Ownable.sol";
import "../interfaces/IWormhole.sol";
import "../../common/interfaces/IUSX.sol";

contract WormholeBridge is Ownable {
    IWormhole public immutable wormholeCoreBridge; // no SLOAD
    address public immutable usx; // no SLOAD

    mapping(uint16 => uint256) public sendFeeLookup;
    mapping(bytes32 => bool) public trustedContracts;
    mapping(address => bool) public trustedRelayers;
    mapping(bytes32 => bool) public processedMessages;
    bytes32[] private trustedContractsList;
    address[] private trustedRelayersList;

    // Events
    event SendToChain(uint16 indexed _dstChainId, address indexed _from, bytes indexed _toAddress, uint256 _amount);
    event ReceiveFromChain(
        uint16 indexed _srcChainId, bytes indexed _srcAddress, address indexed _toAddress, uint256 _amount
    );

    constructor(address _wormholeCoreBridge, address _usx) {
        wormholeCoreBridge = IWormhole(_wormholeCoreBridge);
        usx = _usx;
    }

    function sendMessage(address payable _from, uint16 _dstChainId, bytes memory _toAddress, uint256 _amount)
        external
        payable
        returns (uint64 sequence)
    {
        require(msg.sender == usx, "Unauthorized.");
        require(msg.value >= sendFeeLookup[_dstChainId], "Not enough native token for gas.");

        sequence = _publishMessage(_from, _dstChainId, _toAddress, _amount);

        emit SendToChain(_dstChainId, _from, _toAddress, _amount);
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

        address toAddress;
        assembly {
            toAddress := mload(add(toAddressBytes, 20))
        }

        // Event
        emit ReceiveFromChain(vm.emitterChainId, srcAddress, toAddress, amount);

        // Needs admin privlieges on USX
        IUSX(usx).mint(toAddress, amount);
    }

    /* ****************************************************************************
    **
    **  Admin Functions
    **
    ******************************************************************************/

    /**
     * @dev This function allows contract admins to manage trustworthiness of remote emitter contracts.
     * @param _contract A remote emitter contract.
     * @param _isTrusted True, if trusted. False, if untrusted.
     */
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

    /**
     * @dev This function allows contract admins to manage trustworthiness of relayers.
     * @param _relayer The address of the relayer.
     * @param _isTrusted True, if trusted. False, if untrusted.
     */
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

    /**
     * @dev This function allows contract admins to retreive trusted, remote emitter contracts.
     */
    function getTrustedContracts() public view onlyOwner returns (bytes32[] memory) {
        return trustedContractsList;
    }

    /**
     * @dev This function allows contract admins retreive trusted relayers.
     */
    function getTrustedRelayers() public view onlyOwner returns (address[] memory) {
        return trustedRelayersList;
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
     * @dev This function allows contract admins to extract this contract's native tokens.
     */
    function extractNative() public onlyOwner {
        payable(msg.sender).transfer(address(this).balance);
    }

    /**
     * @dev This function allows contract admins to update send fees.
     * @param _destChainIds an array of destination chain IDs; the order must match `_fees` array.
     * @param _fees an array of destination fees; the order must match `_destChainIds` array. Any
     *              element with a value of zero will not get updated (allows for gas saving optionality).
     */
    function setSendFees(uint16[] memory _destChainIds, uint256[] memory _fees) public onlyOwner {
        for (uint256 i = 0; i < _destChainIds.length; i++) {
            if (_fees[i] != 0) {
                sendFeeLookup[_destChainIds[i]] = _fees[i];
            }
        }
    }
}
