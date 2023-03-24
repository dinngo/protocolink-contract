// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {SafeERC20, IERC20} from 'openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol';
import {IAgent} from '../../src/interfaces/IAgent.sol';
import {Router, IRouter} from '../../src/Router.sol';
import {IParam} from '../../src/interfaces/IParam.sol';
import {IAaveV3Provider} from '../../src/interfaces/aaveV3/IAaveV3Provider.sol';
import {FlashLoanCallbackAaveV3, IFlashLoanCallbackAaveV3} from '../../src/FlashLoanCallbackAaveV3.sol';
import {IAaveV3Pool} from '../../src/interfaces/aaveV3/IAaveV3Pool.sol';

interface IDebtToken {
    function UNDERLYING_ASSET_ADDRESS() external view returns (address);

    function approveDelegation(address delegatee, uint256 amount) external;

    function totalSupply() external view returns (uint256);
}

contract AaveV3IntegrationTest is Test {
    using SafeERC20 for IERC20;

    enum InterestRateMode {
        NONE,
        STABLE,
        VARIABLE
    }

    uint16 private constant _REFERRAL_CODE = 56;
    IAaveV3Provider public constant AAVE_V3_PROVIDER = IAaveV3Provider(0x2f39d218133AFaB8F2B819B1066c7E434Ad94E9e);
    IERC20 public constant USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    address public constant AUSDC_V3 = 0x98C23E9d8f34FEFb1B7BD6a91B7FF122F4e16F5c;
    IDebtToken public constant AUSDC_V3_DEBT_VARIABLE = IDebtToken(0x72E95b8931767C79bA4EeE721354d6E99a61D004);

    address public user;
    IRouter public router;
    IAgent public agent;
    IFlashLoanCallbackAaveV3 public flashLoanCallback;
    IAaveV3Pool pool = IAaveV3Pool(IAaveV3Provider(AAVE_V3_PROVIDER).getPool());

    // Empty arrays
    address[] tokensReturnEmpty;
    IParam.Input[] inputsEmpty;

    function setUp() external {
        user = makeAddr('User');
        router = new Router(makeAddr('Pauser'), makeAddr('FeeCollector'));
        vm.prank(user);
        agent = IAgent(router.newAgent());
        flashLoanCallback = new FlashLoanCallbackAaveV3(address(router), address(AAVE_V3_PROVIDER));

        // User approved agent aave v3 delegation
        vm.startPrank(user);
        AUSDC_V3_DEBT_VARIABLE.approveDelegation(address(agent), type(uint256).max);
        vm.stopPrank();

        vm.label(address(router), 'Router');
        vm.label(address(agent), 'Agent');
        vm.label(address(AAVE_V3_PROVIDER), 'AaveV3Provider');
        vm.label(address(pool), 'AaveV3Pool');
        vm.label(address(USDC), 'USDC');
        vm.label(address(AUSDC_V3), 'aUSDC');
        vm.label(address(AUSDC_V3_DEBT_VARIABLE), 'variableDebtUSDC');
    }

    function testExecuteAaveV3Borrow(uint256 amountIn) external {
        vm.assume(amountIn > 1e8);
        IDebtToken tokenIn = AUSDC_V3_DEBT_VARIABLE;
        IERC20 tokenOut = IERC20(tokenIn.UNDERLYING_ASSET_ADDRESS());
        amountIn = bound(amountIn, 1, tokenIn.totalSupply());
        vm.label(address(tokenOut), 'Token');

        // Setup collateral
        vm.startPrank(user);
        uint256 collateralAmount = amountIn * 3;
        deal(address(tokenOut), user, collateralAmount);
        tokenOut.safeApprove(address(pool), collateralAmount);
        pool.supply(address(tokenOut), collateralAmount, user, 0);
        vm.stopPrank();

        // Encode logics
        IParam.Logic[] memory logics = new IParam.Logic[](1);
        logics[0] = _logicSpenderAaveV3Delegation(tokenOut, amountIn, uint256(InterestRateMode.VARIABLE));

        // Execute
        address[] memory tokensReturn = new address[](1);
        tokensReturn[0] = address(tokenOut);
        vm.prank(user);
        router.execute(logics, tokensReturn);

        assertEq(tokenOut.balanceOf(address(router)), 0);
        assertEq(tokenOut.balanceOf(address(agent)), 0);
        assertEq(tokenOut.balanceOf(user), amountIn);
    }

    function testExecuteAaveV3FlashLoan(uint256 amountIn) external {
        vm.assume(amountIn > 1e6);
        IERC20 token = USDC;
        amountIn = bound(amountIn, 1, token.balanceOf(AUSDC_V3));
        vm.label(address(token), 'Token');

        address[] memory tokens = new address[](1);
        tokens[0] = address(token);

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amountIn;

        uint256[] memory modes = new uint256[](1);
        modes[0] = uint256(InterestRateMode.NONE);

        // Encode logics
        IParam.Logic[] memory logics = new IParam.Logic[](1);
        logics[0] = _logicAaveV3FlashLoan(tokens, amounts, modes);

        // Execute
        vm.prank(user);
        router.execute(logics, tokensReturnEmpty);

        assertEq(token.balanceOf(address(router)), 0);
        assertEq(token.balanceOf(address(agent)), 0);
        assertEq(token.balanceOf(address(flashLoanCallback)), 0);
        assertEq(token.balanceOf(user), 0);
    }

    function _logicSpenderAaveV3Delegation(
        IERC20 token,
        uint256 amount,
        uint256 interestRateMode
    ) public view returns (IParam.Logic memory) {
        return
            IParam.Logic(
                address(pool), // to
                abi.encodeWithSelector(
                    IAaveV3Pool.borrow.selector,
                    token,
                    amount,
                    interestRateMode,
                    _REFERRAL_CODE,
                    user
                ),
                inputsEmpty,
                address(0), // approveTo
                address(0) // callback
            );
    }

    function _logicAaveV3FlashLoan(
        address[] memory tokens,
        uint256[] memory amounts,
        uint256[] memory modes
    ) public returns (IParam.Logic memory) {
        // Encode logic
        address receiverAddress = address(flashLoanCallback);
        address onBehalfOf = address(0);
        bytes memory params = _encodeExecute(tokens, amounts);
        uint16 referralCode = 0;

        return
            IParam.Logic(
                address(pool), // to
                abi.encodeWithSelector(
                    IAaveV3Pool.flashLoan.selector,
                    receiverAddress,
                    tokens,
                    amounts,
                    modes,
                    onBehalfOf,
                    params,
                    referralCode
                ),
                inputsEmpty,
                address(0), // approveTo
                address(flashLoanCallback) // callback
            );
    }

    function _encodeExecute(address[] memory tokens, uint256[] memory amounts) public returns (bytes memory) {
        // Encode logics
        IParam.Logic[] memory logics = new IParam.Logic[](tokens.length);
        uint256 percentage = pool.FLASHLOAN_PREMIUM_TOTAL();

        for (uint256 i = 0; i < tokens.length; ) {
            // Airdrop fee to Agent
            uint256 fee = _percentMul(amounts[i], percentage);
            deal(address(tokens[i]), address(agent), fee);

            // Encode transfering token + fee to the flash loan callback
            logics[i] = IParam.Logic(
                address(tokens[i]), // to
                abi.encodeWithSelector(IERC20.transfer.selector, address(flashLoanCallback), amounts[i] + fee),
                inputsEmpty,
                address(0), // approveTo
                address(0) // callback
            );

            unchecked {
                ++i;
            }
        }

        // Encode execute data
        return abi.encodeWithSelector(IAgent.execute.selector, logics, tokensReturnEmpty);
    }

    function _percentMul(uint256 value, uint256 percentage) internal pure returns (uint256 result) {
        // Fork PercentageMath of AAVEV3.
        // From https://github.com/aave/aave-v3-core/blob/master/contracts/protocol/libraries/math/PercentageMath.sol#L48

        // to avoid overflow, value <= (type(uint256).max - HALF_PERCENTAGE_FACTOR) / percentage
        uint256 PERCENTAGE_FACTOR = 1e4;
        uint256 HALF_PERCENTAGE_FACTOR = 0.5e4;
        assembly {
            if iszero(or(iszero(percentage), iszero(gt(value, div(sub(not(0), HALF_PERCENTAGE_FACTOR), percentage))))) {
                revert(0, 0)
            }

            result := div(add(mul(value, percentage), HALF_PERCENTAGE_FACTOR), PERCENTAGE_FACTOR)
        }
    }
}
