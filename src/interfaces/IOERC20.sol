// SPDX-License-Identifier: MIT

pragma solidity ^0.8.2;

import "./IERC165.sol";
import "./IERC20Metadata.sol";

/**
 * @dev Interface of the Omnichain ERC20 standard
 */
interface IOERC20 is IERC165, IERC20Metadata {
    /**
     * @dev estimate send token `_tokenId` to (`_dstChainId`, `_toAddress`)
     * @param _dstChainId - L0 defined chain id to send tokens too
     * @param _toAddress - dynamic bytes array which contains the address to whom you are sending tokens to on the dstChain
     * @param _amount - amount of the tokens to transfer
     */
    function estimateTransferFee(uint16 _dstChainId, bytes calldata _toAddress, uint256 _amount)
        external
        view
        returns (uint256 nativeFee);

    /**
     * @dev send _amount amount of token to (`_dstChainId`, `_toAddress`) from `_from`
     * @param _bridgeId - the Ax-assigned bridge ID, which dictates the message passing protocol to use
     * @param _from - the owner of token
     * @param _dstChainId - the destination chain identifier
     * @param _toAddress - can be any size depending on the `dstChainId`
     * @param _amount - the quantity of tokens in wei
     * @param _refundAddress the address LayerZero refunds if too much message fee is sent
     */
    function sendFrom(
        uint8 _bridgeId,
        address _from,
        uint16 _dstChainId,
        bytes memory _toAddress,
        uint256 _amount,
        address payable _refundAddress
    ) external payable;

    /**
     * @dev returns the circulating amount of tokens on current chain
     */
    function circulatingSupply() external view returns (uint256);

    /**
     * @dev Emitted when `_amount` tokens are moved from the `_sender` to (`_dstChainId`, `_toAddress`)
     * `_nonce` is the outbound nonce
     */
    event SendToChain(uint16 indexed _dstChainId, address indexed _from, bytes indexed _toAddress, uint256 _amount);

    /**
     * @dev Emitted when `_amount` tokens are received from `_srcChainId` into the `_toAddress` on the local chain.
     * `_nonce` is the inbound nonce.
     */
    event ReceiveFromChain(
        uint16 indexed _srcChainId, bytes indexed _srcAddress, address indexed _toAddress, uint256 _amount
    );
}
