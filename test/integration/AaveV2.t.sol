// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {SafeERC20, IERC20} from 'openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol';
import {Router, IRouter} from '../../src/Router.sol';
import {SpenderERC20Approval, ISpenderERC20Approval} from '../../src/SpenderERC20Approval.sol';
import {SpenderAaveV2Delegation, ISpenderAaveV2Delegation, IAaveV2Provider} from '../../src/SpenderAaveV2Delegation.sol';
import {FlashLoanCallbackAaveV2, IFlashLoanCallbackAaveV2} from '../../src/FlashLoanCallbackAaveV2.sol';
import {IAaveV2Pool} from '../../src/interfaces/aaveV2/IAaveV2Pool.sol';

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
    IERC20 public constant USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    IERC20 public constant AUSDC_V2 = IERC20(0xBcca60bB61934080951369a648Fb03DF4F96263C);
    IDebtToken public constant AUSDC_V2_DEBT_VARIABLE = IDebtToken(0x619beb58998eD2278e08620f97007e1116D5D25b);
    uint256 public constant BPS_BASE = 10_000;
    uint256 public constant NO_CHAINED_INPUT = type(uint256).max;

    address public user;
    IRouter public router;
    ISpenderERC20Approval public spenderERC20;
    ISpenderAaveV2Delegation public spender;
    IFlashLoanCallbackAaveV2 public flashLoanCallback;
    IAaveV2Pool pool = IAaveV2Pool(IAaveV2Provider(aaveV2Provider).getLendingPool());

    // Empty arrays
    address[] tokensReturnEmpty;
    IRouter.Input[] inputsEmpty;
    IRouter.Output[] outputsEmpty;

    function setUp() external {
        user = makeAddr('User');

        router = new Router();
        spenderERC20 = new SpenderERC20Approval(address(router));
        spender = new SpenderAaveV2Delegation(address(router), address(aaveV2Provider));
        flashLoanCallback = new FlashLoanCallbackAaveV2(address(router), address(aaveV2Provider));

        // User approved spender aave v2 delegation
        vm.startPrank(user);
        USDC.safeApprove(address(spenderERC20), type(uint256).max);
        AUSDC_V2.safeApprove(address(spenderERC20), type(uint256).max);
        AUSDC_V2_DEBT_VARIABLE.approveDelegation(address(spender), type(uint256).max);
        vm.stopPrank();

        vm.label(address(router), 'Router');
        vm.label(address(spenderERC20), 'SpenderERC20Approval');
        vm.label(address(spender), 'SpenderAaveV2Delegation');
        vm.label(address(aaveV2Provider), 'AaveV2Provider');
        vm.label(address(pool), 'AaveV2Pool');
        vm.label(address(USDC), 'USDC');
        vm.label(address(AUSDC_V2), 'aUSDC');
        vm.label(address(AUSDC_V2_DEBT_VARIABLE), 'variableDebtUSDC');
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
        assertEq(tokenOut.balanceOf(user), amountIn);
    }

    function testExecuteAaveV2Deposit(uint256 amountIn) external {
        // aToken would be 1 wei short
        IERC20 token = USDC;
        IERC20 tokenOut = AUSDC_V2;
        amountIn = bound(amountIn, 1, token.totalSupply());
        uint256 amountMin = amountIn - 1; // would get 1 wei less aToken

        deal(address(token), user, amountIn);

        // Encode logics
        IRouter.Logic[] memory logics = new IRouter.Logic[](2);
        logics[0] = _logicSpenderERC20Approval(token, amountIn);
        logics[1] = _logicAaveV2Deposit(
            address(token),
            amountIn,
            BPS_BASE,
            NO_CHAINED_INPUT,
            address(router),
            address(tokenOut),
            amountMin
        );

        address[] memory tokensReturn = new address[](1);
        tokensReturn[0] = address(tokenOut);

        // Execute
        vm.prank(user);
        router.execute(logics, tokensReturn);

        assertEq(tokenOut.balanceOf(address(router)), 0);
        assertEq(tokenOut.balanceOf(address(spenderERC20)), 0);
        assertGe(tokenOut.balanceOf(user), amountMin);
    }

    function testExecuteAaveV2DepositWithdraw(uint256 amountIn) external {
        // aToken would be 1 wei short
        IERC20 token = USDC;
        IERC20 tokenOut = AUSDC_V2;
        amountIn = bound(amountIn, 2, token.totalSupply()); // at least 2 wei because cannot burn zero amount
        uint256 amountMin = amountIn - 1; // would get 1 wei less aToken

        deal(address(token), user, amountIn);

        // Encode logics
        IRouter.Logic[] memory logics = new IRouter.Logic[](3);
        logics[0] = _logicSpenderERC20Approval(token, amountIn);
        logics[1] = _logicAaveV2Deposit(
            address(token),
            amountIn,
            BPS_BASE,
            NO_CHAINED_INPUT,
            address(router),
            address(tokenOut),
            amountMin
        );
        logics[2] = _logicAaveV2Withdraw(
            address(tokenOut),
            BPS_BASE,
            NO_CHAINED_INPUT,
            address(token),
            amountMin, // cannot use amountIn because aToken amount(amountMin) would be 1 wei less
            address(router)
        );

        address[] memory tokensReturn = new address[](2);
        tokensReturn[0] = address(token);
        tokensReturn[1] = address(tokenOut);

        // Execute
        vm.prank(user);
        router.execute(logics, tokensReturn);

        assertEq(tokenOut.balanceOf(address(router)), 0);
        assertEq(tokenOut.balanceOf(address(spenderERC20)), 0);
        assertLe(tokenOut.balanceOf(user), 1); // would burn 1 wei less aToken and leave 1 wei in user balance
        assertEq(token.balanceOf(address(router)), 0);
        assertEq(token.balanceOf(address(spenderERC20)), 0);
        assertEq(token.balanceOf(user), amountMin);
    }

    function testExecuteAaveV2Withdraw(uint256 amountIn) external {
        // aToken would be 2 wei short
        IERC20 token = AUSDC_V2;
        IERC20 tokenOut = USDC;
        amountIn = bound(amountIn, 3, token.totalSupply()); // at least 3 wei because cannot burn zero amount
        uint256 amountMin = amountIn - 1; // would get 1 wei less aToken

        // Setup collateral
        deal(address(tokenOut), user, amountIn);
        vm.startPrank(user);
        tokenOut.safeApprove(address(pool), amountIn);
        pool.deposit(address(tokenOut), amountIn, user, 0); // would get 1 wei less aToken
        vm.stopPrank();

        // Encode logics
        IRouter.Logic[] memory logics = new IRouter.Logic[](2);
        logics[0] = _logicSpenderERC20Approval(token, amountMin); // would get 1 wei less aToken
        logics[1] = _logicAaveV2Withdraw(
            address(token),
            BPS_BASE,
            NO_CHAINED_INPUT,
            address(tokenOut),
            amountMin - 1, // cannot use amountIn because aToken amount(amountMin) would be 2 wei less
            address(router)
        );

        address[] memory tokensReturn = new address[](2);
        tokensReturn[0] = address(token);
        tokensReturn[1] = address(tokenOut);

        // Execute
        vm.prank(user);
        router.execute(logics, tokensReturn);

        assertEq(token.balanceOf(address(router)), 0);
        assertEq(token.balanceOf(address(spenderERC20)), 0);
        assertLe(token.balanceOf(user), 2); // would burn 2 wei less aToken and leave 2 wei in user balance
        assertEq(tokenOut.balanceOf(address(router)), 0);
        assertEq(tokenOut.balanceOf(address(spenderERC20)), 0);
        assertEq(tokenOut.balanceOf(user), amountMin - 1); // would get 2 wei less underlying token
    }

    function testExecuteAaveV2FlashLoan(uint256 amountIn) external {
        vm.assume(amountIn > 1e6);
        IERC20 token = USDC;
        amountIn = bound(amountIn, 1, token.balanceOf(address(AUSDC_V2)));
        vm.label(address(token), 'Token');

        address[] memory tokens = new address[](1);
        tokens[0] = address(token);

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amountIn;

        uint256[] memory modes = new uint256[](1);
        modes[0] = uint256(InterestRateMode.NONE);

        // Encode logics
        IRouter.Logic[] memory logics = new IRouter.Logic[](1);
        logics[0] = _logicAaveV2FlashLoan(tokens, amounts, modes);

        // Execute
        vm.prank(user);
        router.execute(logics, tokensReturnEmpty);

        assertEq(token.balanceOf(address(router)), 0);
        assertEq(token.balanceOf(address(flashLoanCallback)), 0);
        assertEq(token.balanceOf(user), 0);
    }

    function _logicSpenderERC20Approval(IERC20 tokenIn, uint256 amountIn) public view returns (IRouter.Logic memory) {
        return
            IRouter.Logic(
                address(spenderERC20), // to
                abi.encodeWithSelector(spenderERC20.pullToken.selector, address(tokenIn), amountIn),
                inputsEmpty,
                outputsEmpty,
                address(0) // callback
            );
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

    function _logicAaveV2Deposit(
        address tokenIn,
        uint256 amountIn,
        uint256 amountBps,
        uint256 amountOffset,
        address onBehalfOf,
        address tokenOut,
        uint256 amountMin
    ) public view returns (IRouter.Logic memory) {
        // Encode logic
        uint16 referralCode = 0;

        bytes memory data = abi.encodeWithSelector(
            IAaveV2Pool.deposit.selector,
            tokenIn,
            amountIn,
            onBehalfOf,
            referralCode
        );

        // Encode inputs
        IRouter.Input[] memory inputs = new IRouter.Input[](1);
        inputs[0].token = tokenIn;
        inputs[0].amountBps = amountBps;
        inputs[0].amountOffset = amountOffset;
        inputs[0].doApprove = true;

        // Encode outputs
        IRouter.Output[] memory outputs = new IRouter.Output[](1);
        outputs[0].token = address(tokenOut);
        outputs[0].amountMin = amountMin;

        return
            IRouter.Logic(
                address(pool), // to
                data,
                inputs,
                outputs,
                address(0) // callback
            );
    }

    function _logicAaveV2Withdraw(
        address aToken,
        uint256 amountBps,
        uint256 amountOffset,
        address underlyingToken,
        uint256 amountMin,
        address to
    ) public view returns (IRouter.Logic memory) {
        // Encode logic
        bytes memory data = abi.encodeWithSelector(IAaveV2Pool.withdraw.selector, underlyingToken, amountMin, to);

        // Encode inputs
        IRouter.Input[] memory inputs = new IRouter.Input[](1);
        inputs[0].token = aToken;
        inputs[0].amountBps = amountBps;
        inputs[0].amountOffset = amountOffset;
        inputs[0].doApprove = false;

        // Encode outputs
        IRouter.Output[] memory outputs = new IRouter.Output[](1);
        outputs[0].token = address(underlyingToken);
        outputs[0].amountMin = amountMin;

        return
            IRouter.Logic(
                address(pool), // to
                data,
                inputs,
                outputs,
                address(0) // callback
            );
    }

    function _logicAaveV2FlashLoan(
        address[] memory tokens,
        uint256[] memory amounts,
        uint256[] memory modes
    ) public returns (IRouter.Logic memory) {
        // Encode logic
        address receiverAddress = address(flashLoanCallback);
        address onBehalfOf = address(0);
        bytes memory params = _encodeExecute(tokens, amounts);
        uint16 referralCode = 0;

        return
            IRouter.Logic(
                address(pool), // to
                abi.encodeWithSelector(
                    IAaveV2Pool.flashLoan.selector,
                    receiverAddress,
                    tokens,
                    amounts,
                    modes,
                    onBehalfOf,
                    params,
                    referralCode
                ),
                inputsEmpty,
                outputsEmpty,
                address(flashLoanCallback) // callback
            );
    }

    function _encodeExecute(address[] memory tokens, uint256[] memory amounts) public returns (bytes memory) {
        // Encode logics
        IRouter.Logic[] memory logics = new IRouter.Logic[](tokens.length);
        for (uint256 i = 0; i < tokens.length; i++) {
            // Airdrop fee to Router
            uint256 fee = (amounts[i] * 9) / 10000;
            deal(address(tokens[i]), address(router), fee);

            // Encode transfering token + fee to the flash loan callback
            logics[i] = IRouter.Logic(
                address(tokens[i]), // to
                abi.encodeWithSelector(IERC20.transfer.selector, address(flashLoanCallback), amounts[i] + fee),
                inputsEmpty,
                outputsEmpty,
                address(0) // callback
            );
        }

        // Encode execute data
        return abi.encodeWithSelector(IRouter.execute.selector, logics, tokensReturnEmpty);
    }
}
