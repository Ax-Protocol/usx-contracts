// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0;

import "./layer_zero/LayerZero.sol";
import "../interfaces/IOERC20.sol";
import "../introspection/ERC165.sol";
import "../token/UERC20.sol";
import "../admin/Privileged.sol";



abstract contract OERC20 is IOERC20, LayerZero, ERC165, UERC20, Privileged {

    enum BridgingProtocols { WORMHOLE, LAYER_ZERO }
    
    // NOTE: clean
    function sendFrom(
        uint8 _bridgeId,
        address _from,
        uint16 _dstChainId,
        bytes memory _toAddress,
        uint256 _amount,
        address payable _refundAddress
    ) public payable virtual override {
        if (paused) {
            revert Paused();
        }

        _debitFrom(_from, _dstChainId, _toAddress, _amount);
        
        if (_bridgeId == uint8(BridgingProtocols.WORMHOLE)) {
            // Send using Wormhole
        } else if (_bridgeId == uint8(BridgingProtocols.LAYER_ZERO)) {
            _send(_from, _dstChainId, _toAddress, _amount, _refundAddress, address(0), bytes(""));
        }

        emit SendToChain(_dstChainId, _from, _toAddress, _amount);
    }

    // NOTE: clean
    function supportsInterface(bytes4 interfaceId) public view virtual override (ERC165, IERC165) returns (bool) {
        return interfaceId == type(IOERC20).interfaceId || interfaceId == type(IERC20).interfaceId
            || super.supportsInterface(interfaceId);
    }

    // NOTE: clean
    function circulatingSupply() public view virtual override returns (uint256) {
        return totalSupply;
    }


    // NOTE: clean
    function receiveMessage(uint16 _srcChainId, bytes memory _srcAddress, address toAddress, uint256 amount) internal override {

        _creditTo(_srcChainId, toAddress, amount);

        emit ReceiveFromChain(_srcChainId, _srcAddress, toAddress, amount);
    }
    
    // NOTE: clean
    /**
     * @dev Updates `owner`'s allowance for `spender` based on spent `amount`.
     * Does not update the allowance amount in case of infinite allowance.
     * Might emit an {Approval} event.
     */
    function _spendAllowance(address owner, address spender, uint256 amount) internal virtual {
        uint256 currentAllowance = allowance[owner][spender];
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "ERC20: insufficient allowance");
            unchecked {
                allowance[owner][spender] = currentAllowance - amount;
            }
        }
    }

    // NOTE: clean
    function _debitFrom(address _from, uint16, bytes memory, uint256 _amount) internal {
        address spender = _msgSender();
        if (_from != spender) {
            _spendAllowance(_from, spender, _amount);
        }
        _burn(_from, _amount);
    }
    
    // NOTE: clean
    function _creditTo(uint16, address _toAddress, uint256 _amount) internal {
        _mint(_toAddress, _amount);
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage slots in the inheritance chain.
     * Storage slot management is necessary, as we're using an upgradable proxy contract.
     * For details, see: https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[50] private __gap;
}
