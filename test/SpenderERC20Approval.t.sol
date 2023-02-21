// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {SafeERC20, IERC20} from 'openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol';
import {ERC20} from 'openzeppelin-contracts/contracts/token/ERC20/ERC20.sol';
import {IAgent} from '../src/interfaces/IAgent.sol';
import {IParam} from '../src/interfaces/IParam.sol';
import {SpenderERC20Approval, ISpenderERC20Approval} from '../src/SpenderERC20Approval.sol';

contract SpenderERC20ApprovalTest is Test {
    using SafeERC20 for IERC20;

    address public user;
    address public router;
    address public agent;
    ISpenderERC20Approval public spender;
    IERC20 public mockERC20;

    IParam.Input[] inputsEmpty;
    IParam.Output[] outputsEmpty;

    function setUp() external {
        user = makeAddr('User');
        // Setup router and agent mock
        router = makeAddr('Router');
        vm.etch(router, 'code');
        agent = makeAddr('Agent');
        vm.etch(agent, 'code');

        spender = new SpenderERC20Approval(router);
        mockERC20 = new ERC20('Mock ERC20', 'mERC20');

        // User approved spender
        vm.startPrank(user);
        mockERC20.safeApprove(address(spender), type(uint256).max);
        vm.stopPrank();

        // Return activated agent from router
        vm.mockCall(router, 0, abi.encodeWithSignature('user()'), abi.encode(user));
        vm.mockCall(router, 0, abi.encodeWithSignature('getAgent()'), abi.encode(agent));
        vm.label(address(spender), 'SpenderERC20Approval');
        vm.label(address(mockERC20), 'mERC20');
    }

    function testPullToken(uint256 amountIn) external {
        IERC20 tokenIn = mockERC20;
        amountIn = bound(amountIn, 1e1, 1e12);
        deal(address(tokenIn), user, amountIn);
        vm.prank(agent);
        spender.pullToken(address(tokenIn), amountIn);

        assertEq(tokenIn.balanceOf(address(spender)), 0);
        assertEq(tokenIn.balanceOf(address(router)), 0);
        assertEq(tokenIn.balanceOf(address(agent)), amountIn);
    }

    // Cannot call spender directly
    function testCannotBeCalledByNonRouter(uint128 amount) external {
        vm.assume(amount > 0);
        deal(address(mockERC20), user, amount);

        vm.startPrank(user);
        vm.expectRevert(ISpenderERC20Approval.InvalidAgent.selector);
        spender.pullToken(address(mockERC20), amount);

        vm.expectRevert(ISpenderERC20Approval.InvalidAgent.selector);
        address[] memory tokens = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        tokens[0] = address(mockERC20);
        amounts[0] = amount;
        spender.pullTokens(tokens, amounts);
        vm.stopPrank();
    }
}
