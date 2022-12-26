// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

// Contracts
import "solmate/utils/SafeTransferLib.sol";
import "../proxy/UUPSUpgradeable.sol";
import "../common/utils/InitOwnable.sol";

// Interfaces
import "./interfaces/ICurve3Pool.sol";
import "./interfaces/IBooster.sol";
import "./interfaces/IBaseRewardPool.sol";
import "./interfaces/ICvxRewardPool.sol";
import "./interfaces/ICrvDepositor.sol";
import "./interfaces/ITreasury.sol";
import "../common/interfaces/IERC20.sol";
import "../common/interfaces/IUSXAdmin.sol";

contract Treasury is InitOwnable, UUPSUpgradeable, ITreasury {
    // Constants: no SLOAD to save gas
    address public constant backingToken = 0x6c3F90f043a72FA612cbac8115EE7e52BDe6E490; // 3CRV
    address public constant curve3Pool = 0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7;
    address public constant crv = 0xD533a949740bb3306d119CC777fa900bA034cd52;
    address public constant cvx = 0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B;
    address public constant cvxCrv = 0x62B9c7356A2Dc64a1969e19C23e4f579F9810Aa7;
    address public constant booster = 0xF403C135812408BFbE8713b5A23a04b3D48AAE31;
    address public constant crvDepositor = 0x8014595F2AB54cD7c604B00E9fb932176fDc86Ae;
    address public constant cvx3CrvBaseRewardPool = 0x689440f2Ff927E1f24c72F1087E1FAF471eCe1c8;
    address public constant cvxCrvBaseRewardPool = 0x3Fe65692bfCD0e6CF84cB1E7d24108E434A7587e;
    address public constant cvxRewardPool = 0xCF50b810E57Ac33B91dCF525C6ddd9881B139332;
    uint8 public constant PID_3POOL = 9;

    // Storage Variables: follow storage slot restrictions
    struct SupportedStable {
        bool supported;
        int128 curveIndex;
    }

    mapping(address => SupportedStable) public supportedStables;
    address public usx;
    uint256 public previousLpTokenPrice;
    uint256 public totalSupply;

    // Events
    event Mint(address indexed account, uint256 amount);
    event Redemption(address indexed account, uint256 amount);

    function initialize(address _usx) public initializer {
        /// @dev No constructor, so initialize Ownable explicitly.
        __Ownable_init();
        usx = _usx;
    }

    /// @dev Required by the UUPS module.
    function _authorizeUpgrade(address) internal override onlyOwner {}

    /**
     * @dev This function deposits any one of the supported stablecoins to Curve,
     * receives 3CRV tokens in exchange, and mints the USX token, such that it's
     * valued at approximately one US dollar.
     * @param _stable The address of the input token used to mint USX.
     * @param _amount The amount of the input token used to mint USX.
     */
    function mint(address _stable, uint256 _amount) public {
        require(supportedStables[_stable].supported || _stable == backingToken, "Unsupported stable.");

        SafeTransferLib.safeTransferFrom(ERC20(_stable), msg.sender, address(this), _amount);

        uint256 lpTokenAmount;
        if (_stable != backingToken) {
            lpTokenAmount = __provideLiquidity(_stable, _amount);
        } else {
            lpTokenAmount = _amount;
        }

        __stakeLpTokens(lpTokenAmount);

        uint256 mintAmount = __getMintAmount(lpTokenAmount);

        totalSupply += mintAmount;
        IUSXAdmin(usx).mint(msg.sender, mintAmount);
        emit Mint(msg.sender, mintAmount);
    }

    /**
     * @dev This function facilitates redeeming a single supported stablecoin, in
     * exchange for USX tokens, such that USX is valued at approximately one US dollar.
     * @param _stable The address of the token to withdraw.
     * @param _amount The amount of USX tokens to burn upon redemption.
     */
    function redeem(address _stable, uint256 _amount) public {
        require(supportedStables[_stable].supported || _stable == backingToken, "Unsupported stable.");

        uint256 lpTokenAmount = __getLpTokenAmount(_amount);

        __unstakeLpTokens(lpTokenAmount);

        uint256 redeemAmount;
        if (_stable != backingToken) {
            redeemAmount = __removeLiquidity(_stable, lpTokenAmount);
        } else {
            redeemAmount = lpTokenAmount;
        }

        SafeTransferLib.safeTransfer(ERC20(_stable), msg.sender, redeemAmount);

        totalSupply -= _amount;
        IUSXAdmin(usx).burn(msg.sender, _amount);
        emit Redemption(msg.sender, _amount);
    }

    function __provideLiquidity(address _stable, uint256 _amount) private returns (uint256 lpTokenAmount) {
        // Obtain contract's LP token balance before adding liquidity
        uint256 preBalance = IERC20(backingToken).balanceOf(address(this));

        // Add liquidity to Curve
        SafeTransferLib.safeApprove(ERC20(_stable), curve3Pool, _amount);
        uint256[3] memory amounts;
        amounts[uint256(uint128(supportedStables[_stable].curveIndex))] = _amount;
        ICurve3Pool(curve3Pool).add_liquidity(amounts, 0);

        // Calculate the amount of LP tokens received from adding liquidity
        lpTokenAmount = IERC20(backingToken).balanceOf(address(this)) - preBalance;
    }

    function __removeLiquidity(address _stable, uint256 _lpTokenAmount) private returns (uint256 redeemAmount) {
        // Obtain contract's withdrawal token balance before removing liquidity
        uint256 preBalance = IERC20(_stable).balanceOf(address(this));

        // Remove liquidity from Curve
        ICurve3Pool(curve3Pool).remove_liquidity_one_coin(_lpTokenAmount, supportedStables[_stable].curveIndex, 0);

        // Calculate the amount of stablecoin received from removing liquidity
        redeemAmount = IERC20(_stable).balanceOf(address(this)) - preBalance;
    }

    function __stakeLpTokens(uint256 _amount) private {
        // Approve Booster to spend Treasury's 3CRV
        SafeTransferLib.safeApprove(ERC20(backingToken), booster, _amount);

        // Deposit 3CRV into Booster and have it stake cvx3CRV into BaseRewardPool on Treasury's behalf
        IBooster(booster).deposit(PID_3POOL, _amount, true);
    }

    function __unstakeLpTokens(uint256 _amount) private {
        // Unstake cvx3CRV, unwrap it into 3RCV, and claim all rewards
        IBaseRewardPool(cvx3CrvBaseRewardPool).withdrawAndUnwrap(_amount, true);
    }

    function __getMintAmount(uint256 _lpTokenAmount) private returns (uint256 mintAmount) {
        uint256 lpTokenPrice = ICurve3Pool(curve3Pool).get_virtual_price();

        // Don't allow LP token price to decrease
        if (lpTokenPrice < previousLpTokenPrice) {
            lpTokenPrice = previousLpTokenPrice;
        } else {
            previousLpTokenPrice = lpTokenPrice;
        }

        mintAmount = (_lpTokenAmount * lpTokenPrice) / 1e18;
    }

    function __getLpTokenAmount(uint256 _amount) private returns (uint256 lpTokenAmount) {
        uint256 lpTokenPrice = ICurve3Pool(curve3Pool).get_virtual_price();

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
     * @dev Allow contract admins to add supported stablecoins.
     * @param _stable The address of stablecoin to add.
     * @param _curveIndex The stablecoin's Curve-assigned index.
     */
    function addSupportedStable(address _stable, int128 _curveIndex) public onlyOwner {
        supportedStables[_stable] = SupportedStable(true, _curveIndex);
    }

    /**
     * @dev Allow contract admins to remove supported stablecoins.
     * @param _stable The address of stablecoin to remove.
     */
    function removeSupportedStable(address _stable) public onlyOwner {
        delete supportedStables[_stable];
    }

    /**
     * @dev Allow contract admins to swap the backing token to a supported stable, in an emergency.
     */
    function emergencySwapBacking(address _newBackingToken) public onlyOwner {
        require(supportedStables[_newBackingToken].supported, "Token not supported.");

        // Withdraw all staked 3CRV
        uint256 totalStaked = IBaseRewardPool(cvx3CrvBaseRewardPool).balanceOf(address(this));
        __unstakeLpTokens(totalStaked);

        // Remove liquidity from Curve, receiving _newBackingToken
        ICurve3Pool(curve3Pool).remove_liquidity_one_coin(totalStaked, supportedStables[_newBackingToken].curveIndex, 0);

        // Pause minting and redeeming
        IUSXAdmin(usx).treasuryKillSwitch();

        // This contract is now backed by _newBackingToken, but backingToken was not updated, because it's a constant.
        // Admins may need to update backingToken via proxy upgrade, depending on the post-emergency-swap resolution.
    }

    /**
     * @dev Allow contract admins to extract any non-backing ERC20 token.
     * @param _token The address of token to remove.
     */
    function extractERC20(address _token) public onlyOwner {
        uint256 balance = IERC20(_token).balanceOf(address(this));

        SafeTransferLib.safeTransfer(ERC20(_token), msg.sender, balance);
    }

    /**
     * @dev Allow contract admins to stake CVX into cvxRewardPool contract. This will
     * accumulate cvxCRV rewards proportionate to the amount staked.
     * @param _amount The amount of CVX to stake.
     */
    function stakeCvx(uint256 _amount) public onlyOwner {
        uint256 balance = IERC20(cvx).balanceOf(address(this));

        require(balance > 0 && balance >= _amount, "Insufficient CVX balance.");

        SafeTransferLib.safeApprove(ERC20(cvx), cvxRewardPool, _amount);

        ICvxRewardPool(cvxRewardPool).stake(_amount);
    }

    /**
     * @dev Allow contract admins to withdraw CVX from cvxRewardPool contract and claim all
     * unclaimed cvxCRV rewards.
     * @param _amount The amount of CVX to withdraw.
     */
    function unstakeCvx(uint256 _amount) public onlyOwner {
        uint256 stakedAmount = ICvxRewardPool(cvxRewardPool).balanceOf(address(this));

        require(stakedAmount > 0 && stakedAmount >= _amount, "Amount exceeds staked balance.");

        ICvxRewardPool(cvxRewardPool).withdraw(_amount, true);
    }

    /**
     * @dev Allow contract admins to claim all unclaimed cvxCRV rewards from cvxRewardPool contract.
     * @param _stake If true, all claimed cvxCRV rewards will be staked into cvxCrvBaseRewardPool.
     */
    function claimRewardCvx(bool _stake) public onlyOwner {
        require(ICvxRewardPool(cvxRewardPool).earned(address(this)) > 0, "No rewards to claim.");

        ICvxRewardPool(cvxRewardPool).getReward(_stake);
    }

    /**
     * @dev Allow contract admins to deposit CRV into CrvDepositor, convert it to cvxCRV, and stake the
     * corresponding cvxCRV into cvxCrvBaseRewardPool. This will accumulate CVX, CRV, and 3CRV
     * rewards proportionate to the amount staked.
     * @param _amount The amount of CRV to deposit, convert, and stake.
     */
    function stakeCrv(uint256 _amount) public onlyOwner {
        require(IERC20(crv).balanceOf(address(this)) >= _amount, "Insufficient CRV balance.");

        SafeTransferLib.safeApprove(ERC20(crv), crvDepositor, _amount);

        ICrvDepositor(crvDepositor).deposit(_amount, true, cvxCrvBaseRewardPool);
    }

    /**
     * @dev Allow contract admins to withdraw cvxCRV from cvxCrvBaseRewardPool and claim all
     * unclaimed CVX, CRV, and 3CRV rewards.
     * @param _amount The amount of cvxCRV to withdraw.
     */
    function unstakeCvxCrv(uint256 _amount) public onlyOwner {
        uint256 stakedAmount = IBaseRewardPool(cvxCrvBaseRewardPool).balanceOf(address(this));

        require(stakedAmount > 0 && stakedAmount >= _amount, "Amount exceeds staked balance.");

        IBaseRewardPool(cvxCrvBaseRewardPool).withdraw(_amount, true);
    }

    /**
     * @dev Allow contract admins to claim all unclaimed CVX, CRV, and 3CRV rewards from cvxCrvBaseRewardPool.
     */
    function claimRewardCvxCrv() public onlyOwner {
        require(IBaseRewardPool(cvxCrvBaseRewardPool).earned(address(this)) > 0, "No rewards to claim.");

        IBaseRewardPool(cvxCrvBaseRewardPool).getReward();
    }

    /**
     * @dev Allow contract admins to deposit 3CRV into Booster, convert it to cvx3CRV, and
     * stake the corresponding cvx3CRV into cvx3CrvBaseRewardPool. This will accumulate
     * CVX and CRV rewards proportionate to the amount staked.
     * @param _amount The amount of 3CRV to deposit, convert, and stake.
     */
    function stake3Crv(uint256 _amount) public onlyOwner {
        uint256 balance = IERC20(backingToken).balanceOf(address(this));

        require(balance > 0 && balance >= _amount, "Insufficient 3CRV balance.");

        __stakeLpTokens(_amount);
    }

    /**
     * @dev Allow contract admins to withdraw cvx3CRV from cvx3CrvBaseRewardPool, unwrap it into 3CRV,
     * and claim all unclaimed CVX and CRV rewards.
     * @param _amount The amount of cvx3CRV to withdraw.
     */
    function unstake3Crv(uint256 _amount) public onlyOwner {
        uint256 balanceCvx3Crv = IBaseRewardPool(cvx3CrvBaseRewardPool).balanceOf(address(this));
        uint256 backingAmount = __getLpTokenAmount(totalSupply);

        require(_amount <= balanceCvx3Crv - backingAmount, "Cannot withdraw backing cvx3CRV.");

        __unstakeLpTokens(_amount);
    }

    /**
     * @dev Allow contract admins to claim all unclaimed CVX and CRV rewards from cvx3CrvBaseRewardPool.
     */
    function claimRewardCvx3Crv() public onlyOwner {
        require(IBaseRewardPool(cvx3CrvBaseRewardPool).earned(address(this)) > 0, "No rewards to claim.");

        IBaseRewardPool(cvx3CrvBaseRewardPool).getReward();
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage slots in the inheritance chain.
     * Storage slot management is necessary, as we're using an upgradable proxy contract.
     * For details, see: https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[50] private __gap;
}
