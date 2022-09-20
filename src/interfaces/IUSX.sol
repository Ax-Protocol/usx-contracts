// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.8.0;

import "./IERC20Metadata.sol";
import "./IERC1822.sol";
import "./IOERC20.sol";

interface IUSX is IOERC20, IERC1822Proxiable {
    function mint(uint256 amount) external;

    function burn(uint256 amount) external;
}
