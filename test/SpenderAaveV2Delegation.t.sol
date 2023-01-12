// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {SafeERC20, IERC20} from 'openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol';
import {Router, IRouter} from '../src/Router.sol';
import {SpenderAaveV2Delegation, ISpenderAaveV2Delegation, IAaveV2Provider} from '../src/SpenderAaveV2Delegation.sol';
import {IAaveV2Pool} from '../src/interfaces/aaveV2/IAaveV2Pool.sol';
import {MockERC20} from './mocks/MockERC20.sol';

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

    IAaveV2Provider public constant aaveV2Provider = IAaveV2Provider(0xB53C1a33016B2DC2fF3653530bfF1848a515c8c5);
    address public constant AUSDC_V2 = 0xBcca60bB61934080951369a648Fb03DF4F96263C;
    IDebtToken public constant AUSDC_V2_DEBT_VARIABLE = IDebtToken(0x619beb58998eD2278e08620f97007e1116D5D25b);

    address public user;
    IRouter public router;
    ISpenderAaveV2Delegation public spender;
    IERC20 public mockERC20;
    IAaveV2Pool pool = IAaveV2Pool(IAaveV2Provider(aaveV2Provider).getLendingPool());

    // Empty arrays
    IRouter.Input[] inputsEmpty;

    function setUp() external {
        user = makeAddr('user');

        router = new Router();
        spender = new SpenderAaveV2Delegation(address(router), address(aaveV2Provider));
        mockERC20 = new MockERC20('Mock ERC20', 'mERC20');

        // User approved spender aave v2 delegation
        vm.startPrank(user);
        AUSDC_V2_DEBT_VARIABLE.approveDelegation(address(spender), type(uint256).max);
        vm.stopPrank();

        vm.label(address(router), 'Router');
        vm.label(address(spender), 'SpenderAaveV2Delegation');
        vm.label(address(mockERC20), 'mERC20');
        vm.label(address(aaveV2Provider), 'AaveV2Provider');
        vm.label(address(pool), 'AaveV2Pool');
        vm.label(address(AUSDC_V2), 'aUSDC');
        vm.label(address(AUSDC_V2_DEBT_VARIABLE), 'variableDebtUSDC');
    }

    // Cannot call spender directly
    function testCannotBeCalledByNonRouter(uint128 amount) external {
        vm.assume(amount > 0);
        deal(address(mockERC20), user, amount);

        vm.startPrank(user);
        vm.expectRevert(ISpenderAaveV2Delegation.InvalidRouter.selector);
        spender.borrow(address(mockERC20), amount, uint256(InterestRateMode.VARIABLE));
        vm.stopPrank();
    }

    function testExecuteAaveV2Borrow(uint256 amountIn) external {
        vm.assume(amountIn > 1e8);
        IDebtToken tokenIn = AUSDC_V2_DEBT_VARIABLE;
        IERC20 tokenOut = IERC20(tokenIn.UNDERLYING_ASSET_ADDRESS());
        amountIn = bound(amountIn, 1, tokenIn.totalSupply());
        vm.label(address(tokenOut), 'Token');

        // Setup collateral
        vm.startPrank(user);
        uint256 collateralAmount = amountIn * 3;
        deal(address(tokenOut), user, collateralAmount);
        tokenOut.safeApprove(address(pool), collateralAmount);
        pool.deposit(address(tokenOut), collateralAmount, user, 0);
        vm.stopPrank();

        // Encode logics
        IRouter.Logic[] memory logics = new IRouter.Logic[](1);
        logics[0] = _logicSpenderAaveV2Delegation(tokenOut, amountIn, uint256(InterestRateMode.VARIABLE));

        // Execute
        address[] memory tokensReturn = new address[](1);
        tokensReturn[0] = address(tokenOut);
        vm.prank(user);
        router.execute(logics, tokensReturn);

        assertEq(tokenOut.balanceOf(address(router)), 0);
        assertEq(tokenOut.balanceOf(address(spender)), 0);
        assertEq(tokenOut.balanceOf(address(user)), amountIn);
    }

    function _logicSpenderAaveV2Delegation(
        IERC20 token,
        uint256 amount,
        uint256 interestRateMode
    ) public view returns (IRouter.Logic memory) {
        // Encode outputs
        IRouter.Output[] memory outputs = new IRouter.Output[](1);
        outputs[0].token = address(token);
        outputs[0].amountMin = amount;

        return
            IRouter.Logic(
                address(spender), // to
                abi.encodeWithSelector(ISpenderAaveV2Delegation.borrow.selector, token, amount, interestRateMode),
                inputsEmpty,
                outputs,
                address(0) // callback
            );
    }
}
