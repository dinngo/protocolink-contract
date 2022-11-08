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

    Router public router;
    Spender public spender;
    address public user;
    address public hacker;
    address public hackerWallet;

    function setUp() external {
        user = makeAddr("user");
        hacker = makeAddr("hacker");
        hackerWallet = makeAddr("hackerWallet");

        router = new Router();
        spender = Spender(router.spender());

        // User approved router
        vm.startPrank(user);
        TOKEN.safeApprove(address(router.spender()), type(uint256).max);
        vm.stopPrank();
    }

    // Ensure to allow interacting with `to` which is not ERC20-compliant.
    function testExecuteUniswapV2(uint256 amount) external {
        IERC20 tokenIn = TOKEN;
        IERC20 tokenOut = WETH;
        amount = bound(amount, 1, tokenIn.totalSupply());
        deal(address(tokenIn), user, amount);

        // Prepare calldata
        address[] memory path = new address[](2);
        path[0] = address(tokenIn);
        path[1] = address(tokenOut);
        bytes memory dataUniswap = abi.encodeWithSelector(
            uniswapRouter02.swapExactTokensForTokens.selector,
            amount, // amountIn
            1, // amountOutMin
            path, // path
            address(router), // to
            block.timestamp // deadline
        );

        // Set uniswapRouter02 to `to`
        vm.prank(user);
        router.execute(
            address(tokenIn), // tokenIn
            amount, // amountIn
            address(tokenOut), // tokenOut
            address(uniswapRouter02), // to
            dataUniswap
        );
        assertGt(tokenOut.balanceOf(address(user)), 0);
    }

    // Ensure to allow interacting with `to` which is ERC20-compliant token.
    function testExecuteYearn(uint128 amount) external {
        vm.assume(amount > 1);
        IERC20 tokenIn = TOKEN;
        deal(address(tokenIn), user, amount);

        // Yearn deposit
        vm.prank(user);
        router.execute(
            address(tokenIn), // tokenIn
            amount, // amountIn
            address(yVault), // tokenOut
            address(yVault), // to
            abi.encodeWithSelector(yVault.deposit.selector, amount)
        );
        assertGt(yVault.balanceOf(address(user)), 0);
    }

    // Ensure hacker cannot exploit spender
    function testCannotExploit(uint128 amount) external {
        vm.assume(amount > 0);
        IERC20 tokenIn = TOKEN;
        deal(address(tokenIn), user, amount);

        vm.startPrank(hacker);
        vm.expectRevert(bytes("!ROUTER"));
        spender.transferFromERC20(user, address(tokenIn), amount);
        vm.stopPrank();
    }
}
