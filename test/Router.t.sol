// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {SafeERC20, IERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {Router, IRouter} from "../src/Router.sol";
import {SpenderERC20Approval, ISpenderERC20Approval} from "../src/SpenderERC20Approval.sol";

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

    address public user;
    IRouter public router;
    ISpenderERC20Approval public spender;

    function setUp() external {
        user = makeAddr("user");

        router = new Router();
        spender = new SpenderERC20Approval(address(router));

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

    // Test Logic.to is ERC20-compliant token.
    function testExecuteYearn(uint128 amountIn) external {
        vm.assume(amountIn > 1);
        IERC20 tokenIn = USDT;
        deal(address(tokenIn), user, amountIn);

        // Encode logics
        IRouter.Logic[] memory logics = new IRouter.Logic[](2);
        logics[0] = _logicSpenderERC20Approval(tokenIn, amountIn);
        logics[1] = _logicYearn(tokenIn);

        // Execute
        address[] memory tokensOut = new address[](1);
        uint256[] memory amountsOutMin = new uint256[](1);
        tokensOut[0] = address(yVault);
        amountsOutMin[0] = 1;
        vm.prank(user);
        router.execute(tokensOut, amountsOutMin, logics);

        assertEq(tokenIn.balanceOf(address(router)), 0);
        assertEq(yVault.balanceOf(address(router)), 0);
        assertGt(yVault.balanceOf(address(user)), 0);
    }

    // Test Logic.to is not ERC20-compliant.
    function testExecuteUniswapV2Swap(uint256 amountIn) external {
        IERC20 tokenIn = USDT;
        IERC20 tokenOut = USDC;
        amountIn = bound(amountIn, 2, tokenIn.totalSupply());
        deal(address(tokenIn), user, amountIn);

        // Encode logics
        IRouter.Logic[] memory logics = new IRouter.Logic[](2);
        logics[0] = _logicSpenderERC20Approval(tokenIn, amountIn);
        logics[1] = _logicUniswapV2Swap(tokenIn, 1e18, tokenOut);

        // Encode execute
        address[] memory tokensOut = new address[](1);
        uint256[] memory amountsOutMin = new uint256[](1);
        tokensOut[0] = address(tokenOut);
        amountsOutMin[0] = 1;
        vm.prank(user);
        router.execute(tokensOut, amountsOutMin, logics);

        assertEq(tokenIn.balanceOf(address(router)), 0);
        assertEq(tokenOut.balanceOf(address(router)), 0);
        assertGt(tokenOut.balanceOf(address(user)), 0);
    }

    // 1. Swap 50% token0 to token1
    // 2. Add liquidity token0/token1
    // 3. Remove liquidity token0/token1
    // 4. Swap token1 to token0
    function testExecuteUniswapV2SwapAddRemoveSwap(uint256 amount0) external {
        IERC20 tokenIn0 = USDT;
        IERC20 tokenIn1 = USDC;
        IERC20 tokenOut =
            IERC20(IUniswapV2Factory(uniswapRouter02.factory()).getPair(address(tokenIn0), address(tokenIn1)));
        amount0 = bound(amount0, 1e6, tokenIn0.balanceOf(address(tokenOut)));
        deal(address(tokenIn0), user, amount0);

        // Encode logics
        IRouter.Logic[] memory logics = new IRouter.Logic[](5);
        logics[0] = _logicSpenderERC20Approval(tokenIn0, amount0);
        logics[1] = _logicUniswapV2Swap(tokenIn0, 0.5 * 1e18, tokenIn1); // 50% balance of tokenIn
        logics[2] = _logicUniswapV2AddLiquidity(tokenIn0, tokenIn1);
        logics[3] = _logicUniswapV2RemoveLiquidity(tokenOut, tokenIn0, tokenIn1);
        logics[4] = _logicUniswapV2Swap(tokenIn1, 1e18, tokenIn0); // 100% balance of tokenIn

        // Encode execute
        uint256[] memory amountsIn = new uint256[](1);
        address[] memory tokensOut = new address[](3);
        uint256[] memory amountsOutMin = new uint256[](3);
        amountsIn[0] = amount0;
        tokensOut[0] = address(tokenIn0);
        tokensOut[1] = address(tokenIn1); // Push intermediate token to ensure clean up Router
        tokensOut[2] = address(tokenOut); // Push intermediate token to ensure clean up Router
        amountsOutMin[0] = amount0 * 99 / 100;
        amountsOutMin[1] = 0;
        amountsOutMin[2] = 0;
        vm.prank(user);
        router.execute(tokensOut, amountsOutMin, logics);

        assertEq(tokenIn0.balanceOf(address(router)), 0);
        assertEq(tokenIn1.balanceOf(address(router)), 0);
        assertEq(tokenOut.balanceOf(address(router)), 0);
        assertApproxEqRel(tokenIn0.balanceOf(address(user)), amount0, 0.01 * 1e18);
    }

    function _logicSpenderERC20Approval(IERC20 tokenIn, uint256 amountIn) public view returns (IRouter.Logic memory) {
        // Encode logic
        IRouter.AmountInConfig[] memory configsEmpty = new IRouter.AmountInConfig[](0);

        return IRouter.Logic(
            address(spender), // to
            configsEmpty,
            abi.encodeWithSelector(spender.pullToken.selector, address(tokenIn), amountIn)
        );
    }

    function _logicYearn(IERC20 tokenIn) public pure returns (IRouter.Logic memory) {
        // Encode logic
        IRouter.AmountInConfig[] memory configs = new IRouter.AmountInConfig[](1);
        configs[0].tokenIn = address(tokenIn);
        configs[0].tokenInBalanceRatio = 1e18;
        configs[0].amountInOffset = 0;

        return IRouter.Logic(
            address(yVault), // to
            configs,
            abi.encodeWithSelector(yVault.deposit.selector, 0) // amount will be replaced with balance
        );
    }

    function _logicUniswapV2Swap(IERC20 tokenIn, uint256 tokenInBalanceRatio, IERC20 tokenOut)
        public
        view
        returns (IRouter.Logic memory)
    {
        // Encode logic
        address[] memory path = new address[](2);
        path[0] = address(tokenIn);
        path[1] = address(tokenOut);
        bytes memory data = abi.encodeWithSelector(
            uniswapRouter02.swapExactTokensForTokens.selector,
            0, // amountIn -> will be replaced with balance
            1, // amountOutMin
            path, // path
            address(router), // to
            block.timestamp // deadline
        );

        IRouter.AmountInConfig[] memory configs = new IRouter.AmountInConfig[](1);
        configs[0].tokenIn = address(tokenIn);
        configs[0].tokenInBalanceRatio = tokenInBalanceRatio;
        configs[0].amountInOffset = 0;

        return IRouter.Logic(
            address(uniswapRouter02), // to
            configs,
            data
        );
    }

    function _logicUniswapV2AddLiquidity(IERC20 tokenIn0, IERC20 tokenIn1) public view returns (IRouter.Logic memory) {
        // Encode logic
        bytes memory data = abi.encodeWithSelector(
            uniswapRouter02.addLiquidity.selector,
            tokenIn0, // tokenA
            tokenIn1, // tokenB,
            0, // amountADesired -> will be replaced with balance
            0, //  amountBDesired -> will be replaced with balance
            1, //  amountAMin
            1, //  amountBMin
            address(router), // to
            block.timestamp // deadline
        );

        IRouter.AmountInConfig[] memory configs = new IRouter.AmountInConfig[](2);
        configs[0].tokenIn = address(tokenIn0);
        configs[1].tokenIn = address(tokenIn1);
        configs[0].tokenInBalanceRatio = 1e18;
        configs[1].tokenInBalanceRatio = 1e18;
        configs[0].amountInOffset = 0x40;
        configs[1].amountInOffset = 0x60;

        return IRouter.Logic(
            address(uniswapRouter02), // to
            configs,
            data
        );
    }

    function _logicUniswapV2RemoveLiquidity(IERC20 tokenIn, IERC20 tokenOut0, IERC20 tokenOut1)
        public
        view
        returns (IRouter.Logic memory)
    {
        // Encode logic
        bytes memory data = abi.encodeWithSelector(
            uniswapRouter02.removeLiquidity.selector,
            tokenOut0, // tokenA
            tokenOut1, // tokenB,
            0, // liquidity -> will be replaced with balance
            1, //  amountAMin
            1, //  amountBMin
            address(router), // to
            block.timestamp // deadline
        );

        IRouter.AmountInConfig[] memory configs = new IRouter.AmountInConfig[](1);
        configs[0].tokenIn = address(tokenIn);
        configs[0].tokenInBalanceRatio = 1e18;
        configs[0].amountInOffset = 0x40;

        return IRouter.Logic(
            address(uniswapRouter02), // to
            configs,
            data
        );
    }
}
