// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {console2} from 'forge-std/console2.sol';
import {Agent} from 'src/Agent.sol';
import {AgentHandler} from './handlers/AgentHandler.sol';
import {MockFallback} from '../mocks/MockFallback.sol';
import {MockCallback} from '../mocks/MockCallback.sol';
import {IMockAgent, MockAgentImplementation} from '../mocks/MockAgentImplementation.sol';

contract AgentInvariants is Test {
    address public router;
    address public agentImp;
    address public mockCallback;
    address public mockFallback;

    IMockAgent public agent;
    AgentHandler public agentHandler;

    function setUp() external {
        router = makeAddr('Router');

        vm.prank(router);
        agentImp = address(new MockAgentImplementation(makeAddr('WrappedNative'), makeAddr('Permit2')));
        agent = IMockAgent(address(new Agent(agentImp)));
        mockCallback = address(new MockCallback());
        mockFallback = address(new MockFallback());
        agentHandler = new AgentHandler(router, address(agent), mockCallback, mockFallback);

        vm.label(address(agent), 'Agent');
        vm.label(address(agentHandler), 'Agent Handler');
        vm.label(mockCallback, 'mCallback');
        vm.label(mockFallback, 'mFallback');

        targetContract(address(agentHandler));
    }

    function invariant_initializedCallbackWithCharge() external {
        assertEq(agent.callbackWithCharge(), agent.INIT_CALLBACK_WITH_CHARGE());
    }

    function invariant_callSummary() external view {
        uint256 numExecute = agentHandler.numCalls('execute');
        uint256 numExecuteWithoutCallback = agentHandler.numCalls('executeWithoutCallback');
        uint256 numExecuteWithSignerFee = agentHandler.numCalls('executeWithSignerFee');
        uint256 numExecuteByCallback = agentHandler.numCalls('executeByCallback');

        console2.log('\nCall Summary\n');
        console2.log('execute', numExecute);
        console2.log('executeWithoutCallback', numExecuteWithoutCallback);
        console2.log('executeWithSignerFee', numExecuteWithSignerFee);
        console2.log('executeByCallback', numExecuteByCallback);
        console2.log('------------------');
        console2.log('Sum', numExecute + numExecuteWithoutCallback + numExecuteWithSignerFee + numExecuteByCallback);
    }
}
