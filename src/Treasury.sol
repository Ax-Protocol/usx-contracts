// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "solmate/utils/SafeTransferLib.sol";
import "./interfaces/IStableSwap3Pool.sol";
import "./interfaces/ILiquidityGauge.sol";
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
    address public liquidityGaugeAddress;
    address public backingToken;
    mapping(address => SupportedStable) public supportedStables;
    uint256 public previousLpTokenPrice;

    // Events
    event Mint(address indexed account, uint256 amount);
    event Redemption(address indexed account, uint256 amount);

    function initialize(address _stableSwap3PoolAddress, address _liquidityGaugeAddress, address _usxToken, address _backingToken) public initializer {
        __Ownable_init();
        /// @dev No constructor, so initialize Ownable explicitly.
        stableSwap3PoolAddress = _stableSwap3PoolAddress;
        liquidityGaugeAddress= _liquidityGaugeAddress;
        backingToken = _backingToken;
        usxToken = _usxToken;
    }

    /// @dev Required by the UUPS module.
    function _authorizeUpgrade(address) internal override onlyOwner {}

    /**
     * @dev This function deposits any one of the supported stable coins to Curve,
     *      receives 3CRV tokens in exchange, and mints the USX token, such that
     *      it's valued at a dollar.
     * @param _stable The address of the input token used to mint USX.
     * @param _amount The amount of the input token used to mint USX.
     */
    function mint(address _stable, uint256 _amount) public {
        require(supportedStables[_stable].supported || _stable == backingToken, "Unsupported stable.");

        // Obtain user's input tokens
        SafeTransferLib.safeTransferFrom(ERC20(_stable), msg.sender, address(this), _amount);

        uint256 lpTokenAmount;
        if (_stable != backingToken) {
            // Obtain contract's LP token balance before adding liquidity
            uint256 preBalance = IERC20(backingToken).balanceOf(address(this));

            // Add liquidity to Curve
            SafeTransferLib.safeApprove(ERC20(_stable), stableSwap3PoolAddress, _amount);
            uint256[3] memory amounts;
            amounts[uint256(uint128(supportedStables[_stable].curveIndex))] = _amount;
            IStableSwap3Pool(stableSwap3PoolAddress).add_liquidity(amounts, 0);

            // Calculate the amount of LP tokens received from adding liquidity
            lpTokenAmount = IERC20(backingToken).balanceOf(address(this)) - preBalance;
        } else {
            lpTokenAmount = _amount;
        }

        // Stake LP tokens
        stakeLpTokens(lpTokenAmount);

        // Mint USX
        uint256 mintAmount = getMintAmount(lpTokenAmount);
        IUSX(usxToken).mint(msg.sender, mintAmount);
        emit Mint(msg.sender, mintAmount);
    }

    /**
     * @dev This function facilitates redeeming a single supported stablecoin, in
     *      exchange for USX tokens, such that USX is valued at a dollar.
     * @param _stable The address of the token to withdraw.
     * @param _amount The amount of USX tokens to burn upon redemption.
     */
    function redeem(address _stable, uint256 _amount) public {
        require(supportedStables[_stable].supported || _stable == backingToken, "Unsupported stable.");

        // Get amount of LP token based on USX burn amount
        uint256 lpTokenAmount = getLpTokenAmount(_amount);

        // Unstake LP tokens
        unstakeLpTokens(lpTokenAmount);

        uint256 redeemAmount;
        if (_stable != backingToken) {
            // Obtain contract's withdrawal token balance before removing liquidity
            uint256 preBalance = IERC20(_stable).balanceOf(address(this));

            // Remove liquidity from Curve
            IStableSwap3Pool(stableSwap3PoolAddress).remove_liquidity_one_coin(
                lpTokenAmount, supportedStables[_stable].curveIndex, 0
            );

            // Calculate the amount of stablecoin received from removing liquidity
            redeemAmount = IERC20(_stable).balanceOf(address(this)) - preBalance;
        } else {
            redeemAmount = lpTokenAmount;
        }

        // Transfer desired withdrawal tokens to user
        SafeTransferLib.safeTransfer(ERC20(_stable), msg.sender, redeemAmount);

        // Burn USX tokens
        IUSX(usxToken).burn(msg.sender, _amount);
        emit Redemption(msg.sender, _amount);
    }

    function stakeLpTokens(uint256 _amount) private {
        // Approve LiquidityGauge to spend Treasury's 3CRV
        IERC20(backingToken).approve(liquidityGaugeAddress, _amount);

        // Deposit 3CRV into LiquidityGauge
        ILiquidityGauge(liquidityGaugeAddress).deposit(_amount);
    }

    function unstakeLpTokens(uint256 _amount) private {
        // Withdraw 3CRV from LiquidityGauge
        ILiquidityGauge(liquidityGaugeAddress).withdraw(_amount);
    }

    function getMintAmount(uint256 _lpTokenAmount) private returns (uint256 mintAmount) {
        uint256 lpTokenPrice = IStableSwap3Pool(stableSwap3PoolAddress).get_virtual_price();

        // Don't allow LP token price to decrease
        if (lpTokenPrice < previousLpTokenPrice) {
            lpTokenPrice = previousLpTokenPrice;
        } else {
            previousLpTokenPrice = lpTokenPrice;
        }

        mintAmount = (_lpTokenAmount * lpTokenPrice) / 1e18;
    }

    function getLpTokenAmount(uint256 _amount) private returns (uint256 lpTokenAmount) {
        uint256 lpTokenPrice = IStableSwap3Pool(stableSwap3PoolAddress).get_virtual_price();

        // Don't allow LP token price to decrease
        if (lpTokenPrice < previousLpTokenPrice) {
            lpTokenPrice = previousLpTokenPrice;
        } else {
            previousLpTokenPrice = lpTokenPrice;
        }

        uint256 conversionFactor = (1e18 * 1e18 / lpTokenPrice);
        lpTokenAmount = (_amount * conversionFactor) / 1e18;
    } 

    /* ****************************************************************************
    **
    **  Admin Functions
    **
    ******************************************************************************/

    /**
     * @dev This function allows contract admins to add supported stablecoins.
     * @param _stable The address of stablecoin to add.
     * @param _curveIndex The stablecoin's Curve-assigned index.
     */
    function addSupportedStable(address _stable, int128 _curveIndex) public onlyOwner {
        supportedStables[_stable] = SupportedStable(true, _curveIndex);
    }

    /**
     * @dev This function allows contract admins to remove supported stablecoins.
     * @param _stable The address of stablecoin to remove.
     */
    function removeSupportedStable(address _stable) public onlyOwner {
        delete supportedStables[_stable];
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage slots in the inheritance chain.
     * Storage slot management is necessary, as we're using an upgradable proxy contract.
     * For details, see: https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[50] private __gap;
}
