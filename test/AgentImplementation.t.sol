// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {ERC20} from 'openzeppelin-contracts/contracts/token/ERC20/ERC20.sol';
import {SafeERC20, IERC20} from 'openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol';
import {AgentImplementation, IAgent} from '../src/AgentImplementation.sol';
import {Router, IRouter} from '../src/Router.sol';
import {IParam} from '../src/interfaces/IParam.sol';
import {ICallback, MockCallback} from './mocks/MockCallback.sol';
import {MockFallback} from './mocks/MockFallback.sol';

contract AgentImplementationTest is Test {
    using SafeERC20 for IERC20;

    uint256 public constant BPS_BASE = 10_000;
    uint256 public constant SKIP = type(uint256).max;

    address public user;
    address public router;
    IAgent public agent;
    IERC20 public mockERC20;
    ICallback public mockCallback;
    address public mockFallback;

    // Empty arrays
    address[] tokensReturnEmpty;
    IParam.Input[] inputsEmpty;

    event Approval(address indexed owner, address indexed spender, uint256 value);

    function setUp() external {
        user = makeAddr('User');
        router = makeAddr('Router');

        vm.prank(router);
        agent = new AgentImplementation();
        agent.initialize();
        mockERC20 = new ERC20('mockERC20', 'mock');
        mockCallback = new MockCallback();
        mockFallback = address(new MockFallback());

        vm.mockCall(router, 0, abi.encodeWithSignature('user()'), abi.encode(user));
        vm.label(address(agent), 'Agent');
        vm.label(address(mockERC20), 'mERC20');
        vm.label(address(mockCallback), 'mCallback');
        vm.label(address(mockFallback), 'mFallback');
    }

    function testCannotExecuteByInvalidCallback() external {
        IParam.Logic[] memory callbacks = new IParam.Logic[](1);
        callbacks[0] = IParam.Logic(
            address(mockFallback), // to
            '',
            inputsEmpty,
            address(0) // callback
        );
        bytes memory data = abi.encodeWithSelector(IRouter.execute.selector, callbacks, tokensReturnEmpty);
        IParam.Logic[] memory logics = new IParam.Logic[](1);
        logics[0] = IParam.Logic(
            address(mockCallback),
            abi.encodeWithSelector(ICallback.callback.selector, data),
            inputsEmpty,
            address(router) // callback
        );
        vm.expectRevert(IAgent.InvalidCallback.selector);
        vm.prank(router);
        agent.execute(logics, tokensReturnEmpty);
    }

    function testCannotBeInvalidBps() external {
        IParam.Logic[] memory logics = new IParam.Logic[](1);
        IParam.Input[] memory inputs = new IParam.Input[](1);

        // Revert if amountBps = 0
        inputs[0] = IParam.Input(
            address(0),
            0, // amountBps
            0 // amountOrOffset
        );
        logics[0] = IParam.Logic(
            address(0), // to
            '',
            inputs,
            address(0) // callback
        );
        vm.expectRevert(IAgent.InvalidBps.selector);
        vm.prank(router);
        agent.execute(logics, tokensReturnEmpty);

        // Revert if amountBps = BPS_BASE + 1
        inputs[0] = IParam.Input(
            address(0),
            BPS_BASE + 1, // amountBps
            0 // amountOrOffset
        );
        logics[0] = IParam.Logic(
            address(0), // to
            '',
            inputs,
            address(0) // callback
        );
        vm.expectRevert(IAgent.InvalidBps.selector);
        vm.prank(router);
        agent.execute(logics, tokensReturnEmpty);
    }

    function testCannotUnresetCallback() external {
        IParam.Logic[] memory logics = new IParam.Logic[](1);
        logics[0] = IParam.Logic(
            address(mockFallback), // to
            '',
            inputsEmpty,
            address(mockCallback) // callback
        );
        vm.expectRevert(IAgent.UnresetCallback.selector);
        vm.prank(router);
        agent.execute(logics, tokensReturnEmpty);
    }
}
