// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "../src/Router.sol";
import "../src/Spender.sol";

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
    address public hacker;
    Router public router;
    Spender public spender;

    function setUp() external {
        user = makeAddr("user");
        hacker = makeAddr("hacker");

        router = new Router();
        spender = Spender(router.spender());

        // User approved spender
        vm.startPrank(user);
        USDT.safeApprove(address(router.spender()), type(uint256).max);
        USDC.safeApprove(address(router.spender()), type(uint256).max);
        vm.stopPrank();
    }

    // Test `to` is not ERC20-compliant.
    function testExecuteUniswapV2Swap(uint256 amountIn) external {
        IERC20 tokenIn = USDT;
        IERC20 tokenOut = USDC;
        amountIn = bound(amountIn, 2, tokenIn.totalSupply());
        deal(address(tokenIn), user, amountIn);

        // Prepare logic
        address[] memory path = new address[](2);
        path[0] = address(tokenIn);
        path[1] = address(tokenOut);
        bytes memory dataUniswap = abi.encodeWithSelector(
            uniswapRouter02.swapExactTokensForTokens.selector,
            0, // amountIn -> will be replaced with balance
            1, // amountOutMin
            path, // path
            address(router), // to
            block.timestamp // deadline
        );

        address[] memory tokensIn = new address[](1);
        uint256[] memory amountsInOffset = new uint256[](1);
        tokensIn[0] = address(tokenIn);
        amountsInOffset[0] = 0;
        IRouter.Logic memory logicUniswap = IRouter.Logic(
            address(uniswapRouter02), // to
            tokensIn,
            amountsInOffset,
            dataUniswap
        );

        // Prepare logics
        IRouter.Logic[] memory logics = new IRouter.Logic[](1);
        logics[0] = logicUniswap;

        // Execute
        uint256[] memory amountsIn = new uint256[](1);
        address[] memory tokensOut = new address[](1);
        uint256[] memory amountsOutMin = new uint256[](1);
        amountsIn[0] = amountIn;
        tokensOut[0] = address(tokenOut);
        amountsOutMin[0] = 1;
        vm.prank(user);
        router.execute(amountsIn, tokensOut, amountsOutMin, logics);

        assertGt(tokenOut.balanceOf(address(user)), 0);
    }

    // Test `to` is ERC20-compliant token.
    function testExecuteYearn(uint128 amountIn) external {
        vm.assume(amountIn > 1);
        IERC20 tokenIn = USDT;
        deal(address(tokenIn), user, amountIn);

        // Prepare logic
        address[] memory tokensIn = new address[](1);
        uint256[] memory amountsInOffset = new uint256[](1);
        tokensIn[0] = address(tokenIn);
        amountsInOffset[0] = 0;
        IRouter.Logic memory logicYearn = IRouter.Logic(
            address(yVault), // to
            tokensIn,
            amountsInOffset,
            abi.encodeWithSelector(yVault.deposit.selector, 0) // amount will be replaced with balance
        );

        // Prepare logics
        IRouter.Logic[] memory logics = new IRouter.Logic[](1);
        logics[0] = logicYearn;

        // Yearn deposit
        uint256[] memory amountsIn = new uint256[](1);
        address[] memory tokensOut = new address[](1);
        uint256[] memory amountsOutMin = new uint256[](1);
        amountsIn[0] = amountIn;
        tokensOut[0] = address(yVault);
        amountsOutMin[0] = 1;
        vm.prank(user);
        router.execute(amountsIn, tokensOut, amountsOutMin, logics);

        assertGt(yVault.balanceOf(address(user)), 0);
    }

    // Test multiple tokensIn
    function testExecuteUniswapV2AddLiquidity(uint256 amount0, uint256 amount1) external {
        IERC20 tokenIn0 = USDT;
        IERC20 tokenIn1 = USDC;
        address tokenOut = IUniswapV2Factory(uniswapRouter02.factory()).getPair(address(tokenIn0), address(tokenIn1));
        amount0 = bound(amount0, 1e6, tokenIn0.balanceOf(tokenOut));
        amount1 = bound(amount1, 1e6, tokenIn1.balanceOf(tokenOut));
        deal(address(tokenIn0), user, amount0);
        deal(address(tokenIn1), user, amount1);

        // Prepare logic
        bytes memory dataUniswap = abi.encodeWithSelector(
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

        address[] memory tokensIn = new address[](2);
        uint256[] memory amountsInOffset = new uint256[](2);
        tokensIn[0] = address(tokenIn0);
        tokensIn[1] = address(tokenIn1);
        amountsInOffset[0] = 0x40;
        amountsInOffset[1] = 0x60;
        IRouter.Logic memory logicUniswap = IRouter.Logic(
            address(uniswapRouter02), // to
            tokensIn,
            amountsInOffset,
            dataUniswap
        );

        // Prepare logics
        IRouter.Logic[] memory logics = new IRouter.Logic[](1);
        logics[0] = logicUniswap;

        // Execute
        uint256[] memory amountsIn = new uint256[](2);
        address[] memory tokensOut = new address[](1);
        uint256[] memory amountsOutMin = new uint256[](1);
        amountsIn[0] = amount0;
        amountsIn[1] = amount1;
        tokensOut[0] = address(tokenOut);
        amountsOutMin[0] = 1;
        vm.prank(user);
        router.execute(amountsIn, tokensOut, amountsOutMin, logics);

        assertGt(IERC20(tokenOut).balanceOf(address(user)), 0);
    }
}
