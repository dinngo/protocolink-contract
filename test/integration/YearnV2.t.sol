// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {SafeERC20, IERC20} from 'openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol';
import {Router, IRouter} from '../../src/Router.sol';
import {IParam} from '../../src/interfaces/IParam.sol';
import {SpenderPermitUtils} from '../utils/SpenderPermitUtils.sol';

interface IYVault {
    function deposit(uint256) external;

    function balanceOf(address) external returns (uint256);
}

// Test Yearn V2 which is also an ERC20-compliant token
contract YearnV2Test is Test, SpenderPermitUtils {
    using SafeERC20 for IERC20;

    IERC20 public constant USDT = IERC20(0xdAC17F958D2ee523a2206206994597C13D831ec7); // USDT
    IYVault public constant yVault = IYVault(0x2f08119C6f07c006695E079AAFc638b8789FAf18); // yUSDT
    uint256 public constant BPS_BASE = 10_000;
    uint256 public constant SKIP = type(uint256).max;

    address public user;
    uint256 public userPrivateKey;
    IRouter public router;

    // Empty arrays
    IParam.Input[] inputsEmpty;
    IParam.Output[] outputsEmpty;

    function setUp() external {
        (user, userPrivateKey) = makeAddrAndKey('User');
        router = new Router();

        // User permit token
        spenderSetUp(user, userPrivateKey, router);
        permitToken(USDT);

        vm.label(address(router), 'Router');
        vm.label(address(spender), 'SpenderPermit2ERC20');
        vm.label(address(USDT), 'USDT');
        vm.label(address(yVault), 'yVault');
    }

    function testExecuteYearn(uint128 amountIn) external {
        vm.assume(amountIn > 1);
        IERC20 tokenIn = USDT;
        IERC20 tokenOut = IERC20(address(yVault));
        deal(address(tokenIn), user, amountIn);

        // Encode logics
        IParam.Logic[] memory logics = new IParam.Logic[](2);
        logics[0] = logicSpenderPermit2ERC20PullToken(tokenIn, uint160(amountIn));
        logics[1] = _logicYearn(tokenIn, amountIn, BPS_BASE, tokenOut);

        // Execute
        address[] memory tokensReturn = new address[](1);
        tokensReturn[0] = address(tokenOut);
        vm.prank(user);
        router.execute(logics, tokensReturn);

        assertEq(tokenIn.balanceOf(address(router)), 0);
        assertEq(yVault.balanceOf(address(router)), 0);
        assertGt(yVault.balanceOf(user), 0);
    }

    function _logicYearn(
        IERC20 tokenIn,
        uint256 amountIn,
        uint256 amountBps,
        IERC20 tokenOut
    ) public pure returns (IParam.Logic memory) {
        // FIXME: it's relaxed amountMin = amountIn * 90%
        uint256 amountMin = (amountIn * 9_000) / BPS_BASE;

        // Encode inputs
        IParam.Input[] memory inputs = new IParam.Input[](1);
        inputs[0].token = address(tokenIn);
        inputs[0].amountBps = amountBps;
        if (inputs[0].amountBps == SKIP) inputs[0].amountOrOffset = amountIn;
        else inputs[0].amountOrOffset = 0;

        // Encode outputs
        IParam.Output[] memory outputs = new IParam.Output[](1);
        outputs[0].token = address(tokenOut);
        outputs[0].amountMin = amountMin;

        return
            IParam.Logic(
                address(yVault), // to
                abi.encodeWithSelector(yVault.deposit.selector, 0), // amount will be replaced with balance
                inputs,
                outputs,
                address(0), // approveTo
                address(0) // callback
            );
    }
}
