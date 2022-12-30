// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "../src/Router.sol";
import "../src/SpenderAaveV2Delegation.sol";
import "../src/interfaces/aaveV2/ILendingPoolAddressesProviderV2.sol";
import "./mocks/MockERC20.sol";

interface IDebtToken {
    function UNDERLYING_ASSET_ADDRESS() external view returns (address);

    function approveDelegation(address delegatee, uint256 amount) external;

    function totalSupply() external view returns (uint256);
}

contract SpenderAaveV2DelegationTest is Test {
    using SafeERC20 for IERC20;

    enum InterestRateMode {
        NONE,
        STABLE,
        VARIABLE
    }

    ILendingPoolAddressesProviderV2 public constant aaveV2Provider =
        ILendingPoolAddressesProviderV2(0xB53C1a33016B2DC2fF3653530bfF1848a515c8c5);
    address public constant AUSDC_V2 = 0xBcca60bB61934080951369a648Fb03DF4F96263C;
    IDebtToken public constant AUSDC_V2_DEBT_VARIABLE = IDebtToken(0x619beb58998eD2278e08620f97007e1116D5D25b);

    address public user;
    IRouter public router;
    ISpenderAaveV2Delegation public spender;
    IERC20 public mockERC20;
    ILendingPoolV2 pool = ILendingPoolV2(ILendingPoolAddressesProviderV2(aaveV2Provider).getLendingPool());

    function setUp() external {
        user = makeAddr("user");

        router = new Router();
        spender = new SpenderAaveV2Delegation(address(router), address(aaveV2Provider));
        mockERC20 = new MockERC20("Mock ERC20", "mERC20");

        // User approved spender aave v2 delegation
        vm.startPrank(user);
        AUSDC_V2_DEBT_VARIABLE.approveDelegation(address(spender), type(uint256).max);
        vm.stopPrank();

        vm.label(address(router), "Router");
        vm.label(address(spender), "SpenderAaveV2Delegation");
        vm.label(address(mockERC20), "mERC20");
        vm.label(address(aaveV2Provider), "AaveV2Provider");
        vm.label(address(pool), "AaveV2Pool");
        vm.label(address(AUSDC_V2), "aUSDC");
        vm.label(address(AUSDC_V2_DEBT_VARIABLE), "variableDebtUSDC");
    }

    // Cannot call spender directly
    function testCannotExploit(uint128 amount) external {
        vm.assume(amount > 0);
        deal(address(mockERC20), user, amount);

        vm.startPrank(user);
        vm.expectRevert(bytes("INVALID_USER"));
        spender.borrow(address(mockERC20), amount, uint256(InterestRateMode.VARIABLE));
        vm.stopPrank();
    }

    function testExecuteAaveV2Borrow(uint256 amountIn) external {
        vm.assume(amountIn > 1e8);
        IDebtToken tokenIn = AUSDC_V2_DEBT_VARIABLE;
        IERC20 tokenOut = IERC20(tokenIn.UNDERLYING_ASSET_ADDRESS());
        amountIn = bound(amountIn, 1, tokenIn.totalSupply());
        vm.label(address(tokenOut), "Asset");

        // Setup collateral
        vm.startPrank(user);
        uint256 collateralAmount = amountIn * 3;
        deal(address(tokenOut), user, collateralAmount);
        tokenOut.safeApprove(address(pool), collateralAmount);
        pool.deposit(address(tokenOut), collateralAmount, user, 0);
        vm.stopPrank();

        // Encode logics
        IRouter.Logic[] memory logics = new IRouter.Logic[](1);
        logics[0] = _logicSpenderAaveV2Delegation(address(tokenOut), amountIn, uint256(InterestRateMode.VARIABLE));

        // Execute
        address[] memory tokensOut = new address[](1);
        uint256[] memory amountsOutMin = new uint256[](1);
        tokensOut[0] = address(tokenOut);
        amountsOutMin[0] = amountIn;
        vm.prank(user);
        router.execute(tokensOut, amountsOutMin, logics);

        assertEq(tokenOut.balanceOf(address(router)), 0);
        assertEq(tokenOut.balanceOf(address(spender)), 0);
        assertEq(tokenOut.balanceOf(address(user)), amountIn);
    }

    function _logicSpenderAaveV2Delegation(address asset, uint256 amount, uint256 interestRateMode)
        public
        view
        returns (IRouter.Logic memory)
    {
        // Encode logic
        IRouter.AmountInConfig[] memory configs = new IRouter.AmountInConfig[](0);

        return IRouter.Logic(
            address(spender), // to
            configs,
            abi.encodeWithSelector(ISpenderAaveV2Delegation.borrow.selector, asset, amount, interestRateMode)
        );
    }
}
