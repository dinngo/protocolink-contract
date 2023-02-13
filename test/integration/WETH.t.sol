// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {SafeERC20, IERC20} from 'openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol';
import {Router, IRouter} from '../../src/Router.sol';

interface IWETH {
    function deposit() external payable;
}

// Test WETH for native token
contract WETHTest is Test {
    using SafeERC20 for IERC20;

    address public constant NATIVE = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    IERC20 public constant WETH = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    uint256 public constant BPS_BASE = 10_000;
    uint256 public constant SKIP = type(uint256).max;

    address public user;
    IRouter public router;

    function setUp() external {
        user = makeAddr('User');

        router = new Router();

        vm.label(address(router), 'Router');
        vm.label(address(WETH), 'WETH');
    }

    function testExecuteWETHDeposit(uint256 amountIn) external {
        amountIn = bound(amountIn, BPS_BASE, WETH.totalSupply());
        address tokenIn = NATIVE;
        IERC20 tokenOut = WETH;
        deal(user, amountIn + 1 ether);

        // Encode logics
        IRouter.Logic[] memory logics = new IRouter.Logic[](1);
        logics[0] = _logicWETHDeposit(amountIn, BPS_BASE / 2, tokenOut); // 50% amount

        // Execute
        address[] memory tokensReturn = new address[](2);
        tokensReturn[0] = tokenIn;
        tokensReturn[1] = address(tokenOut);
        vm.prank(user);
        router.execute{value: amountIn}(logics, tokensReturn);

        assertEq(address(router).balance, 0);
        assertEq(tokenOut.balanceOf(address(router)), 0);
        assertGt(user.balance, 0);
        assertGt(tokenOut.balanceOf(user), 0);
    }

    function _logicWETHDeposit(
        uint256 amountIn,
        uint256 amountBps,
        IERC20 tokenOut
    ) public pure returns (IRouter.Logic memory) {
        // Encode inputs
        IRouter.Input[] memory inputs = new IRouter.Input[](1);
        inputs[0].token = NATIVE;
        inputs[0].amountBps = amountBps;
        if (inputs[0].amountBps == SKIP) inputs[0].amountOrOffset = amountIn;
        else inputs[0].amountOrOffset = SKIP; // data don't have amount parameter

        // Encode outputs
        IRouter.Output[] memory outputs = new IRouter.Output[](1);
        outputs[0].token = address(tokenOut);
        outputs[0].amountMin = (amountIn * amountBps) / BPS_BASE;

        return
            IRouter.Logic(
                address(WETH), // to
                abi.encodeWithSelector(IWETH.deposit.selector),
                inputs,
                outputs,
                address(0), // approveTo
                address(0) // callback
            );
    }
}
