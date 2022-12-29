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

contract SpenderTest is Test {
    using SafeERC20 for IERC20;

    IERC20 public constant TOKEN = IERC20(0xdAC17F958D2ee523a2206206994597C13D831ec7); // USDT

    address public user;
    address public hacker;
    IRouter public router;
    ISpender public spender;

    function setUp() external {
        user = makeAddr("user");
        hacker = makeAddr("hacker");

        router = new Router();
        spender = new Spender(address(router));

        // User approved spender
        vm.startPrank(user);
        TOKEN.safeApprove(address(spender), type(uint256).max);
        vm.stopPrank();
    }

    // Ensure hacker cannot exploit spender
    function testCannotExploit(uint128 amount) external {
        vm.assume(amount > 0);
        IERC20 tokenIn = TOKEN;
        deal(address(tokenIn), user, amount);

        vm.startPrank(hacker);
        vm.expectRevert(bytes("INVALID_USER"));
        spender.pull(address(tokenIn), amount);
        vm.stopPrank();
    }
}
