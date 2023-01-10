// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {SafeERC20, IERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {Router, IRouter} from "../src/Router.sol";
import {SpenderERC20Approval, ISpenderERC20Approval} from "../src/SpenderERC20Approval.sol";
import {MockERC20} from "./mocks/MockERC20.sol";

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

contract SpenderERC20ApprovalTest is Test {
    using SafeERC20 for IERC20;

    address public user;
    IRouter public router;
    ISpenderERC20Approval public spender;
    IERC20 public mockERC20;

    function setUp() external {
        user = makeAddr("user");

        router = new Router();
        spender = new SpenderERC20Approval(address(router));
        mockERC20 = new MockERC20("Mock ERC20", "mERC20");

        // User approved spender
        vm.startPrank(user);
        mockERC20.safeApprove(address(spender), type(uint256).max);
        vm.stopPrank();

        vm.label(address(router), "Router");
        vm.label(address(spender), "SpenderERC20Approval");
        vm.label(address(mockERC20), "mERC20");
    }

    // Cannot call spender directly
    function testCannotExploit(uint128 amount) external {
        vm.assume(amount > 0);
        deal(address(mockERC20), user, amount);

        vm.startPrank(user);
        vm.expectRevert(ISpenderERC20Approval.RouterInvalidUser.selector);
        spender.pullToken(address(mockERC20), amount);

        vm.expectRevert(ISpenderERC20Approval.RouterInvalidUser.selector);
        address[] memory tokens = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        tokens[0] = address(mockERC20);
        amounts[0] = amount;
        spender.pullTokens(tokens, amounts);
        vm.stopPrank();
    }
}
