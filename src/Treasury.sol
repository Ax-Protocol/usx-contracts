// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "solmate/utils/SafeTransferLib.sol";
import "./interfaces/IStableSwap3Pool.sol";
import "./interfaces/IBooster.sol";
import "./interfaces/IBaseRewardPool.sol";
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
    uint8 public constant PID_3POOL = 9;  // TODO: Need to figure out the best place to put this, taking into account storage slotsß
    address public usxToken;
    address public stableSwap3PoolAddress;
    address public booster;
    address public baseRewardPool;
    address public backingToken;
    mapping(address => SupportedStable) public supportedStables;
    uint256 public previousLpTokenPrice;
    bool public backingSwapped;
    uint256 public totalSupply;

    // Events
    event Mint(address indexed account, uint256 amount);
    event Redemption(address indexed account, uint256 amount);

    function initialize(
        address _stableSwap3PoolAddress,
        address _booster,
        address _baseRewardPool,
        address _backingToken,
        address _usxToken
    ) public initializer {
        __Ownable_init();
        /// @dev No constructor, so initialize Ownable explicitly.
        stableSwap3PoolAddress = _stableSwap3PoolAddress;
        booster = _booster;
        baseRewardPool = _baseRewardPool;
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
        uint256 mintAmount;

        if (!backingSwapped) {
            require(supportedStables[_stable].supported || _stable == backingToken, "Unsupported stable.");

            SafeTransferLib.safeTransferFrom(ERC20(_stable), msg.sender, address(this), _amount);

            uint256 lpTokenAmount = __provideLiquidity(_stable, _amount);

            __stakeLpTokens(lpTokenAmount);

            mintAmount = __getMintAmount(lpTokenAmount);
        } else {
            require(_stable == backingToken, "Invalid _stable.");

            SafeTransferLib.safeTransferFrom(ERC20(_stable), msg.sender, address(this), _amount);

            mintAmount = _amount;
        }

        totalSupply += mintAmount;
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
        uint256 redeemAmount;

        if (!backingSwapped) {
            require(supportedStables[_stable].supported || _stable == backingToken, "Unsupported stable.");

            // Get amount of LP token based on USX burn amount
            uint256 lpTokenAmount = __getLpTokenAmount(_amount);

            // Unstake LP tokens
            __unstakeLpTokens(lpTokenAmount);

            // Remove liquidity from Curve
            redeemAmount = __removeLiquidity(_stable, lpTokenAmount);
        } else {
            require(_stable == backingToken, "Invalid _stable.");

            uint256 backingBalance = IERC20(_stable).balanceOf(address(this));
            redeemAmount = ((_amount * 1e36 / totalSupply) * backingBalance) / 1e36;
            require(redeemAmount > 0, "_amount is too small.");
        }

        // Transfer desired withdrawal tokens to user
        SafeTransferLib.safeTransfer(ERC20(_stable), msg.sender, redeemAmount);

        // Burn USX tokens
        totalSupply -= _amount;
        IUSX(usxToken).burn(msg.sender, _amount);
        emit Redemption(msg.sender, _amount);
    }

    function __provideLiquidity(address _stable, uint256 _amount) private returns (uint256 lpTokenAmount) {
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
    }

    function __removeLiquidity(address _stable, uint256 _lpTokenAmount) private returns (uint256 redeemAmount) {
        if (_stable != backingToken) {
            // Obtain contract's withdrawal token balance before removing liquidity
            uint256 preBalance = IERC20(_stable).balanceOf(address(this));

            // Remove liquidity from Curve
            IStableSwap3Pool(stableSwap3PoolAddress).remove_liquidity_one_coin(
                _lpTokenAmount, supportedStables[_stable].curveIndex, 0
            );

            // Calculate the amount of stablecoin received from removing liquidity
            redeemAmount = IERC20(_stable).balanceOf(address(this)) - preBalance;
        } else {
            redeemAmount = _lpTokenAmount;
        }
    }

    function __stakeLpTokens(uint256 _amount) private {
        // Approve Booster to spend Treasury's 3CRV
        IERC20(backingToken).approve(booster, _amount);

        // Deposit 3CRV into Booster and have it stake cvx3CRV into BaseRewardPool on Treasury's behalf
        IBooster(booster).deposit(PID_3POOL, _amount, true);
    }

    function __unstakeLpTokens(uint256 _amount) private {
        // Unstake cvx3CRV, unwrap it into 3RCV, and claim all rewards
        IBaseRewardPool(baseRewardPool).withdrawAndUnwrap(_amount, true);
    }

    function __getMintAmount(uint256 _lpTokenAmount) private returns (uint256 mintAmount) {
        uint256 lpTokenPrice = IStableSwap3Pool(stableSwap3PoolAddress).get_virtual_price();

        // Don't allow LP token price to decrease
        if (lpTokenPrice < previousLpTokenPrice) {
            lpTokenPrice = previousLpTokenPrice;
        } else {
            previousLpTokenPrice = lpTokenPrice;
        }

        mintAmount = (_lpTokenAmount * lpTokenPrice) / 1e18;
    }

    function __getLpTokenAmount(uint256 _amount) private returns (uint256 lpTokenAmount) {
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
     * @dev Allows contract admins to swap the backing token, in an emergency.
     * @param _newBackingToken The address of the new backing token.
     */
    function emergencySwapBacking(address _newBackingToken) public onlyOwner {
        require(supportedStables[_newBackingToken].supported, "Token not supported.");

        // 1. Withdraw all staked 3CRV
        uint256 totalStaked = IBaseRewardPool(baseRewardPool).balanceOf(address(this)); // TODO: Figure out if withdrawAllAndUnrwrap is cheaper than thisß

        __unstakeLpTokens(totalStaked);

        // 2. Remove liquidity from Curve, receiving _newBackingToken
        IStableSwap3Pool(stableSwap3PoolAddress).remove_liquidity_one_coin(
            totalStaked, supportedStables[_newBackingToken].curveIndex, 0
        );

        // 3. Update State
        backingToken = _newBackingToken;
        backingSwapped = true;
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage slots in the inheritance chain.
     * Storage slot management is necessary, as we're using an upgradable proxy contract.
     * For details, see: https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[50] private __gap;
}
