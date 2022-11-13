// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

import "./interfaces/IStableSwap3Pool.sol";
import "./proxy/UUPSUpgradeable.sol";
import "./interfaces/IERC20.sol";
import "./utils/Ownable.sol";
import "./interfaces/IUSX.sol";
import "./interfaces/ITreasury.sol";

contract Treasury is Ownable, UUPSUpgradeable, ITreasury {
    struct SupportedStable {
        bool supported;
        int128 curveIndex;
    }

    // Storage Variables
    address public usxToken;
    address public stableSwap3PoolAddress;
    address public curveToken;
    mapping(address => SupportedStable) public supportedStables;

    // Events
    event Mint(address indexed account, uint256 amount);
    event Redemption(address indexed account, uint256 amount);

    function initialize(address _stableSwap3PoolAddress, address _usxToken, address _curveToken) public initializer {
        __Ownable_init();
        stableSwap3PoolAddress = _stableSwap3PoolAddress;
        curveToken = _curveToken;
        usxToken = _usxToken;
    }

    // @dev required by the UUPS module
    function _authorizeUpgrade(address) internal override onlyOwner {}

    /**
     * @dev This function deposits any one of the supported stable coins to Curve, such that it
     *        receives 3CRV tokens in exchange.
     * @param _stable The address of the stable coin to deposit.
     * @param _amount The amount of the selected stable coin to deposit.
     */
    function mint(address _stable, uint256 _amount) public {
        require(supportedStables[_stable].supported || _stable == curveToken, "Unsupported stable.");

        // Obtain user's stablecoins
        IERC20(_stable).transferFrom(msg.sender, address(this), _amount);

        uint256 mintAmount;
        if (_stable != curveToken) {
            // Approve Curve to spend those newly obtained tokens
            IERC20(_stable).approve(stableSwap3PoolAddress, _amount);

            // Add liquidity to Curve
            uint256[3] memory amounts;
            amounts[uint256(uint128(supportedStables[_stable].curveIndex))] = _amount;
            mintAmount = IStableSwap3Pool(stableSwap3PoolAddress).add_liquidity(amounts, 0);
        } else {
            mintAmount = _amount;
        }

        // Mint USX tokens
        IUSX(usxToken).mint(msg.sender, mintAmount);
        emit Mint(msg.sender, mintAmount);
    }

    /**
     * @dev This function facilitates redeeming a single, supported stablecoin, in
     *         exchange for USX tokens.
     * @param _stable The address of the coin to withdraw.
     * @param _amount The amount of USX tokens to burn upon redemption.
     */
    function redeem(address _stable, uint256 _amount) public {
        require(supportedStables[_stable].supported || _stable == curveToken, "Unsupported stable.");

        uint256 redeemAmount;
        if (_stable != curveToken) {
            redeemAmount = IStableSwap3Pool(stableSwap3PoolAddress).remove_liquidity_one_coin(
                _amount, supportedStables[_stable].curveIndex, 0
            );
        } else {
            redeemAmount = _amount;
        }

        // Transfer desired redemption tokens to user
        IERC20(_stable).transfer(msg.sender, redeemAmount);

        // Burn USX tokens
        IUSX(usxToken).burn(msg.sender, _amount);
        emit Redemption(msg.sender, _amount);
    }

    function addSupportedStable(address _stable, int128 _curveIndex) public onlyOwner {
        supportedStables[_stable] = SupportedStable(true, _curveIndex);
    }

    function removeSupportedStable(address _stable) public onlyOwner {
        delete supportedStables[_stable];
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     */
    uint256[50] private __gap;
}
