// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {SafeERC20, IERC20} from 'openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol';
import {Router, IRouter} from '../../src/Router.sol';
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
    address public constant AUSDC_V2 = 0xBcca60bB61934080951369a648Fb03DF4F96263C;
    IDebtToken public constant AUSDC_V2_DEBT_VARIABLE = IDebtToken(0x619beb58998eD2278e08620f97007e1116D5D25b);

    address public user;
    IRouter public router;
    ISpenderAaveV2Delegation public spender;
    IFlashLoanCallbackAaveV2 public flashLoanCallback;
    IAaveV2Pool pool = IAaveV2Pool(IAaveV2Provider(aaveV2Provider).getLendingPool());

    // Empty arrays
    address[] tokensReturnEmpty;
    IRouter.Input[] inputsEmpty;
    IRouter.Output[] outputsEmpty;

    function setUp() external {
        user = makeAddr('user');

        router = new Router();
        spender = new SpenderAaveV2Delegation(address(router), address(aaveV2Provider));
        flashLoanCallback = new FlashLoanCallbackAaveV2(address(router), address(aaveV2Provider));

        // User approved spender aave v2 delegation
        vm.startPrank(user);
        AUSDC_V2_DEBT_VARIABLE.approveDelegation(address(spender), type(uint256).max);
        vm.stopPrank();

        vm.label(address(router), 'Router');
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
        assertEq(tokenOut.balanceOf(address(user)), amountIn);
    }

    function testExecuteAaveV2FlashLoan(uint256 amountIn) external {
        vm.assume(amountIn > 1e6);
        IERC20 token = USDC;
        amountIn = bound(amountIn, 1, token.balanceOf(AUSDC_V2));
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
        assertEq(token.balanceOf(address(user)), 0);
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
