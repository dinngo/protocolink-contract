// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {console2} from 'forge-std/console2.sol';
import {Agent} from 'src/Agent.sol';
import {AgentHandler} from './handlers/AgentHandler.sol';
import {MockFallback} from '../mocks/MockFallback.sol';
import {MockCallback} from '../mocks/MockCallback.sol';
import {IMockAgent, MockAgentImplementation} from '../mocks/MockAgentImplementation.sol';

contract AgentImplementationInvariants is Test {
    address public router;
    address public agentImp;
    address public mockCallback;
    address public mockFallback;

    IMockAgent public agent;
    AgentHandler public agentHandler;

    function setUp() external {
        router = makeAddr('Router');

        vm.prank(router);
        agentImp = address(new MockAgentImplementation(makeAddr('WrappedNative')));
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

    function invariant_callerIsAlwaysRouter() external {
        assertEq(agent.caller(), router);
    }

    function invariant_callSummary() external view {
        uint256 numExecuteWithCallback = agentHandler.numCalls('executeWithCallback');
        uint256 numExecuteWithoutCallback = agentHandler.numCalls('executeWithoutCallback');

        console2.log('\nCall Summary\n');
        console2.log('executeWithCallback       ', numExecuteWithCallback);
        console2.log('executeWithoutCallback    ', numExecuteWithoutCallback);
        console2.log('------------------');
        console2.log('Sum', numExecuteWithCallback + numExecuteWithoutCallback);
    }
}
