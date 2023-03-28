// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {SafeERC20, IERC20} from 'openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol';
import {SafeCast160} from 'permit2/libraries/SafeCast160.sol';
import {IAgent} from 'src/interfaces/IAgent.sol';
import {Router, IRouter} from 'src/Router.sol';
import {IParam} from 'src/interfaces/IParam.sol';
import {SpenderPermitUtils} from '../utils/SpenderPermitUtils.sol';

interface IUniswapV2Factory {
    function getPair(address tokenA, address tokenB) external view returns (address pair);
}

interface IUniswapV2Router02 {
    function factory() external view returns (address);

    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);

    function swapExactETHForTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable returns (uint[] memory amounts);

    function swapExactTokensForETH(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB, uint256 liquidity);

    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB);
}

// Test Uniswap whose Router is not ERC20-compliant token
contract UniswapV2Test is Test, SpenderPermitUtils {
    using SafeERC20 for IERC20;
    using SafeCast160 for uint256;

    address public constant NATIVE = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    IERC20 public constant WRAPPED_NATIVE = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IERC20 public constant USDT = IERC20(0xdAC17F958D2ee523a2206206994597C13D831ec7);
    IERC20 public constant USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    IUniswapV2Router02 public constant uniswapRouter02 = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
    uint256 public constant BPS_BASE = 10_000;
    uint256 public constant SKIP = type(uint256).max;

    address public user;
    uint256 public userPrivateKey;
    IRouter public router;
    IAgent public agent;

    // Empty arrays
    IParam.Input[] inputsEmpty;

    function setUp() external {
        (user, userPrivateKey) = makeAddrAndKey('User');
        router = new Router(makeAddr('Pauser'), makeAddr('FeeCollector'));
        vm.prank(user);
        agent = IAgent(router.newAgent());

        // User permit token
        spenderSetUp(user, userPrivateKey, router, agent);
        permitToken(USDT);
        permitToken(USDC);

        // Empty router the balance
        vm.prank(address(router));
        (bool success, ) = payable(address(0)).call{value: address(router).balance}('');
        assertTrue(success);

        vm.label(address(router), 'Router');
        vm.label(address(agent), 'Agent');
        vm.label(NATIVE, 'NATIVE');
        vm.label(address(WRAPPED_NATIVE), 'WrappedNative');
        vm.label(address(USDT), 'USDT');
        vm.label(address(USDC), 'USDC');
        vm.label(address(uniswapRouter02), 'uniswapRouter02');
    }

    function testExecuteUniswapV2SwapNativeToToken(uint256 amountIn) external {
        IERC20 tokenOut = USDT;
        amountIn = bound(amountIn, 1e12, 1e22);
        deal(user, amountIn);

        // Encode logics
        IParam.Logic[] memory logics = new IParam.Logic[](1);
        logics[0] = _logicUniswapV2SwapNativeToToken(amountIn, SKIP, tokenOut); // Fixed amount

        // Execute
        address[] memory tokensReturn = new address[](1);
        tokensReturn[0] = address(tokenOut);
        vm.prank(user);
        router.execute{value: amountIn}(logics, tokensReturn, SIGNER_REFERRAL);

        assertEq(address(router).balance, 0);
        assertEq(address(agent).balance, 0);
        assertEq(tokenOut.balanceOf(address(router)), 0);
        assertEq(tokenOut.balanceOf(address(agent)), 0);
        assertGt(tokenOut.balanceOf(user), 0);
    }

    function testExecuteUniswapV2SwapTokenToNative(uint256 amountIn) external {
        IERC20 tokenIn = USDT;
        amountIn = bound(amountIn, 1e6, 1e12);
        deal(address(tokenIn), user, amountIn);

        // Encode logics
        IParam.Logic[] memory logics = new IParam.Logic[](2);
        logics[0] = logicSpenderPermit2ERC20PullToken(tokenIn, amountIn.toUint160());
        logics[1] = _logicUniswapV2SwapTokenToNative(tokenIn, amountIn, SKIP); // Fixed amount

        // Execute
        address[] memory tokensReturn = new address[](1);
        tokensReturn[0] = NATIVE;
        vm.prank(user);
        router.execute(logics, tokensReturn, SIGNER_REFERRAL);

        assertEq(tokenIn.balanceOf(address(router)), 0);
        assertEq(tokenIn.balanceOf(address(agent)), 0);
        assertEq(address(router).balance, 0);
        assertEq(address(agent).balance, 0);
        assertGt(user.balance, 0);
    }

    function testExecuteUniswapV2SwapTokenToToken(uint256 amountIn) external {
        IERC20 tokenIn = USDT;
        IERC20 tokenOut = USDC;
        amountIn = bound(amountIn, 1e1, 1e12);
        deal(address(tokenIn), user, amountIn);

        // Encode logics
        IParam.Logic[] memory logics = new IParam.Logic[](2);
        logics[0] = logicSpenderPermit2ERC20PullToken(tokenIn, amountIn.toUint160());
        logics[1] = _logicUniswapV2Swap(tokenIn, amountIn / BPS_BASE, BPS_BASE, tokenOut);

        // Execute
        address[] memory tokensReturn = new address[](1);
        tokensReturn[0] = address(tokenOut);
        vm.prank(user);
        router.execute(logics, tokensReturn, SIGNER_REFERRAL);

        assertEq(tokenIn.balanceOf(address(router)), 0);
        assertEq(tokenOut.balanceOf(address(agent)), 0);
        assertGt(tokenOut.balanceOf(user), 0);
    }

    // 1. Swap 50% token0 to token1
    // 2. Add liquidity token0/token1
    // 3. Remove liquidity token0/token1
    // 4. Swap token1 to token0
    function testExecuteUniswapV2SwapAddRemoveSwap(uint256 amountIn0) external {
        IERC20 tokenIn0 = USDC;
        IERC20 tokenIn1 = USDT;
        IERC20 tokenOut = IERC20(
            IUniswapV2Factory(uniswapRouter02.factory()).getPair(address(tokenIn0), address(tokenIn1))
        );
        amountIn0 = bound(amountIn0, 1e6, 1e10);
        uint256 amountIn0Half = (amountIn0 * 5_000) / BPS_BASE;
        deal(address(tokenIn0), user, amountIn0);

        // Encode logics
        IParam.Logic[] memory logics = new IParam.Logic[](5);
        logics[0] = logicSpenderPermit2ERC20PullToken(tokenIn0, amountIn0.toUint160());
        logics[1] = _logicUniswapV2Swap(tokenIn0, amountIn0Half, BPS_BASE / 2, tokenIn1); // Swap 50% amountIn0 to amountIn1
        logics[2] = _logicUniswapV2AddLiquidity(tokenIn0, amountIn0Half, 0, tokenIn1); // Add liquidity with 50% amountIn0 and all amountIn1
        logics[3] = _logicUniswapV2RemoveLiquidity(tokenOut, 0, tokenIn0, amountIn0Half, tokenIn1); // Remove all liquidity
        logics[4] = _logicUniswapV2Swap(tokenIn1, amountIn0Half, BPS_BASE, tokenIn0); // 100% balance of tokenIn

        // Execute
        address[] memory tokensReturn = new address[](3);
        tokensReturn[0] = address(tokenIn0);
        tokensReturn[1] = address(tokenIn1); // Push intermediate token to ensure clean up Router
        tokensReturn[2] = address(tokenOut); // Push intermediate token to ensure clean up Router
        vm.prank(user);
        router.execute(logics, tokensReturn, SIGNER_REFERRAL);

        assertEq(tokenIn0.balanceOf(address(router)), 0);
        assertEq(tokenIn0.balanceOf(address(agent)), 0);
        assertEq(tokenIn1.balanceOf(address(router)), 0);
        assertEq(tokenIn1.balanceOf(address(agent)), 0);
        assertEq(tokenOut.balanceOf(address(router)), 0);
        assertEq(tokenOut.balanceOf(address(agent)), 0);
        assertApproxEqRel(tokenIn0.balanceOf(user), amountIn0, 0.01 * 1e18);
    }

    function _logicUniswapV2SwapNativeToToken(
        uint256 amountIn,
        uint256 amountBps,
        IERC20 tokenOut
    ) public view returns (IParam.Logic memory) {
        // Encode data
        address[] memory path = new address[](2);
        path[0] = address(WRAPPED_NATIVE);
        path[1] = address(tokenOut);
        uint256[] memory amountsOut = uniswapRouter02.getAmountsOut(amountIn, path);
        uint256 amountMin = amountsOut[1];
        bytes memory data = abi.encodeWithSelector(
            uniswapRouter02.swapExactETHForTokens.selector,
            amountMin, // amountOutMin
            path, // path
            address(agent), // to
            block.timestamp // deadline
        );

        // Encode inputs
        IParam.Input[] memory inputs = new IParam.Input[](1);
        inputs[0].token = NATIVE;
        inputs[0].amountBps = amountBps;
        if (inputs[0].amountBps == SKIP) inputs[0].amountOrOffset = amountIn;
        else inputs[0].amountOrOffset = SKIP;

        return
            IParam.Logic(
                address(uniswapRouter02), // to
                data,
                inputs,
                address(0), // approveTo
                address(0) // callback
            );
    }

    function _logicUniswapV2SwapTokenToNative(
        IERC20 tokenIn,
        uint256 amountIn,
        uint256 amountBps
    ) public view returns (IParam.Logic memory) {
        // Encode data
        address[] memory path = new address[](2);
        path[0] = address(tokenIn);
        path[1] = address(WRAPPED_NATIVE);
        uint256[] memory amountsOut = uniswapRouter02.getAmountsOut(amountIn, path);
        uint256 amountMin = (amountsOut[1] * 9_900) / BPS_BASE;
        bytes memory data = abi.encodeWithSelector(
            uniswapRouter02.swapExactTokensForETH.selector,
            amountIn, // amountIn
            amountMin, // amountOutMin
            path, // path
            address(agent), // to
            block.timestamp // deadline
        );

        // Encode inputs
        IParam.Input[] memory inputs = new IParam.Input[](1);
        inputs[0].token = address(tokenIn);
        inputs[0].amountBps = amountBps;
        if (inputs[0].amountBps == SKIP) inputs[0].amountOrOffset = amountIn;
        else inputs[0].amountOrOffset = 0;

        return
            IParam.Logic(
                address(uniswapRouter02), // to
                data,
                inputs,
                address(0), // approveTo
                address(0) // callback
            );
    }

    function _logicUniswapV2Swap(
        IERC20 tokenIn,
        uint256 amountIn,
        uint256 amountBps,
        IERC20 tokenOut
    ) public view returns (IParam.Logic memory) {
        // At least get 98% tokenIn since both are stablecoins
        uint256 amountMin = (amountIn * 9_800) / BPS_BASE;

        // Encode data
        address[] memory path = new address[](2);
        path[0] = address(tokenIn);
        path[1] = address(tokenOut);
        bytes memory data = abi.encodeWithSelector(
            uniswapRouter02.swapExactTokensForTokens.selector,
            0, // amountIn -> will be replaced with balance
            amountMin, // amountOutMin
            path, // path
            address(agent), // to
            block.timestamp // deadline
        );

        // Encode inputs
        IParam.Input[] memory inputs = new IParam.Input[](1);
        inputs[0].token = address(tokenIn);
        inputs[0].amountBps = amountBps;
        if (inputs[0].amountBps == SKIP) inputs[0].amountOrOffset = amountIn;
        else inputs[0].amountOrOffset = 0;

        return
            IParam.Logic(
                address(uniswapRouter02), // to
                data,
                inputs,
                address(0), // approveTo
                address(0) // callback
            );
    }

    function _logicUniswapV2AddLiquidity(
        IERC20 tokenIn0,
        uint256 amountIn0,
        uint256 amountIn1,
        IERC20 tokenIn1
    ) public view returns (IParam.Logic memory) {
        // At least adds 98% token0 to liquidity
        uint256 amountIn0Min = (amountIn0 * 9_800) / BPS_BASE;

        // Encode data
        bytes memory data = abi.encodeWithSelector(
            uniswapRouter02.addLiquidity.selector,
            tokenIn0, // tokenA
            tokenIn1, // tokenB,
            0, // amountADesired -> will be replaced with balance
            0, // amountBDesired -> will be replaced with balance
            amountIn0Min, //  amountAMin
            1, // amountBMin
            address(agent), // to
            block.timestamp // deadline
        );

        // Encode inputs
        IParam.Input[] memory inputs = new IParam.Input[](2);
        inputs[0].token = address(tokenIn0);
        inputs[1].token = address(tokenIn1);
        inputs[0].amountBps = BPS_BASE;
        inputs[1].amountBps = BPS_BASE;
        if (inputs[0].amountBps == SKIP) inputs[0].amountOrOffset = amountIn0;
        else inputs[0].amountOrOffset = 0x40;
        if (inputs[1].amountBps == SKIP) inputs[1].amountOrOffset = amountIn1;
        else inputs[1].amountOrOffset = 0x60;

        return
            IParam.Logic(
                address(uniswapRouter02), // to
                data,
                inputs,
                address(0), // approveTo
                address(0) // callback
            );
    }

    function _logicUniswapV2RemoveLiquidity(
        IERC20 tokenIn,
        uint256 amountIn,
        IERC20 tokenOut0,
        uint256 amountOut0,
        IERC20 tokenOut1
    ) public view returns (IParam.Logic memory) {
        // At least returns 98% token0 from liquidity
        uint256 amountOut0Min = (amountOut0 * 9_800) / BPS_BASE;

        // Encode data
        bytes memory data = abi.encodeWithSelector(
            uniswapRouter02.removeLiquidity.selector,
            tokenOut0, // tokenA
            tokenOut1, // tokenB,
            0, // liquidity -> will be replaced with balance
            amountOut0Min, //  amountAMin
            1, //  amountBMin
            address(agent), // to
            block.timestamp // deadline
        );

        // Encode inputs
        IParam.Input[] memory inputs = new IParam.Input[](1);
        inputs[0].token = address(tokenIn);
        inputs[0].amountBps = BPS_BASE;
        if (inputs[0].amountBps == SKIP) inputs[0].amountOrOffset = amountIn;
        else inputs[0].amountOrOffset = 0x40;

        return
            IParam.Logic(
                address(uniswapRouter02), // to
                data,
                inputs,
                address(0), // approveTo
                address(0) // callback
            );
    }
}
