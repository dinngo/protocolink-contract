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

interface IUniswapV2Router02 {
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);
}

contract RouterTest is Test {
    using SafeERC20 for IERC20;

    IERC20 public constant TOKEN = IERC20(0xdAC17F958D2ee523a2206206994597C13D831ec7); // USDT
    IERC20 public constant WETH = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2); // WETH
    IUniswapV2Router02 public constant uniswapRouter02 = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
    IYVault public constant yVault = IYVault(0x2f08119C6f07c006695E079AAFc638b8789FAf18); // yUSDT

    address public user;
    address public hacker;
    address public hackerWallet;
    Router public router;
    Spender public spender;

    function setUp() external {
        user = makeAddr("user");
        hacker = makeAddr("hacker");
        hackerWallet = makeAddr("hackerWallet");

        router = new Router();
        spender = Spender(router.spender());

        // User approved spender
        vm.startPrank(user);
        TOKEN.safeApprove(address(router.spender()), type(uint256).max);
        vm.stopPrank();
    }

    // Test `to` is not ERC20-compliant.
    function testExecuteUniswapV2(uint256 amount) external {
        IERC20 tokenIn = TOKEN;
        IERC20 tokenOut = WETH;
        amount = bound(amount, 1, tokenIn.totalSupply());
        deal(address(tokenIn), user, amount);

        // Prepare logic
        address[] memory path = new address[](2);
        path[0] = address(tokenIn);
        path[1] = address(tokenOut);
        bytes memory dataUniswap = abi.encodeWithSelector(
            uniswapRouter02.swapExactTokensForTokens.selector,
            0, // amountIn -> will be replaced with balanceOf(token)
            1, // amountOutMin
            path, // path
            address(router), // to
            block.timestamp // deadline
        );

        IRouter.Logic memory logicUniswap = IRouter.Logic(
            address(uniswapRouter02), // to
            address(tokenIn), // token
            0, // amountOffset
            dataUniswap
        );

        // Prepare logics
        IRouter.Logic[] memory logics = new IRouter.Logic[](1);
        logics[0] = logicUniswap;

        // Execute
        vm.prank(user);
        router.execute(
            address(tokenIn), // tokenIn
            amount, // amountIn
            address(tokenOut), // tokenOut
            1, // amountOutMin
            logics
        );
        assertGt(tokenOut.balanceOf(address(user)), 0);
    }

    // Test `to` is ERC20-compliant token.
    function testExecuteYearn(uint128 amount) external {
        vm.assume(amount > 1e6);
        IERC20 tokenIn = TOKEN;
        deal(address(tokenIn), user, amount);

        // Prepare logic
        IRouter.Logic memory logicYearn = IRouter.Logic(
            address(yVault), // to
            address(tokenIn), // token
            1, // amountOffset
            abi.encodeWithSelector(yVault.deposit.selector, 0) // amount will be replaced with balanceOf(token)
        );

        // Prepare logics
        IRouter.Logic[] memory logics = new IRouter.Logic[](1);
        logics[0] = logicYearn;

        // Yearn deposit
        vm.prank(user);
        router.execute(
            address(tokenIn), // tokenIn
            amount, // amountIn
            address(yVault), // tokenOut
            1, // amountOutMin
            logics
        );

        assertGt(yVault.balanceOf(address(user)), 0);
    }
}
