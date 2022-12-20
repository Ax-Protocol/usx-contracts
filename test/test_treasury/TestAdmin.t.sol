// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "forge-std/Test.sol";
import "../interfaces/ITreasuryTest.t.sol";
import "../interfaces/ICvxMining.t.sol";
import "../interfaces/IVirtualBalanceRewardPool.t.sol";
import "../common/Constants.t.sol";
import "./common/TestHelpers.t.sol";

contract TestAdmin is Test, TreasurySetup, RedeemHelper {
    function test_addSupportedStable() public {
        // Test Variables
        int128 testCurveIndex = 0;

        // Pre-action assertions
        (bool supported, int128 returnedTestCurveIndex) =
            ITreasuryTest(address(treasury_proxy)).supportedStables(TEST_STABLE);
        assertEq(supported, false, "Error: stable already supported");

        // Act
        ITreasuryTest(address(treasury_proxy)).addSupportedStable(TEST_STABLE, testCurveIndex);

        // Post-action assertions
        (supported, returnedTestCurveIndex) = ITreasuryTest(address(treasury_proxy)).supportedStables(TEST_STABLE);
        assertEq(supported, true, "Error: failed to add supported stable");
        assertEq(
            returnedTestCurveIndex, testCurveIndex, "Equivalence violation: returnedTestCurveIndex and testCurveIndex"
        );
    }

    function testCannot_addSupportedStable_sender() public {
        // Test Variables
        int128 testCurveIndex = 0;

        // Expectations
        vm.expectRevert("Ownable: caller is not the owner");

        // Act
        vm.prank(TEST_ADDRESS);
        ITreasuryTest(address(treasury_proxy)).addSupportedStable(TEST_STABLE, testCurveIndex);
    }

    function test_removeSupportedStable() public {
        // Setup
        ITreasuryTest(address(treasury_proxy)).addSupportedStable(TEST_STABLE, 0);

        // Pre-action assertions
        (bool supported, int128 returnedTestCurveIndex) =
            ITreasuryTest(address(treasury_proxy)).supportedStables(TEST_STABLE);
        assertEq(supported, true, "Error: stable not supported");
        assertEq(returnedTestCurveIndex, 0, "Equivalence violation: returnedTestCurveIndex and testCurveIndex");

        // Act
        ITreasuryTest(address(treasury_proxy)).removeSupportedStable(TEST_STABLE);

        // Post-action assertions
        (supported, returnedTestCurveIndex) = ITreasuryTest(address(treasury_proxy)).supportedStables(TEST_STABLE);
        assertEq(supported, false, "Error: failed to remove supported stable");
    }

    function testCannot_removeSupportedStable_sender() public {
        // Expectations
        vm.expectRevert("Ownable: caller is not the owner");

        // Act
        vm.prank(TEST_ADDRESS);
        ITreasuryTest(address(treasury_proxy)).removeSupportedStable(TEST_STABLE);
    }

    function test_extractERC20_treasury(uint256 amount) public {
        vm.assume(amount > 0 && amount < 1e6);

        mintForTest(DAI, DAI_AMOUNT);

        // Send the treasury an ERC20 token
        deal(USDC, address(treasury_proxy), amount);

        // Pre-action assertions
        assertEq(
            IERC20(USDC).balanceOf(address(treasury_proxy)),
            amount,
            "Equivalence violation: treausury test coin balance and amount"
        );

        // Act
        ITreasuryTest(address(treasury_proxy)).extractERC20(USDC);

        // Post-action assertions
        assertEq(
            IERC20(USDC).balanceOf(address(treasury_proxy)),
            0,
            "Equivalence violation: treausury test coin balance is not zero"
        );
        assertEq(
            IERC20(USDC).balanceOf(address(this)),
            amount,
            "Equivalence violation: owner USDC balance and amount"
        );
    }

    // TODO: add testCannot_extractERC20_treasury(), where an admin attempts to withdraw backingToken

    /// @dev Test that contract admins can stake CVX into CVX_REWARD_POOL contract.
    function test_stakeCvx() public {
        // Allocate funds for test
        deal(CVX, address(treasury_proxy), CVX_AMOUNT);

        // Pre-action assertions
        assertEq(
            IERC20(CVX).balanceOf(address(treasury_proxy)),
            CVX_AMOUNT,
            "Equivalence violation: treasury CVX balance and CVX_AMOUNT."
        );
        assertEq(
            ICvxRewardPool(CVX_REWARD_POOL).balanceOf(address(treasury_proxy)),
            0,
            "Equivalence violation: treasury staked CVX balance is not zero."
        );

        // Action
        ITreasuryTest(address(treasury_proxy)).stakeCvx(CVX_AMOUNT);

        // Post-action assertions
        assertEq(
            IERC20(CVX).balanceOf(address(treasury_proxy)),
            0,
            "Equivalence violation: treasury CVX balance is not zero."
        );
        assertEq(
            ICvxRewardPool(CVX_REWARD_POOL).balanceOf(address(treasury_proxy)),
            CVX_AMOUNT,
            "Equivalence violation: treasury staked CVX balance and CVX_AMOUNT."
        );
    }

    /// @dev Test that contract admins can withdraw CVX principal from CVX_REWARD_POOL contract, and claim all unclaimed cvxCRV rewards.
    function test_unstakeCvx() public {
        // Allocate funds for test
        deal(CVX, address(treasury_proxy), CVX_AMOUNT);

        // Setup
        uint256 oneWeek = 604800;
        ITreasuryTest(address(treasury_proxy)).stakeCvx(CVX_AMOUNT);
        skip(oneWeek);

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
            CVX_AMOUNT,
            "Equivalence violation: treasury staked CVX balance and CVX_AMOUNT."
        );

        // Act
        ITreasuryTest(address(treasury_proxy)).unstakeCvx(CVX_AMOUNT);

        // Post-action
        assertEq(
            IERC20(CVX).balanceOf(address(treasury_proxy)),
            CVX_AMOUNT,
            "Equivalence violation: treasury CVX balance and CVX_AMOUNT."
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

    /// @dev Test that contract admins can claim all unclaimed cvxCRV rewards from CVX_REWARD_POOL contract, and stake the cvxCRV rewards.
    function test_claimRewardCvx_and_stake() public {
        // Allocate funds for test
        deal(CVX, address(treasury_proxy), CVX_AMOUNT);

        // Setup
        uint256 oneWeek = 604800;
        ITreasuryTest(address(treasury_proxy)).stakeCvx(CVX_AMOUNT);
        skip(oneWeek);

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
            CVX_AMOUNT,
            "Equivalence violation: treasury staked CVX balance and CVX_AMOUNT."
        );

        // Act
        ITreasuryTest(address(treasury_proxy)).claimRewardCvx(true);

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
            CVX_AMOUNT,
            "Equivalence violation: treasury staked CVX balance and CVX_AMOUNT."
        );
        assertEq(
            IBaseRewardPool(CVX_CRV_BASE_REWARD_POOL).balanceOf(address(treasury_proxy)),
            expectedRewardAmount,
            "Equivalence violation: treasury staked cvxCRV balance and expectedRewardAmount."
        );
    }

    /// @dev Test that contract admins can claim all unclaimed cvxCRV rewards from CVX_REWARD_POOL contract, without staking the cvxCRV rewards.
    function test_claimRewardCvx_without_stake() public {
        // Allocate funds for test
        deal(CVX, address(treasury_proxy), CVX_AMOUNT);

        // Setup
        ITreasuryTest(address(treasury_proxy)).stakeCvx(CVX_AMOUNT);
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
            CVX_AMOUNT,
            "Equivalence violation: treasury staked CVX balance and CVX_AMOUNT."
        );

        // Act
        ITreasuryTest(address(treasury_proxy)).claimRewardCvx(false);

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
            CVX_AMOUNT,
            "Equivalence violation: treasury staked CVX balance and CVX_AMOUNT."
        );
        assertEq(
            IBaseRewardPool(CVX_CRV_BASE_REWARD_POOL).balanceOf(address(treasury_proxy)),
            0,
            "Equivalence violation: treasury staked cvxCRV balance is not zero."
        );
    }

    /// @dev Test that contract admins can deposit CRV into CRV_DEPOSITOR, convert the CRV to cvxCRV, and stake the corresponding cvxCRV into CVX_CRV_BASE_REWARD_POOL.
    function test_stakeCrv() public {
        // Allocate funds for test
        deal(CRV, address(treasury_proxy), CRV_AMOUNT);

        // Pre-action assertions
        assertEq(
            IERC20(CRV).balanceOf(address(treasury_proxy)),
            CRV_AMOUNT,
            "Equivalence violation: treasury CRV balance and CRV_AMOUNT."
        );
        assertEq(
            IBaseRewardPool(CVX_CRV_BASE_REWARD_POOL).balanceOf(address(treasury_proxy)),
            0,
            "Equivalence violation: treasury staked cvxCRV balance is not zero."
        );

        // Act
        ITreasuryTest(address(treasury_proxy)).stakeCrv(CRV_AMOUNT);

        // Post-action assertions
        assertEq(
            IERC20(CRV).balanceOf(address(treasury_proxy)),
            0,
            "Equivalence violation: treasury CRV balance is not zero."
        );
        assertEq(
            IBaseRewardPool(CVX_CRV_BASE_REWARD_POOL).balanceOf(address(treasury_proxy)),
            CRV_AMOUNT,
            "Equivalence violation: treasury staked cvxCRV balance and CRV_AMOUNT."
        );
    }

    /// @dev Test that contract admins can stake cvxCRV into CVX_CRV_BASE_REWARD_POOL.
    function test_stakeCvxCrv() public {
        // Allocate funds for test
        deal(CVX_CRV, address(treasury_proxy), CVX_CRV_AMOUNT);

        assertEq(
            IERC20(CVX_CRV).balanceOf(address(treasury_proxy)),
            CVX_CRV_AMOUNT,
            "Equivalence violation: treasury cvxCRV balance and CVX_CRV_AMOUNT."
        );
        assertEq(
            IBaseRewardPool(CVX_CRV_BASE_REWARD_POOL).balanceOf(address(treasury_proxy)),
            0,
            "Equivalence violation: treasury staked cvxCRV balance is not zero."
        );

        // Act
        ITreasuryTest(address(treasury_proxy)).stakeCvxCrv(CVX_CRV_AMOUNT);

        // Post-action assertions
        assertEq(
            IERC20(CVX_CRV).balanceOf(address(treasury_proxy)),
            0,
            "Equivalence violation: treasury cvxCRV balance is not zero."
        );
        assertEq(
            IBaseRewardPool(CVX_CRV_BASE_REWARD_POOL).balanceOf(address(treasury_proxy)),
            CVX_CRV_AMOUNT,
            "Equivalence violation: treasury staked cvxCRV balance and CVX_CRV_AMOUNT."
        );
    }

    /// @dev Test that contract admins can withdraw all staked cvxCRV from CVX_CRV_BASE_REWARD_POOL, and claim all unclaimed CVX, CRV, and 3CRV rewards.
    function test_unstakeCvxCrv() public {
        // Allocate funds for test
        deal(CRV, address(treasury_proxy), CRV_AMOUNT);

        // Setup
        ITreasuryTest(address(treasury_proxy)).stakeCrv(CRV_AMOUNT);
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
            CRV_AMOUNT,
            "Equivalence violation: treasury staked cvxCRV balance and CRV_AMOUNT."
        );

        // Act
        ITreasuryTest(address(treasury_proxy)).unstakeCvxCrv(CRV_AMOUNT);

        // Post-action assertions
        assertEq(
            IERC20(CVX_CRV).balanceOf(address(treasury_proxy)),
            CRV_AMOUNT,
            "Equivalence violation: treasury cvxCRV balance and CRV_AMOUNT."
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

    /// @dev Test that contract admins can claim all unclaimed CVX, CRV, and 3CRV rewards from CVX_CRV_BASE_REWARD_POOL, without withrawing cvxCRV principal.
    function test_claimRewardCvxCrv() public {
        // Allocate funds for test
        deal(CRV, address(treasury_proxy), CRV_AMOUNT);

        // Setup
        ITreasuryTest(address(treasury_proxy)).stakeCrv(CRV_AMOUNT);
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
            CRV_AMOUNT,
            "Equivalence violation: treasury staked cvxCRV balance and CRV_AMOUNT."
        );

        // Act
        ITreasuryTest(address(treasury_proxy)).claimRewardCvxCrv();

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
            CRV_AMOUNT,
            "Equivalence violation: treasury staked cvxCRV balance and CRV_AMOUNT."
        );
    }

    // function stake3Crv(uint256 _amount) external;
    function test_stake3Crv() public {
        // Allocate funds for test
        deal(_3CRV, address(treasury_proxy), _3CRV_AMOUNT);

        assertEq(IERC20(_3CRV).balanceOf(address(treasury_proxy)), _3CRV_AMOUNT, "Equivalence violation: treasury 3CRV balance and _3CRV_AMOUNT.");
        assertEq(IBaseRewardPool(CVX_3CRV_BASE_REWARD_POOL).balanceOf(address(treasury_proxy)), 0, "Equivalence violation: treasury staked cvx3CRV balance is not zero.");
    
        // Act
        ITreasuryTest(address(treasury_proxy)).stake3Crv(_3CRV_AMOUNT);

        // Post-action assertions
        assertEq(IERC20(_3CRV).balanceOf(address(treasury_proxy)), 0, "Equivalence violation: treasury 3CRV balance is not zero.");
        assertEq(IBaseRewardPool(CVX_3CRV_BASE_REWARD_POOL).balanceOf(address(treasury_proxy)), _3CRV_AMOUNT, "Equivalence violation: treasury staked cvx3CRV balance and _3CRV_AMOUNT.");
    }

    // function unstake3Crv(uint256 _amount) external;
    function test_unstake3Crv() public {
        // Allocate funds for test
        deal(_3CRV, address(treasury_proxy), _3CRV_AMOUNT);

        // Setup
        ITreasuryTest(address(treasury_proxy)).stake3Crv(_3CRV_AMOUNT);
        skip(ONE_WEEK);

        // Expectations
        uint256 expectedCrvRewardAmount = IBaseRewardPool(CVX_3CRV_BASE_REWARD_POOL).earned(address(treasury_proxy));
        uint256 expectedCvxRewardAmount = ICvxMining(CVX_MINING).ConvertCrvToCvx(expectedCrvRewardAmount);

        // Pre-action assertions
        assertEq(IERC20(_3CRV).balanceOf(address(treasury_proxy)), 0, "Equivalence violation: treasury 3CRV balance is not zero.");
        assertEq(IERC20(CRV).balanceOf(address(treasury_proxy)), 0, "Equivalence violation: treasury CRV balance is not zero.");
        assertEq(IERC20(CVX).balanceOf(address(treasury_proxy)), 0, "Equivalence violation: treasury CVX balance is not zero.");
        assertEq(IBaseRewardPool(CVX_3CRV_BASE_REWARD_POOL).balanceOf(address(treasury_proxy)), _3CRV_AMOUNT, "Equivalence violation: treasury staked cvx3CRV balance and _3CRV_AMOUNT.");

        // Act
        ITreasuryTest(address(treasury_proxy)).unstake3Crv(_3CRV_AMOUNT);

        // Post-action assertions
        assertEq(IERC20(_3CRV).balanceOf(address(treasury_proxy)), _3CRV_AMOUNT, "Equivalence violation: treasury 3CRV balance and _3CRV_AMOUNT.");
        assertEq(IERC20(CRV).balanceOf(address(treasury_proxy)), expectedCrvRewardAmount, "Equivalence violation: treasury CRV balance and expectedCrvRewardAmount.");
        assertEq(IERC20(CVX).balanceOf(address(treasury_proxy)), expectedCvxRewardAmount, "Equivalence violation: treasury CVX balance and expectedCvxRewardAmount.");
        assertEq(IBaseRewardPool(CVX_3CRV_BASE_REWARD_POOL).balanceOf(address(treasury_proxy)), 0, "Equivalence violation: treasury staked cvx3CRV balance is not zero.");
    }
    
    // // function claimRewardCvx3Crv() external;
    function test_claimRewardCvx3Crv() public {
        // Allocate funds for test
        deal(_3CRV, address(treasury_proxy), _3CRV_AMOUNT);

        // Setup
        ITreasuryTest(address(treasury_proxy)).stake3Crv(_3CRV_AMOUNT);
        skip(ONE_WEEK);

        // Expectations
        uint256 expectedCrvRewardAmount = IBaseRewardPool(CVX_3CRV_BASE_REWARD_POOL).earned(address(treasury_proxy));
        uint256 expectedCvxRewardAmount = ICvxMining(CVX_MINING).ConvertCrvToCvx(expectedCrvRewardAmount);

        // Pre-action assertions
        assertEq(IERC20(_3CRV).balanceOf(address(treasury_proxy)), 0, "Equivalence violation: treasury 3CRV balance is not zero.");
        assertEq(IERC20(CRV).balanceOf(address(treasury_proxy)), 0, "Equivalence violation: treasury CRV balance is not zero.");
        assertEq(IERC20(CVX).balanceOf(address(treasury_proxy)), 0, "Equivalence violation: treasury CVX balance is not zero.");
        assertEq(IBaseRewardPool(CVX_3CRV_BASE_REWARD_POOL).balanceOf(address(treasury_proxy)), _3CRV_AMOUNT, "Equivalence violation: treasury staked cvx3CRV balance and _3CRV_AMOUNT.");

        // Act
        ITreasuryTest(address(treasury_proxy)).claimRewardCvx3Crv();

        // Post-action assertions
        assertEq(IERC20(_3CRV).balanceOf(address(treasury_proxy)), 0, "Equivalence violation: treasury 3CRV balance is not zero.");
        assertEq(IERC20(CRV).balanceOf(address(treasury_proxy)), expectedCrvRewardAmount, "Equivalence violation: treasury CRV balance and expectedCrvRewardAmount.");
        assertEq(IERC20(CVX).balanceOf(address(treasury_proxy)), expectedCvxRewardAmount, "Equivalence violation: treasury CVX balance and expectedCvxRewardAmount.");
        assertEq(IBaseRewardPool(CVX_3CRV_BASE_REWARD_POOL).balanceOf(address(treasury_proxy)), _3CRV_AMOUNT, "Equivalence violation: treasury staked cvx3CRV balance is not zero.");
    }

    // TODO: add testCannot_ counterparts to all reward management unit tests
    // ************************************************************************************************
    // ************************************************************************************************
    // ************************************************************************************************
    // ************************************************************************************************
    // ************************************************************************************************
    //
    // *** Example ***
    // function testCannot_removeSupportedStable_sender() public {
    //     // Expectations
    //     vm.expectRevert("Ownable: caller is not the owner");

    //     // Act
    //     vm.prank(TEST_ADDRESS);
    //     ITreasuryTest(address(treasury_proxy)).removeSupportedStable(TEST_STABLE);
    // }
    // ***************
    //
    //            O   testCannot_stakeCvx
    //            O   testCannot_unstakeCvx
    //            O   testCannot_claimRewardCvx
    //            O   testCannot_stakeCrv
    //            O   testCannot_stakeCvxCrv
    //            O   testCannot_unstakeCvxCrv
    //            O   testCannot_claimRewardCvxCrv
    //            O   testCannot_stake3Crv
    //            O   testCannot_unstake3Crv
    //            O   testCannot_claimRewardCvx3Crv
    //
    // ************************************************************************************************
    // ************************************************************************************************
    // ************************************************************************************************
    // ************************************************************************************************
    // ************************************************************************************************



}
