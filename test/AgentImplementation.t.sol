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
    IParam.Output[] outputsEmpty;

    event Approval(address indexed owner, address indexed spender, uint256 value);

    function setUp() external {
        user = makeAddr('User');
        router = makeAddr('Router');

        vm.prank(router);
        agent = new AgentImplementation(user);
        mockERC20 = new ERC20('mockERC20', 'mock');
        mockCallback = new MockCallback();
        mockFallback = address(new MockFallback());

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
            outputsEmpty,
            address(0), // approveTo
            address(0) // callback
        );
        bytes memory data = abi.encodeWithSelector(IRouter.execute.selector, callbacks, tokensReturnEmpty);
        IParam.Logic[] memory logics = new IParam.Logic[](1);
        logics[0] = IParam.Logic(
            address(mockCallback),
            abi.encodeWithSelector(ICallback.callback.selector, data),
            inputsEmpty,
            outputsEmpty,
            address(0), // approveTo
            address(router) // callback
        );
        vm.expectRevert(IAgent.InvalidCallback.selector);
        vm.prank(router);
        agent.execute(logics, tokensReturnEmpty);
    }

    function testCannotEncodeApproveSig() external {
        IParam.Logic[] memory logics = new IParam.Logic[](1);
        logics[0] = IParam.Logic(
            address(mockERC20), // to
            abi.encodeWithSelector(IERC20.approve.selector, user, 0),
            inputsEmpty,
            outputsEmpty,
            address(0), // approveTo
            address(0) // callback
        );

        vm.expectRevert(IAgent.InvalidERC20Sig.selector);
        vm.prank(router);
        agent.execute(logics, tokensReturnEmpty);
    }

    function testCannotEncodeTransferFromSig() external {
        IParam.Logic[] memory logics = new IParam.Logic[](1);
        logics[0] = IParam.Logic(
            address(mockERC20), // to
            abi.encodeWithSelector(IERC20.transferFrom.selector, user, 0),
            inputsEmpty,
            outputsEmpty,
            address(0), // approveTo
            address(0) // callback
        );

        vm.expectRevert(IAgent.InvalidERC20Sig.selector);
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
            outputsEmpty,
            address(0), // approveTo
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
            outputsEmpty,
            address(0), // approveTo
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
            outputsEmpty,
            address(0), // approveTo
            address(mockCallback) // callback
        );
        vm.expectRevert(IAgent.UnresetCallback.selector);
        vm.prank(router);
        agent.execute(logics, tokensReturnEmpty);
    }

    function testCannotReceiveLessOutputToken() external {
        IERC20 tokenOut = mockERC20;
        uint256 amountMin = 1 ether;
        IParam.Logic[] memory logics = new IParam.Logic[](1);
        IParam.Output[] memory outputs = new IParam.Output[](1);

        // Output token already exists in router
        deal(address(tokenOut), address(router), 10 ether);

        outputs[0] = IParam.Output(address(tokenOut), amountMin);

        // Receive 0 output token
        logics[0] = IParam.Logic(
            address(mockFallback), // to
            '',
            inputsEmpty,
            outputs,
            address(0), // approveTo
            address(0) // callback
        );

        // Execute
        address[] memory tokensReturn = new address[](1);
        tokensReturn[0] = address(tokenOut);
        vm.expectRevert(abi.encodeWithSelector(IAgent.InsufficientBalance.selector, address(tokenOut), amountMin, 0));
        vm.prank(router);
        agent.execute(logics, tokensReturn);
    }

    function testApproveToIsDefault(uint256 amountIn) external {
        vm.assume(amountIn > 0);

        IParam.Logic[] memory logics = new IParam.Logic[](1);
        IParam.Input[] memory inputs = new IParam.Input[](1);

        inputs[0] = IParam.Input(
            address(mockERC20),
            SKIP, // amountBps
            amountIn // amountOrOffset
        );
        logics[0] = IParam.Logic(
            address(mockFallback), // to
            '',
            inputs,
            outputsEmpty,
            address(0), // approveTo
            address(0) // callback
        );

        // Execute
        vm.expectEmit(true, true, true, true, address(mockERC20));
        emit Approval(address(agent), address(mockFallback), amountIn);
        vm.expectEmit(true, true, true, true, address(mockERC20));
        emit Approval(address(agent), address(mockFallback), 0);
        vm.prank(router);
        agent.execute(logics, tokensReturnEmpty);
    }

    function testApproveToIsSet(uint256 amountIn, address approveTo) external {
        vm.assume(amountIn > 0);
        vm.assume(approveTo != address(0) && approveTo != mockFallback && approveTo != address(mockERC20));

        IParam.Logic[] memory logics = new IParam.Logic[](1);
        IParam.Input[] memory inputs = new IParam.Input[](1);

        inputs[0] = IParam.Input(
            address(mockERC20),
            SKIP, // amountBps
            amountIn // amountOrOffset
        );
        logics[0] = IParam.Logic(
            address(mockFallback), // to
            '',
            inputs,
            outputsEmpty,
            approveTo, // approveTo
            address(0) // callback
        );

        // Execute
        vm.expectEmit(true, true, true, true, address(mockERC20));
        emit Approval(address(agent), approveTo, amountIn);
        vm.expectEmit(true, true, true, true, address(mockERC20));
        emit Approval(address(agent), approveTo, 0);
        vm.prank(router);
        agent.execute(logics, tokensReturnEmpty);
    }
}
