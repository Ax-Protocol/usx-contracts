// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "../common/Constants.t.sol";
import "./common/TestSetup.t.sol";
import "../../src/treasury/interfaces/ITreasuryAdmin.sol";
import "../../src/treasury/interfaces/ICvxMining.sol";
import "../../src/treasury/interfaces/IVirtualBalanceRewardPool.sol";

contract RewardsTest is FundingHelper {
    /// @dev Test that contract admins can stake CVX into CVX_REWARD_POOL contract.
    function test_stakeCvx(uint256 amount) public {
        // Assumptions
        vm.assume(amount > 1e12 && amount < 1e18 * 1e6);

        // Allocate funds for test
        deal(CVX, address(treasury_proxy), amount);

        // Pre-action assertions
        assertEq(
            IERC20(CVX).balanceOf(address(treasury_proxy)),
            amount,
            "Equivalence violation: treasury CVX balance and amount."
        );
        assertEq(
            ICvxRewardPool(CVX_REWARD_POOL).balanceOf(address(treasury_proxy)),
            0,
            "Equivalence violation: treasury staked CVX balance is not zero."
        );

        // Action
        ITreasuryAdmin(address(treasury_proxy)).stakeCvx(amount);

        // Post-action assertions
        assertEq(
            IERC20(CVX).balanceOf(address(treasury_proxy)),
            0,
            "Equivalence violation: treasury CVX balance is not zero."
        );
        assertEq(
            ICvxRewardPool(CVX_REWARD_POOL).balanceOf(address(treasury_proxy)),
            amount,
            "Equivalence violation: treasury staked CVX balance and amount."
        );
    }

    function testCannot_stakeCvx_unauthorized(address sender, uint256 amount) public {
        // Assumptions
        vm.assume(amount > 1e12 && amount < 1e18 * 1e6);
        vm.assume(sender != address(this));

        // Allocate funds for test
        deal(CVX, address(treasury_proxy), amount);

        // Exptectations
        vm.expectRevert("Ownable: caller is not the owner");

        // Act: pranking as other addresses
        vm.prank(sender);
        ITreasuryAdmin(address(treasury_proxy)).stakeCvx(amount);
    }

    function testCannot_stakeCvx_balance(uint256 balance, uint256 stakeAmount) public {
        // Assumptions
        vm.assume(balance > 1e12 && balance < 1e18 * 1e6);
        vm.assume(stakeAmount > balance);

        // Exptectations
        vm.expectRevert("Insufficient CVX balance.");

        // Act: treasury CVX balance is zero
        ITreasuryAdmin(address(treasury_proxy)).stakeCvx(stakeAmount);
    }

    /// @dev Test that contract admins can withdraw CVX principal from CVX_REWARD_POOL contract, and claim all unclaimed cvxCRV rewards.
    function test_unstakeCvx(uint256 amount) public {
        // Assumptions
        vm.assume(amount > 1e12 && amount < 1e18 * 1e6);

        // Allocate funds for test
        deal(CVX, address(treasury_proxy), amount);

        // Setup
        ITreasuryAdmin(address(treasury_proxy)).stakeCvx(amount);
        skip(ONE_WEEK);

        // Expectations
        uint256 expectedRewardAmount = ICvxRewardPool(CVX_REWARD_POOL).earned(address(treasury_proxy));

        // Pre-action assertions
        assertEq(
            IERC20(CVX).balanceOf(address(treasury_proxy)),
            0,
            "Equivalence violation: treasury CVX balance is not zero."
        );
        assertEq(
            IERC20(CVX_CRV).balanceOf(address(treasury_proxy)),
            0,
            "Equivalence violation: treasury cvxCRV balance is not zero."
        );
        assertEq(
            ICvxRewardPool(CVX_REWARD_POOL).balanceOf(address(treasury_proxy)),
            amount,
            "Equivalence violation: treasury staked CVX balance and amount."
        );

        // Act
        ITreasuryAdmin(address(treasury_proxy)).unstakeCvx(amount);

        // Post-action
        assertEq(
            IERC20(CVX).balanceOf(address(treasury_proxy)),
            amount,
            "Equivalence violation: treasury CVX balance and amount."
        );
        assertEq(
            IERC20(CVX_CRV).balanceOf(address(treasury_proxy)),
            expectedRewardAmount,
            "Equivalence violation: treasury cvxCRV balance and expectedRewardAmount."
        );
        assertEq(
            ICvxRewardPool(CVX_REWARD_POOL).balanceOf(address(treasury_proxy)),
            0,
            "Equivalence violation: treasury staked CVX balance is not zero."
        );
    }

    function testCannot_unstakeCvx_unauthorized(address sender, uint256 amount) public {
        // Assumptions
        vm.assume(amount > 1e12 && amount < 1e18 * 1e6);
        vm.assume(sender != address(this));

        // Allocate funds for test
        deal(CVX, address(treasury_proxy), amount);

        // Setup
        ITreasuryAdmin(address(treasury_proxy)).stakeCvx(amount);
        skip(ONE_WEEK);

        // Exptectations
        vm.expectRevert("Ownable: caller is not the owner");

        // Act: pranking as other addresses
        vm.prank(sender);
        ITreasuryAdmin(address(treasury_proxy)).unstakeCvx(amount);
    }

    function testCannot_unstakeCvx_balance(uint256 amount) public {
        // Assumptions
        vm.assume(amount > 1e12 && amount < 1e18 * 1e6);

        // Exptectations
        vm.expectRevert("Amount exceeds staked balance.");

        // Act: treasury staked CVX balance is zero
        ITreasuryAdmin(address(treasury_proxy)).unstakeCvx(amount);
    }

    /// @dev Test that contract admins can claim all unclaimed cvxCRV rewards from CVX_REWARD_POOL contract, and stake the cvxCRV rewards.
    function test_claimRewardCvx_and_stake(uint256 amount) public {
        // Assumptions
        vm.assume(amount > 1e12 && amount < 1e18 * 1e6);

        // Allocate funds for test
        deal(CVX, address(treasury_proxy), amount);

        // Setup
        ITreasuryAdmin(address(treasury_proxy)).stakeCvx(amount);
        skip(ONE_WEEK);

        // Expectations
        uint256 expectedRewardAmount = ICvxRewardPool(CVX_REWARD_POOL).earned(address(treasury_proxy));

        // Pre-action assertions
        assertEq(
            IERC20(CVX).balanceOf(address(treasury_proxy)),
            0,
            "Equivalence violation: treasury CVX balance is not zero."
        );
        assertEq(
            IERC20(CVX_CRV).balanceOf(address(treasury_proxy)),
            0,
            "Equivalence violation: treasury cvxCRV balance is not zero."
        );
        assertEq(
            ICvxRewardPool(CVX_REWARD_POOL).balanceOf(address(treasury_proxy)),
            amount,
            "Equivalence violation: treasury staked CVX balance and amount."
        );

        // Act
        ITreasuryAdmin(address(treasury_proxy)).claimRewardCvx(true);

        // Post-action assertions
        assertEq(
            IERC20(CVX).balanceOf(address(treasury_proxy)),
            0,
            "Equivalence violation: treasury CVX balance is not zero."
        );
        assertEq(
            IERC20(CVX_CRV).balanceOf(address(treasury_proxy)),
            0,
            "Equivalence violation: treasury cvxCRV balance is not zero."
        );
        assertEq(
            ICvxRewardPool(CVX_REWARD_POOL).balanceOf(address(treasury_proxy)),
            amount,
            "Equivalence violation: treasury staked CVX balance and amount."
        );
        assertEq(
            IBaseRewardPool(CVX_CRV_BASE_REWARD_POOL).balanceOf(address(treasury_proxy)),
            expectedRewardAmount,
            "Equivalence violation: treasury staked cvxCRV balance and expectedRewardAmount."
        );
    }

    /// @dev Test that contract admins can claim all unclaimed cvxCRV rewards from CVX_REWARD_POOL contract, without staking the cvxCRV rewards.
    function test_claimRewardCvx_without_stake(uint256 amount) public {
        // Assumptions
        vm.assume(amount > 1e12 && amount < 1e18 * 1e6);

        // Allocate funds for test
        deal(CVX, address(treasury_proxy), amount);

        // Setup
        ITreasuryAdmin(address(treasury_proxy)).stakeCvx(amount);
        skip(ONE_WEEK);

        // Expectations
        uint256 expectedRewardAmount = ICvxRewardPool(CVX_REWARD_POOL).earned(address(treasury_proxy));

        // Pre-action assertions
        assertEq(
            IERC20(CVX).balanceOf(address(treasury_proxy)),
            0,
            "Equivalence violation: treasury CVX balance is not zero."
        );
        assertEq(
            IERC20(CVX_CRV).balanceOf(address(treasury_proxy)),
            0,
            "Equivalence violation: treasury cvxCRV balance is not zero."
        );
        assertEq(
            ICvxRewardPool(CVX_REWARD_POOL).balanceOf(address(treasury_proxy)),
            amount,
            "Equivalence violation: treasury staked CVX balance and amount."
        );

        // Act
        ITreasuryAdmin(address(treasury_proxy)).claimRewardCvx(false);

        // Post-action assertions
        assertEq(
            IERC20(CVX).balanceOf(address(treasury_proxy)),
            0,
            "Equivalence violation: treasury CVX balance is not zero."
        );
        assertEq(
            IERC20(CVX_CRV).balanceOf(address(treasury_proxy)),
            expectedRewardAmount,
            "Equivalence violation: treasury cvxCRV balance and expectedRewardAmount."
        );
        assertEq(
            ICvxRewardPool(CVX_REWARD_POOL).balanceOf(address(treasury_proxy)),
            amount,
            "Equivalence violation: treasury staked CVX balance and amount."
        );
        assertEq(
            IBaseRewardPool(CVX_CRV_BASE_REWARD_POOL).balanceOf(address(treasury_proxy)),
            0,
            "Equivalence violation: treasury staked cvxCRV balance is not zero."
        );
    }

    function testCannot_test_claimRewardCvx_unauthorized(address sender, uint256 amount) public {
        // Assumptions
        vm.assume(amount > 1e12 && amount < 1e18 * 1e6);
        vm.assume(sender != address(this));

        // Allocate funds for test
        deal(CVX, address(treasury_proxy), amount);

        // Setup
        ITreasuryAdmin(address(treasury_proxy)).stakeCvx(amount);
        skip(ONE_WEEK);

        // Exptectation 1
        vm.expectRevert("Ownable: caller is not the owner");

        // Act 1: pranking as other addresses
        vm.prank(sender);
        ITreasuryAdmin(address(treasury_proxy)).claimRewardCvx(true);

        // Exptectation 2
        vm.expectRevert("Ownable: caller is not the owner");

        // Act 2: pranking as other addresses
        vm.prank(sender);
        ITreasuryAdmin(address(treasury_proxy)).claimRewardCvx(false);
    }

    function testCannot_test_claimRewardCvx_no_rewards(uint256 amount) public {
        // Assumptions
        vm.assume(amount > 1e12 && amount < 1e18 * 1e6);

        // Exptectation 1
        vm.expectRevert("No rewards to claim.");

        // Act 1: treasury has no rewards to claim on CVX_REWARD_POOL
        ITreasuryAdmin(address(treasury_proxy)).claimRewardCvx(true);

        // Exptectation 1
        vm.expectRevert("No rewards to claim.");

        // Act 1: treasury has no rewards to claim on CVX_REWARD_POOL
        ITreasuryAdmin(address(treasury_proxy)).claimRewardCvx(false);
    }

    /// @dev Test that contract admins can deposit CRV into CRV_DEPOSITOR, convert the CRV to cvxCRV, and stake the corresponding cvxCRV into CVX_CRV_BASE_REWARD_POOL.
    function test_stakeCrv(uint256 amount) public {
        // Assumptions
        vm.assume(amount > 1e12 && amount < 1e18 * 1e6);

        // Allocate funds for test
        deal(CRV, address(treasury_proxy), amount);

        // Pre-action assertions
        assertEq(
            IERC20(CRV).balanceOf(address(treasury_proxy)),
            amount,
            "Equivalence violation: treasury CRV balance and amount."
        );
        assertEq(
            IBaseRewardPool(CVX_CRV_BASE_REWARD_POOL).balanceOf(address(treasury_proxy)),
            0,
            "Equivalence violation: treasury staked cvxCRV balance is not zero."
        );

        // Act
        ITreasuryAdmin(address(treasury_proxy)).stakeCrv(amount);

        // Post-action assertions
        assertEq(
            IERC20(CRV).balanceOf(address(treasury_proxy)),
            0,
            "Equivalence violation: treasury CRV balance is not zero."
        );
        assertEq(
            IBaseRewardPool(CVX_CRV_BASE_REWARD_POOL).balanceOf(address(treasury_proxy)),
            amount,
            "Equivalence violation: treasury staked cvxCRV balance and amount."
        );
    }

    function testCannot_stakeCrv_unauthorized(address sender, uint256 amount) public {
        // Assumptions
        vm.assume(amount > 1e12 && amount < 1e18 * 1e6);
        vm.assume(sender != address(this));

        // Allocate funds for test
        deal(CRV, address(treasury_proxy), amount);

        // Exptectations
        vm.expectRevert("Ownable: caller is not the owner");

        // Act: pranking as other addresses
        vm.prank(sender);
        ITreasuryAdmin(address(treasury_proxy)).stakeCrv(amount);
    }

    function testCannot_stakeCrv_balance(uint256 balance, uint256 stakeAmount) public {
        // Assumptions
        vm.assume(balance > 1e12 && balance < 1e18 * 1e6);
        vm.assume(stakeAmount > balance);

        // Exptectations
        vm.expectRevert("Insufficient CRV balance.");

        // Act: treasury CRV balance is zero
        ITreasuryAdmin(address(treasury_proxy)).stakeCrv(stakeAmount);
    }

    /// @dev Test that contract admins can withdraw all staked cvxCRV from CVX_CRV_BASE_REWARD_POOL, and claim all unclaimed CVX, CRV, and 3CRV rewards.
    function test_unstakeCvxCrv(uint256 amount) public {
        // Assumptions
        vm.assume(amount > 1e12 && amount < 1e18 * 1e6);

        // Allocate funds for test
        deal(CRV, address(treasury_proxy), amount);

        // Setup
        ITreasuryAdmin(address(treasury_proxy)).stakeCrv(amount);
        skip(ONE_WEEK);

        // Expectations
        uint256 expectedCrvRewardAmount = IBaseRewardPool(CVX_CRV_BASE_REWARD_POOL).earned(address(treasury_proxy));
        uint256 expectedCvxRewardAmount = ICvxMining(CVX_MINING).ConvertCrvToCvx(expectedCrvRewardAmount);
        uint256 expected3CrvRewardAmount =
            IVirtualBalanceRewardPool(VIRTUAL_BALANCE_REWARD_POOL).earned(address(treasury_proxy));

        // Pre-action assertions
        assertEq(
            IERC20(CVX_CRV).balanceOf(address(treasury_proxy)),
            0,
            "Equivalence violation: treasury cvxCRV balance is not zero."
        );
        assertEq(
            IERC20(CRV).balanceOf(address(treasury_proxy)),
            0,
            "Equivalence violation: treasury CRV balance is not zero."
        );
        assertEq(
            IERC20(CVX).balanceOf(address(treasury_proxy)),
            0,
            "Equivalence violation: treasury CVX balance is not zero."
        );
        assertEq(
            IERC20(_3CRV).balanceOf(address(treasury_proxy)),
            0,
            "Equivalence violation: treasury 3CRV balance is not zero."
        );
        assertEq(
            IBaseRewardPool(CVX_CRV_BASE_REWARD_POOL).balanceOf(address(treasury_proxy)),
            amount,
            "Equivalence violation: treasury staked cvxCRV balance and amount."
        );

        // Act
        ITreasuryAdmin(address(treasury_proxy)).unstakeCvxCrv(amount);

        // Post-action assertions
        assertEq(
            IERC20(CVX_CRV).balanceOf(address(treasury_proxy)),
            amount,
            "Equivalence violation: treasury cvxCRV balance and amount."
        );
        assertEq(
            IERC20(CRV).balanceOf(address(treasury_proxy)),
            expectedCrvRewardAmount,
            "Equivalence violation: treasury CRV balance and expectedCrvRewardAmount."
        );
        assertEq(
            IERC20(CVX).balanceOf(address(treasury_proxy)),
            expectedCvxRewardAmount,
            "Equivalence violation: treasury CVX balance and expectedCvxRewardAmount."
        );
        assertEq(
            IERC20(_3CRV).balanceOf(address(treasury_proxy)),
            expected3CrvRewardAmount,
            "Equivalence violation: treasury 3CRV balance and expected3CrvRewardAmount."
        );
        assertEq(
            IBaseRewardPool(CVX_CRV_BASE_REWARD_POOL).balanceOf(address(treasury_proxy)),
            0,
            "Equivalence violation: treasury staked cvxCRV balance is not zero."
        );
    }

    function testCannot_unstakeCvxCrv_unauthorized(address sender, uint256 amount) public {
        // Assumptions
        vm.assume(amount > 1e12 && amount < 1e18 * 1e6);
        vm.assume(sender != address(this));

        // Allocate funds for test
        deal(CRV, address(treasury_proxy), amount);

        // Setup
        ITreasuryAdmin(address(treasury_proxy)).stakeCrv(amount);
        skip(ONE_WEEK);

        // Exptectations
        vm.expectRevert("Ownable: caller is not the owner");

        // Act: pranking as other addresses
        vm.prank(sender);
        ITreasuryAdmin(address(treasury_proxy)).unstakeCvxCrv(amount);
    }

    function testCannot_unstakeCvxCrv_balance(uint256 amount) public {
        // Assumptions
        vm.assume(amount > 1e12 && amount < 1e18 * 1e6);

        // Exptectations
        vm.expectRevert("Amount exceeds staked balance.");

        // Act: treasury staked cvxCRV balance is zero
        ITreasuryAdmin(address(treasury_proxy)).unstakeCvxCrv(amount);
    }

    /// @dev Test that contract admins can claim all unclaimed CVX, CRV, and 3CRV rewards from CVX_CRV_BASE_REWARD_POOL, without withrawing cvxCRV principal.
    function test_claimRewardCvxCrv(uint256 amount) public {
        // Assumptions
        vm.assume(amount > 1e12 && amount < 1e18 * 1e6);

        // Allocate funds for test
        deal(CRV, address(treasury_proxy), amount);

        // Setup
        ITreasuryAdmin(address(treasury_proxy)).stakeCrv(amount);
        skip(ONE_WEEK);

        // Expectations
        uint256 expectedCrvRewardAmount = IBaseRewardPool(CVX_CRV_BASE_REWARD_POOL).earned(address(treasury_proxy));
        uint256 expectedCvxRewardAmount = ICvxMining(CVX_MINING).ConvertCrvToCvx(expectedCrvRewardAmount);
        uint256 expected3CrvRewardAmount =
            IVirtualBalanceRewardPool(VIRTUAL_BALANCE_REWARD_POOL).earned(address(treasury_proxy));

        // Pre-action assertions
        assertEq(
            IERC20(CVX_CRV).balanceOf(address(treasury_proxy)),
            0,
            "Equivalence violation: treasury cvxCRV balance is not zero."
        );
        assertEq(
            IERC20(CRV).balanceOf(address(treasury_proxy)),
            0,
            "Equivalence violation: treasury CRV balance is not zero."
        );
        assertEq(
            IERC20(CVX).balanceOf(address(treasury_proxy)),
            0,
            "Equivalence violation: treasury CVX balance is not zero."
        );
        assertEq(
            IERC20(_3CRV).balanceOf(address(treasury_proxy)),
            0,
            "Equivalence violation: treasury 3CRV balance is not zero."
        );
        assertEq(
            IBaseRewardPool(CVX_CRV_BASE_REWARD_POOL).balanceOf(address(treasury_proxy)),
            amount,
            "Equivalence violation: treasury staked cvxCRV balance and amount."
        );

        // Act
        ITreasuryAdmin(address(treasury_proxy)).claimRewardCvxCrv();

        // Post-action assertions
        assertEq(
            IERC20(CVX_CRV).balanceOf(address(treasury_proxy)),
            0,
            "Equivalence violation: treasury cvxCRV balance is not zero."
        );
        assertEq(
            IERC20(CRV).balanceOf(address(treasury_proxy)),
            expectedCrvRewardAmount,
            "Equivalence violation: treasury CRV balance and expectedCrvRewardAmount."
        );
        assertEq(
            IERC20(CVX).balanceOf(address(treasury_proxy)),
            expectedCvxRewardAmount,
            "Equivalence violation: treasury CVX balance and expectedCvxRewardAmount."
        );
        assertEq(
            IERC20(_3CRV).balanceOf(address(treasury_proxy)),
            expected3CrvRewardAmount,
            "Equivalence violation: treasury 3CRV balance and expected3CrvRewardAmount."
        );
        assertEq(
            IBaseRewardPool(CVX_CRV_BASE_REWARD_POOL).balanceOf(address(treasury_proxy)),
            amount,
            "Equivalence violation: treasury staked cvxCRV balance and amount."
        );
    }

    function testCannot_claimRewardCvxCrv_unauthorized(address sender, uint256 amount) public {
        // Assumptions
        vm.assume(amount > 1e12 && amount < 1e18 * 1e6);
        vm.assume(sender != address(this));

        // Allocate funds for test
        deal(CRV, address(treasury_proxy), amount);

        // Setup
        ITreasuryAdmin(address(treasury_proxy)).stakeCrv(amount);
        skip(ONE_WEEK);

        // Exptectations
        vm.expectRevert("Ownable: caller is not the owner");

        // Act: pranking as other addresses
        vm.prank(sender);
        ITreasuryAdmin(address(treasury_proxy)).claimRewardCvxCrv();
    }

    function testCannot_claimRewardCvxCrv_no_reward(uint256 amount) public {
        // Assumptions
        vm.assume(amount > 1e12 && amount < 1e18 * 1e6);

        // Allocate funds for test
        deal(CRV, address(treasury_proxy), amount);

        // Exptectations
        vm.expectRevert("No rewards to claim.");

        // Act: treasury has no rewards to claim on CVX_CRV_BASE_REWARD_POOL
        ITreasuryAdmin(address(treasury_proxy)).claimRewardCvxCrv();
    }

    /// @dev Test that contract admins can stake 3CRV into CVX_3CRV_BASE_REWARD_POOL.
    function test_stake3Crv(uint256 amount) public {
        // Assumptions
        vm.assume(amount > 1e12 && amount < 1e18 * 1e6);

        // Allocate funds for test
        deal(_3CRV, address(treasury_proxy), amount);

        assertEq(
            IERC20(_3CRV).balanceOf(address(treasury_proxy)),
            amount,
            "Equivalence violation: treasury 3CRV balance and amount."
        );
        assertEq(
            IBaseRewardPool(CVX_3CRV_BASE_REWARD_POOL).balanceOf(address(treasury_proxy)),
            0,
            "Equivalence violation: treasury staked cvx3CRV balance is not zero."
        );

        // Act
        ITreasuryAdmin(address(treasury_proxy)).stake3Crv(amount);

        // Post-action assertions
        assertEq(
            IERC20(_3CRV).balanceOf(address(treasury_proxy)),
            0,
            "Equivalence violation: treasury 3CRV balance is not zero."
        );
        assertEq(
            IBaseRewardPool(CVX_3CRV_BASE_REWARD_POOL).balanceOf(address(treasury_proxy)),
            amount,
            "Equivalence violation: treasury staked cvx3CRV balance and amount."
        );
    }

    function testCannot_stake3Crv_unauthorized(address sender, uint256 amount) public {
        // Assumptions
        vm.assume(amount > 1e12 && amount < 1e18 * 1e6);
        vm.assume(sender != address(this));

        // Allocate funds for test
        deal(_3CRV, address(treasury_proxy), amount);

        // Exptectations
        vm.expectRevert("Ownable: caller is not the owner");

        // Act: pranking as other addresses
        vm.prank(sender);
        ITreasuryAdmin(address(treasury_proxy)).stake3Crv(amount);
    }

    function testCannot_stake3Crv_balance(uint256 balance, uint256 stakeAmount) public {
        // Assumptions
        vm.assume(balance > 1e12 && balance < 1e18 * 1e6);
        vm.assume(stakeAmount > balance);

        // Exptectations
        vm.expectRevert("Insufficient 3CRV balance.");

        // Act: treasury 3CRV balance is zero
        ITreasuryAdmin(address(treasury_proxy)).stake3Crv(balance);
    }

    /**
     * @dev Test that contract admins can withdraw cvx3CRV from CVX_3CRV_BASE_REWARD_POOL,
     * unwrap it into 3CRV, and claim all unclaimed CVX and CRV rewards.
     */
    function test_unstake3Crv(uint256 amount, uint256 withdrawAmount) public {
        // Assumptions 1
        vm.assume(amount > 1e12 && amount < 1e18 * 1e6);

        // Allocate funds for test
        _mintForTest(DAI, amount);
        deal(_3CRV, address(treasury_proxy), amount);

        // Setup
        ITreasuryAdmin(address(treasury_proxy)).stake3Crv(amount);
        skip(ONE_WEEK);
        uint256 totalSupply = ITreasuryAdmin(address(treasury_proxy)).totalSupply();
        uint256 lpTokenPrice = ICurve3Pool(STABLE_SWAP_3POOL).get_virtual_price();
        uint256 conversionFactor = (1e18 * 1e18 / lpTokenPrice);
        uint256 backingAmount = (totalSupply * conversionFactor) / 1e18;
        uint256 totalStaked = IBaseRewardPool(CVX_3CRV_BASE_REWARD_POOL).balanceOf(address(treasury_proxy));
        uint256 maxWithdrawAmount = totalStaked - backingAmount;

        // Assumptions 2
        vm.assume(withdrawAmount <= maxWithdrawAmount);

        // Expectations
        uint256 expectedCrvRewardAmount = IBaseRewardPool(CVX_3CRV_BASE_REWARD_POOL).earned(address(treasury_proxy));
        uint256 expectedCvxRewardAmount = ICvxMining(CVX_MINING).ConvertCrvToCvx(expectedCrvRewardAmount);

        // Pre-action assertions
        assertEq(
            IERC20(_3CRV).balanceOf(address(treasury_proxy)),
            0,
            "Equivalence violation: treasury 3CRV balance is not zero."
        );
        assertEq(
            IERC20(CRV).balanceOf(address(treasury_proxy)),
            0,
            "Equivalence violation: treasury CRV balance is not zero."
        );
        assertEq(
            IERC20(CVX).balanceOf(address(treasury_proxy)),
            0,
            "Equivalence violation: treasury CVX balance is not zero."
        );
        assertEq(
            IBaseRewardPool(CVX_3CRV_BASE_REWARD_POOL).balanceOf(address(treasury_proxy)),
            totalStaked,
            "Equivalence violation: treasury staked cvx3CRV balance and totalStaked."
        );

        // Act
        ITreasuryAdmin(address(treasury_proxy)).unstake3Crv(withdrawAmount);

        // Post-action assertions
        assertEq(
            IERC20(_3CRV).balanceOf(address(treasury_proxy)),
            withdrawAmount,
            "Equivalence violation: treasury 3CRV balance and withdrawAmount."
        );
        assertEq(
            IERC20(CRV).balanceOf(address(treasury_proxy)),
            expectedCrvRewardAmount,
            "Equivalence violation: treasury CRV balance and expectedCrvRewardAmount."
        );
        assertEq(
            IERC20(CVX).balanceOf(address(treasury_proxy)),
            expectedCvxRewardAmount,
            "Equivalence violation: treasury CVX balance and expectedCvxRewardAmount."
        );
        assertEq(
            IBaseRewardPool(CVX_3CRV_BASE_REWARD_POOL).balanceOf(address(treasury_proxy)),
            backingAmount + (maxWithdrawAmount - withdrawAmount),
            "Equivalence violation: treasury staked cvx3CRV balance and backingAmount."
        );
    }

    function testCannot_unstake3Crv_unauthorized(address sender, uint256 amount) public {
        // Assumptions
        vm.assume(amount > 1e12 && amount < 1e18 * 1e6);
        vm.assume(sender != address(this));

        // Allocate funds for test
        deal(_3CRV, address(treasury_proxy), amount);

        // Setup
        ITreasuryAdmin(address(treasury_proxy)).stake3Crv(amount);
        skip(ONE_WEEK);

        // Exptectations
        vm.expectRevert("Ownable: caller is not the owner");

        // Act: pranking as other addresses
        vm.prank(sender);
        ITreasuryAdmin(address(treasury_proxy)).unstake3Crv(amount);
    }

    function testCannot_unstake3Crv_backing(uint256 amount, uint256 withdrawAmount) public {
        // Assumptions 1
        vm.assume(amount > 1e12 && amount < 1e18 * 1e6);

        // Allocate funds for test
        _mintForTest(DAI, amount);
        deal(_3CRV, address(treasury_proxy), amount);

        // Setup
        ITreasuryAdmin(address(treasury_proxy)).stake3Crv(amount);
        skip(ONE_WEEK);
        uint256 totalSupply = ITreasuryAdmin(address(treasury_proxy)).totalSupply();
        uint256 lpTokenPrice = ICurve3Pool(STABLE_SWAP_3POOL).get_virtual_price();
        uint256 conversionFactor = (1e18 * 1e18 / lpTokenPrice);
        uint256 backingAmount = (totalSupply * conversionFactor) / 1e18;
        uint256 totalStaked = IBaseRewardPool(CVX_3CRV_BASE_REWARD_POOL).balanceOf(address(treasury_proxy));
        uint256 maxWithdrawAmount = totalStaked - backingAmount;

        // Assumptions 2
        vm.assume(withdrawAmount > maxWithdrawAmount);

        // Exptectations
        vm.expectRevert("Cannot withdraw backing cvx3CRV.");

        // Act: treasury staked cvx3CRV amount to withdraw is backing USX
        ITreasuryAdmin(address(treasury_proxy)).unstake3Crv(withdrawAmount);
    }

    function test_claimRewardCvx3Crv(uint256 amount) public {
        // Assumptions
        vm.assume(amount > 1e12 && amount < 1e18 * 1e6);

        // Allocate funds for test
        deal(_3CRV, address(treasury_proxy), amount);

        // Setup
        ITreasuryAdmin(address(treasury_proxy)).stake3Crv(amount);
        skip(ONE_WEEK);

        // Expectations
        uint256 expectedCrvRewardAmount = IBaseRewardPool(CVX_3CRV_BASE_REWARD_POOL).earned(address(treasury_proxy));
        uint256 expectedCvxRewardAmount = ICvxMining(CVX_MINING).ConvertCrvToCvx(expectedCrvRewardAmount);

        // Pre-action assertions
        assertEq(
            IERC20(_3CRV).balanceOf(address(treasury_proxy)),
            0,
            "Equivalence violation: treasury 3CRV balance is not zero."
        );
        assertEq(
            IERC20(CRV).balanceOf(address(treasury_proxy)),
            0,
            "Equivalence violation: treasury CRV balance is not zero."
        );
        assertEq(
            IERC20(CVX).balanceOf(address(treasury_proxy)),
            0,
            "Equivalence violation: treasury CVX balance is not zero."
        );
        assertEq(
            IBaseRewardPool(CVX_3CRV_BASE_REWARD_POOL).balanceOf(address(treasury_proxy)),
            amount,
            "Equivalence violation: treasury staked cvx3CRV balance and amount."
        );

        // Act
        ITreasuryAdmin(address(treasury_proxy)).claimRewardCvx3Crv();

        // Post-action assertions
        assertEq(
            IERC20(_3CRV).balanceOf(address(treasury_proxy)),
            0,
            "Equivalence violation: treasury 3CRV balance is not zero."
        );
        assertEq(
            IERC20(CRV).balanceOf(address(treasury_proxy)),
            expectedCrvRewardAmount,
            "Equivalence violation: treasury CRV balance and expectedCrvRewardAmount."
        );
        assertEq(
            IERC20(CVX).balanceOf(address(treasury_proxy)),
            expectedCvxRewardAmount,
            "Equivalence violation: treasury CVX balance and expectedCvxRewardAmount."
        );
        assertEq(
            IBaseRewardPool(CVX_3CRV_BASE_REWARD_POOL).balanceOf(address(treasury_proxy)),
            amount,
            "Equivalence violation: treasury staked cvx3CRV balance is not zero."
        );
    }

    function testCannot_claimRewardCvx3Crv_unauthorized(address sender, uint256 amount) public {
        // Assumptions
        vm.assume(amount > 1e12 && amount < 1e18 * 1e6);
        vm.assume(sender != address(this));

        // Allocate funds for test
        deal(_3CRV, address(treasury_proxy), amount);

        // Setup
        ITreasuryAdmin(address(treasury_proxy)).stake3Crv(amount);
        skip(ONE_WEEK);

        // Exptectations
        vm.expectRevert("Ownable: caller is not the owner");

        // Act: pranking as other addresses
        vm.prank(sender);
        ITreasuryAdmin(address(treasury_proxy)).claimRewardCvx3Crv();
    }

    function testCannot_claimRewardCvx3Crv_no_rewards(uint256 amount) public {
        // Assumptions
        vm.assume(amount > 1e12 && amount < 1e18 * 1e6);

        // Exptectations
        vm.expectRevert("No rewards to claim.");

        // Act: treasury has no rewards to claim on CVX_3CRV_BASE_REWARD_POOL
        ITreasuryAdmin(address(treasury_proxy)).claimRewardCvx3Crv();
    }
}
