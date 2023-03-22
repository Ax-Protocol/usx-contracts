// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0;

import { IERC20 } from "./IERC20.sol";

/**
 * @dev Extends IERC20 to include permit functionality
 */
interface IUERC20 is IERC20 {
    /**
     * @dev nonces is mapping given for replay protection.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     */
    function nonces(address owner) external returns (uint256);

    /**
     * @dev Hash of a structed defined in EIP-712; it's used for replay protection.
     *
     * Returns the hash.
     */
    function DOMAIN_SEPARATOR() external returns (bytes32);

    /**
     * @dev Allows abstraction of ERC-20 approval method.
     */
    function permit(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s)
        external;
}
