// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {SafeERC20, IERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {Router, IRouter} from "../src/Router.sol";
import {SpenderERC20Approval, ISpenderERC20Approval} from "../src/SpenderERC20Approval.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {ICallback, MockCallback} from "./mocks/MockCallback.sol";

interface IYVault {
    function deposit(uint256) external;

    function balanceOf(address) external returns (uint256);
}

interface IUniswapV2Factory {
    function getPair(address tokenA, address tokenB) external view returns (address pair);
}

interface IUniswapV2Router02 {
    function factory() external view returns (address);

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

contract RouterTest is Test {
    using SafeERC20 for IERC20;

    IERC20 public constant USDT = IERC20(0xdAC17F958D2ee523a2206206994597C13D831ec7); // USDT
    IERC20 public constant USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48); // USDC
    IUniswapV2Router02 public constant uniswapRouter02 = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
    IYVault public constant yVault = IYVault(0x2f08119C6f07c006695E079AAFc638b8789FAf18); // yUSDT
    uint256 public constant BPS_BASE = 10_000;

    address public user;
    IRouter public router;
    ISpenderERC20Approval public spender;
    IERC20 public mockERC20;
    ICallback public mockCallback;

    // Empty arrays
    address[] tokensReturnEmpty;
    IRouter.Logic[] logicsEmpty;
    IRouter.Input[] inputsEmpty;
    IRouter.Output[] outputsEmpty;

    function setUp() external {
        user = makeAddr("user");

        router = new Router();
        spender = new SpenderERC20Approval(address(router));
        mockERC20 = new MockERC20("Mock ERC20", "mERC20");
        mockCallback = new MockCallback();

        // User approved spender
        vm.startPrank(user);
        USDT.safeApprove(address(spender), type(uint256).max);
        USDC.safeApprove(address(spender), type(uint256).max);
        vm.stopPrank();

        vm.label(address(router), "Router");
        vm.label(address(spender), "SpenderERC20Approval");
        vm.label(address(USDT), "USDT");
        vm.label(address(USDC), "USDC");
        vm.label(address(uniswapRouter02), "uniswapRouter02");
        vm.label(address(yVault), "yVault");
    }

    function testCannotExecuteByInvalidCallback() external {
        IRouter.Logic[] memory callbacks = new IRouter.Logic[](1);
        callbacks[0] = IRouter.Logic(
            address(mockERC20), // to
            abi.encodeWithSelector(IERC20.totalSupply.selector),
            inputsEmpty,
            outputsEmpty,
            address(0) // callback
        );
        bytes memory data = abi.encodeWithSelector(IRouter.execute.selector, callbacks, tokensReturnEmpty);
        IRouter.Logic[] memory logics = new IRouter.Logic[](1);
        logics[0] = IRouter.Logic(address(mockCallback), abi.encodeWithSelector(ICallback.callback.selector, data), inputsEmpty, outputsEmpty, address(router));
        vm.expectRevert(IRouter.InvalidCallback.selector);
        router.execute(logics, tokensReturnEmpty);
    }

    function testCannotEncodeApproveSig() external {
        IRouter.Logic[] memory logics = new IRouter.Logic[](1);
        logics[0] = IRouter.Logic(
            address(USDT), // to
            abi.encodeWithSelector(IERC20.approve.selector, user, 0),
            inputsEmpty,
            outputsEmpty,
            address(0) // callback
        );

        vm.expectRevert(IRouter.InvalidERC20Sig.selector);
        router.execute(logics, tokensReturnEmpty);
    }

    function testCannotEncodeTransferFromSig() external {
        IRouter.Logic[] memory logics = new IRouter.Logic[](1);
        logics[0] = IRouter.Logic(
            address(USDT), // to
            abi.encodeWithSelector(IERC20.transferFrom.selector, user, 0),
            inputsEmpty,
            outputsEmpty,
            address(0) // callback
        );

        vm.expectRevert(IRouter.InvalidERC20Sig.selector);
        router.execute(logics, tokensReturnEmpty);
    }

    function testCannotBeInvalidBps() external {
        IRouter.Logic[] memory logics = new IRouter.Logic[](1);
        IRouter.Input[] memory inputs = new IRouter.Input[](1);

        // Revert if amountBps = 0
        inputs[0] = IRouter.Input(
            address(0),
            0, // amountBps
            0,
            false
        );
        logics[0] = IRouter.Logic(
            address(0), // to
            "",
            inputs,
            outputsEmpty,
            address(0) // callback
        );
        vm.expectRevert(IRouter.InvalidBps.selector);
        router.execute(logics, tokensReturnEmpty);

        // Revert if amountBps = BPS_BASE + 1
        inputs[0] = IRouter.Input(
            address(0),
            BPS_BASE + 1, // amountBps
            0,
            false
        );
        logics[0] = IRouter.Logic(
            address(0), // to
            "",
            inputs,
            outputsEmpty,
            address(0) // callback
        );
        vm.expectRevert(IRouter.InvalidBps.selector);
        router.execute(logics, tokensReturnEmpty);
    }

    function testCannotUnresetCallback() external {
        IRouter.Logic[] memory logics = new IRouter.Logic[](1);
        logics[0] = IRouter.Logic(
            address(mockERC20), // to
            abi.encodeWithSelector(IERC20.totalSupply.selector),
            inputsEmpty,
            outputsEmpty,
            address(router) // callback
        );
        vm.expectRevert(IRouter.UnresetCallback.selector);
        router.execute(logics, tokensReturnEmpty);
    }

    // Test Logic.to is ERC20-compliant token.
    function testExecuteYearn(uint128 amountIn) external {
        vm.assume(amountIn > 1);
        IERC20 tokenIn = USDT;
        IERC20 tokenOut = IERC20(address(yVault));
        deal(address(tokenIn), user, amountIn);

        // Encode logics
        IRouter.Logic[] memory logics = new IRouter.Logic[](2);
        logics[0] = _logicSpenderERC20Approval(tokenIn, amountIn);
        logics[1] = _logicYearn(tokenIn, amountIn, tokenOut);

        // Execute
        address[] memory tokensReturn = new address[](1);
        tokensReturn[0] = address(tokenOut);
        vm.prank(user);
        router.execute(logics, tokensReturn);

        assertEq(tokenIn.balanceOf(address(router)), 0);
        assertEq(yVault.balanceOf(address(router)), 0);
        assertGt(yVault.balanceOf(address(user)), 0);
    }

    // Test Logic.to is not ERC20-compliant.
    function testExecuteUniswapV2Swap(uint256 amountIn) external {
        IERC20 tokenIn = USDT;
        IERC20 tokenOut = USDC;
        amountIn = bound(amountIn, 1e1, 1e12);
        deal(address(tokenIn), user, amountIn);

        // Encode logics
        IRouter.Logic[] memory logics = new IRouter.Logic[](2);
        logics[0] = _logicSpenderERC20Approval(tokenIn, amountIn);
        logics[1] = _logicUniswapV2Swap(tokenIn, amountIn / BPS_BASE, BPS_BASE, tokenOut);

        // Encode execute
        address[] memory tokensReturn = new address[](1);
        tokensReturn[0] = address(tokenOut);
        vm.prank(user);
        router.execute(logics, tokensReturn);

        assertEq(tokenIn.balanceOf(address(router)), 0);
        assertEq(tokenOut.balanceOf(address(router)), 0);
        assertGt(tokenOut.balanceOf(address(user)), 0);
    }

    // 1. Swap 50% token0 to token1
    // 2. Add liquidity token0/token1
    // 3. Remove liquidity token0/token1
    // 4. Swap token1 to token0
    function testExecuteUniswapV2SwapAddRemoveSwap(uint256 amountIn0) external {
        IERC20 tokenIn0 = USDC;
        IERC20 tokenIn1 = USDT;
        IERC20 tokenOut =
            IERC20(IUniswapV2Factory(uniswapRouter02.factory()).getPair(address(tokenIn0), address(tokenIn1)));
        amountIn0 = bound(amountIn0, 1e6, 1e10);
        uint256 amountIn0Half = amountIn0 * 5_000 / BPS_BASE;
        deal(address(tokenIn0), user, amountIn0);

        // Encode logics
        IRouter.Logic[] memory logics = new IRouter.Logic[](5);
        logics[0] = _logicSpenderERC20Approval(tokenIn0, amountIn0);
        logics[1] = _logicUniswapV2Swap(tokenIn0, amountIn0Half, BPS_BASE / 2, tokenIn1); // Swap 50% amountIn0 to amountIn1
        logics[2] = _logicUniswapV2AddLiquidity(tokenIn0, amountIn0Half, tokenIn1, tokenOut); // Add liquidity with 50% amountIn0 and all amountIn1
        logics[3] = _logicUniswapV2RemoveLiquidity(tokenOut, tokenIn0, amountIn0Half, tokenIn1); // Remove all liquidity
        logics[4] = _logicUniswapV2Swap(tokenIn1, amountIn0Half, BPS_BASE, tokenIn0); // 100% balance of tokenIn

        // Encode execute
        address[] memory tokensReturn = new address[](3);
        tokensReturn[0] = address(tokenIn0);
        tokensReturn[1] = address(tokenIn1); // Push intermediate token to ensure clean up Router
        tokensReturn[2] = address(tokenOut); // Push intermediate token to ensure clean up Router
        vm.prank(user);
        router.execute(logics, tokensReturn);

        assertEq(tokenIn0.balanceOf(address(router)), 0);
        assertEq(tokenIn1.balanceOf(address(router)), 0);
        assertEq(tokenOut.balanceOf(address(router)), 0);
        assertApproxEqRel(tokenIn0.balanceOf(address(user)), amountIn0, 0.01 * 1e18);
    }

    function _logicSpenderERC20Approval(IERC20 tokenIn, uint256 amountIn) public view returns (IRouter.Logic memory) {
        return IRouter.Logic(
            address(spender), // to
            abi.encodeWithSelector(spender.pullToken.selector, address(tokenIn), amountIn),
            inputsEmpty,
            outputsEmpty,
            address(0) // callback
        );
    }

    function _logicYearn(IERC20 tokenIn, uint256 amountIn, IERC20 tokenOut)
        public
        pure
        returns (IRouter.Logic memory)
    {
        // FIXME: it's relaxed amountMin = amountIn * 90%
        uint256 amountMin = amountIn * 9_000 / BPS_BASE;

        // Encode inputs
        IRouter.Input[] memory inputs = new IRouter.Input[](1);
        inputs[0].token = address(tokenIn);
        inputs[0].amountBps = BPS_BASE;
        inputs[0].amountOffset = 0;
        inputs[0].doApprove = true;

        // Encode outputs
        IRouter.Output[] memory outputs = new IRouter.Output[](1);
        outputs[0].token = address(tokenOut);
        outputs[0].amountMin = amountMin;

        return IRouter.Logic(
            address(yVault), // to
            abi.encodeWithSelector(yVault.deposit.selector, 0), // amount will be replaced with balance
            inputs,
            outputs,
            address(0) // callback
        );
    }

    function _logicUniswapV2Swap(IERC20 tokenIn, uint256 amountIn, uint256 amountBps, IERC20 tokenOut)
        public
        view
        returns (IRouter.Logic memory)
    {
        // At least get 99% tokenIn since both are stablecoins
        uint256 amountMin = amountIn * 9_900 / BPS_BASE;

        // Encode data
        address[] memory path = new address[](2);
        path[0] = address(tokenIn);
        path[1] = address(tokenOut);
        bytes memory data = abi.encodeWithSelector(
            uniswapRouter02.swapExactTokensForTokens.selector,
            0, // amountIn -> will be replaced with balance
            amountMin, // amountOutMin
            path, // path
            address(router), // to
            block.timestamp // deadline
        );

        // Encode inputs
        IRouter.Input[] memory inputs = new IRouter.Input[](1);
        inputs[0].token = address(tokenIn);
        inputs[0].amountBps = amountBps;
        inputs[0].amountOffset = 0;
        inputs[0].doApprove = true;

        // Encode outputs
        IRouter.Output[] memory outputs = new IRouter.Output[](1);
        outputs[0].token = address(tokenOut);
        outputs[0].amountMin = amountMin;

        return IRouter.Logic(
            address(uniswapRouter02), // to
            data,
            inputs,
            outputs,
            address(0) // callback
        );
    }

    function _logicUniswapV2AddLiquidity(IERC20 tokenIn0, uint256 amountIn0, IERC20 tokenIn1, IERC20 tokenOut)
        public
        view
        returns (IRouter.Logic memory)
    {
        // At least adds 98% token0 to liquidity
        uint256 amountIn0Min = amountIn0 * 9_800 / BPS_BASE;

        // Encode data
        bytes memory data = abi.encodeWithSelector(
            uniswapRouter02.addLiquidity.selector,
            tokenIn0, // tokenA
            tokenIn1, // tokenB,
            0, // amountADesired -> will be replaced with balance
            0, // amountBDesired -> will be replaced with balance
            amountIn0Min, //  amountAMin
            1, // amountBMin
            address(router), // to
            block.timestamp // deadline
        );

        // Encode inputs
        IRouter.Input[] memory inputs = new IRouter.Input[](2);
        inputs[0].token = address(tokenIn0);
        inputs[1].token = address(tokenIn1);
        inputs[0].amountBps = BPS_BASE;
        inputs[1].amountBps = BPS_BASE;
        inputs[0].amountOffset = 0x40;
        inputs[1].amountOffset = 0x60;
        inputs[0].doApprove = true;
        inputs[1].doApprove = true;

        // Encode outputs
        IRouter.Output[] memory outputs = new IRouter.Output[](1);
        outputs[0].token = address(tokenOut);
        outputs[0].amountMin = 1; // FIXME: should calculate the expected min amount

        return IRouter.Logic(
            address(uniswapRouter02), // to
            data,
            inputs,
            outputs,
            address(0) // callback
        );
    }

    function _logicUniswapV2RemoveLiquidity(IERC20 tokenIn, IERC20 tokenOut0, uint256 amountOut0, IERC20 tokenOut1)
        public
        view
        returns (IRouter.Logic memory)
    {
        // At least returns 98% token0 from liquidity
        uint256 amountOut0Min = amountOut0 * 9_800 / BPS_BASE;

        // Encode data
        bytes memory data = abi.encodeWithSelector(
            uniswapRouter02.removeLiquidity.selector,
            tokenOut0, // tokenA
            tokenOut1, // tokenB,
            0, // liquidity -> will be replaced with balance
            amountOut0Min, //  amountAMin
            1, //  amountBMin
            address(router), // to
            block.timestamp // deadline
        );

        // Encode inputs
        IRouter.Input[] memory inputs = new IRouter.Input[](1);
        inputs[0].token = address(tokenIn);
        inputs[0].amountBps = BPS_BASE;
        inputs[0].amountOffset = 0x40;
        inputs[0].doApprove = true;

        // Encode outputs
        IRouter.Output[] memory outputs = new IRouter.Output[](2);
        outputs[0].token = address(tokenOut0);
        outputs[1].token = address(tokenOut1);
        outputs[0].amountMin = amountOut0Min;
        outputs[0].amountMin = 1; // FIXME: should calculate the expected min amount

        return IRouter.Logic(
            address(uniswapRouter02), // to
            data,
            inputs,
            outputs,
            address(0) // callback
        );
    }
}
