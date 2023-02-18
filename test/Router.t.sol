// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {ERC20} from 'openzeppelin-contracts/contracts/token/ERC20/ERC20.sol';
import {SafeERC20, IERC20} from 'openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol';
import {Agent, IAgent} from '../src/Agent.sol';
import {Router, IRouter} from '../src/Router.sol';
import {IParam} from '../src/interfaces/IParam.sol';
import {ICallback, MockCallback} from './mocks/MockCallback.sol';
import {MockFallback} from './mocks/MockFallback.sol';

contract RouterTest is Test {
    using SafeERC20 for IERC20;

    uint256 public constant BPS_BASE = 10_000;
    uint256 public constant SKIP = type(uint256).max;

    address public user;
    IRouter public router;
    IERC20 public mockERC20;
    address public mockTo;

    // Empty arrays
    address[] tokensReturnEmpty;
    IParam.Input[] inputsEmpty;
    IParam.Output[] outputsEmpty;

    event Approval(address indexed owner, address indexed spender, uint256 value);

    function setUp() external {
        user = makeAddr('User');

        router = new Router();
        mockERC20 = new ERC20('mockERC20', 'mock');
        mockTo = address(new MockFallback());

        // Mock `Logic.to`
        vm.mockCall(mockTo, 0, abi.encodeWithSignature('dummy()'), new bytes(0));
        vm.label(address(mockERC20), 'mERC20');
    }

    function testNewAgent() external {
        vm.prank(user);
        router.newAgent();
        assertFalse(router.getAgent(user) == address(0));
    }

    function testCannotNewAgentAgain() external {
        vm.startPrank(user);
        router.newAgent();
        vm.expectRevert();
        router.newAgent();
        vm.stopPrank();
    }

    function testNewUserExecute() external {
        IParam.Logic[] memory logics = new IParam.Logic[](1);
        logics[0] = IParam.Logic(
            address(mockTo), // to
            abi.encodeWithSignature('dummy()'),
            inputsEmpty,
            outputsEmpty,
            address(0), // approveTo
            address(0) // callback
        );
        assertEq(router.getAgent(user), address(0));
        vm.prank(user);
        router.execute(logics, tokensReturnEmpty);
        assertFalse(router.getAgent(user) == address(0));
    }

    function testOldUserExecute() external {
        IParam.Logic[] memory logics = new IParam.Logic[](1);
        logics[0] = IParam.Logic(
            address(mockTo), // to
            abi.encodeWithSignature('dummy()'),
            inputsEmpty,
            outputsEmpty,
            address(0), // approveTo
            address(0) // callback
        );
        vm.startPrank(user);
        router.newAgent();
        assertFalse(router.getAgent(user) == address(0));
        router.execute(logics, tokensReturnEmpty);
        vm.stopPrank();
    }

    function testCannotExecuteReentrance() external {
        IParam.Logic[] memory callback = new IParam.Logic[](1);
        callback[0] = IParam.Logic(
            address(mockTo), // to
            abi.encodeWithSignature('dummy()'),
            inputsEmpty,
            outputsEmpty,
            address(0), // approveTo
            address(0) // callback
        );
        IParam.Logic[] memory logics = new IParam.Logic[](1);
        logics[0] = IParam.Logic(
            address(router), // to
            abi.encodeCall(IRouter.execute, (callback, tokensReturnEmpty)),
            inputsEmpty,
            outputsEmpty,
            address(0), // approveTo
            address(0) // callback
        );
        vm.startPrank(user);
        router.newAgent();
        vm.expectRevert();
        router.execute(logics, tokensReturnEmpty);
        vm.stopPrank();
    }

    function testGetAgentWithUserExecuting() external {
        vm.prank(user);
        router.newAgent();
        address agent = router.getAgent(user);
        IParam.Logic[] memory logics = new IParam.Logic[](1);
        logics[0] = IParam.Logic(
            address(this), // to
            abi.encodeCall(this.checkExecutingAgent, (agent)),
            inputsEmpty,
            outputsEmpty,
            address(0), // approveTo
            address(0) // callback
        );
        vm.prank(user);
        router.execute(logics, tokensReturnEmpty);
        agent = router.getAgent();
        // The executing agent should be reset to 0
        assertEq(agent, address(0));
    }

    function checkExecutingAgent(address agent) external view {
        address executingAgent = router.getAgent();
        if (agent != executingAgent) revert();
    }
}
