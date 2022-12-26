// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0;

import "solmate/utils/SafeTransferLib.sol";
import "./lz_app/NonBlockingLzApp.sol";
import "../../common/interfaces/IUSX.sol";

contract LayerZeroBridge is NonBlockingLzApp {
    uint256 public constant NO_EXTRA_GAS = 0; // no SLOAD
    uint256 public constant FUNCTION_TYPE_SEND = 1; // no SLOAD
    bool public useCustomAdapterParams;

    address public immutable usx; // no SLOAD

    // Events
    event SendToChain(uint16 indexed _dstChainId, address indexed _from, bytes indexed _toAddress, uint256 _amount);
    event ReceiveFromChain(
        uint16 indexed _srcChainId, bytes indexed _srcAddress, address indexed _toAddress, uint256 _amount
    );
    event SetUseCustomAdapterParams(bool _useCustomAdapterParams);

    constructor(address _lzEndpoint, address _usx) NonBlockingLzApp(_lzEndpoint) {
        usx = _usx;
    }

    function sendMessage(address payable _from, uint16 _dstChainId, bytes memory _toAddress, uint256 _amount)
        external
        payable
        returns (uint64 sequence)
    {
        require(msg.sender == usx, "Unauthorized.");
        _send(_from, _dstChainId, _toAddress, _amount, address(0), bytes(""));

        emit SendToChain(_dstChainId, _from, _toAddress, _amount);

        sequence = 0;
    }

    function _send(
        address payable _from,
        uint16 _dstChainId,
        bytes memory _toAddress,
        uint256 _amount,
        address _zroPaymentAddress,
        bytes memory _adapterParams
    ) internal virtual {
        bytes memory payload = abi.encode(_toAddress, _amount);
        if (useCustomAdapterParams) {
            _checkGasLimit(_dstChainId, FUNCTION_TYPE_SEND, _adapterParams, NO_EXTRA_GAS);
        } else {
            require(_adapterParams.length == 0, "LzApp: _adapterParams must be empty.");
        }
        _lzSend(_dstChainId, payload, _from, _zroPaymentAddress, _adapterParams);
    }

    function _nonblockingLzReceive(
        uint16 _srcChainId,
        bytes memory _srcAddress,
        uint64, // _nonce
        bytes memory _payload
    ) internal virtual override {
        // decode and load toAddress
        (bytes memory toAddressBytes, uint256 amount) = abi.decode(_payload, (bytes, uint256));

        address toAddress;
        assembly {
            toAddress := mload(add(toAddressBytes, 20))
        }

        _receiveMessage(_srcChainId, _srcAddress, toAddress, amount);
    }

    function _receiveMessage(uint16 _srcChainId, bytes memory _srcAddress, address _toAddress, uint256 _amount)
        internal
        virtual
    {
        // Privileges needed
        IUSX(usx).mint(_toAddress, _amount);

        emit ReceiveFromChain(_srcChainId, _srcAddress, _toAddress, _amount);
    }

    /**
     * @dev Obtain gas estimate for cross-chain transfer.
     * @param _dstChainId The Layer Zero destination chain ID.
     * @param _toAddress The recipient address on the destination chain.
     * @param _amount The amount to be transferred across chains.
     */
    function estimateSendFee(uint16 _dstChainId, bytes memory _toAddress, uint256 _amount)
        public
        view
        virtual
        returns (uint256 nativeFee, uint256 zroFee)
    {
        // mock the payload for send()
        bytes memory payload = abi.encode(_toAddress, _amount);
        return lzEndpoint.estimateFees(_dstChainId, address(this), payload, false, bytes(""));
    }

    /* ****************************************************************************
    **
    **  Admin Functions
    **
    ******************************************************************************/

    /**
     * @dev This function allows contract admins to use custom adapter params.
     * @param _useCustomAdapterParams Whether or not to use custom adapter params.
     */
    function setUseCustomAdapterParams(bool _useCustomAdapterParams) external onlyOwner {
        useCustomAdapterParams = _useCustomAdapterParams;
        emit SetUseCustomAdapterParams(_useCustomAdapterParams);
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
}
