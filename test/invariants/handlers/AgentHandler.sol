// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {IAgent} from 'src/interfaces/IAgent.sol';
import {IParam} from 'src/interfaces/IParam.sol';
import {IMockAgent} from '../../mocks/MockAgentImplementation.sol';
import {ICallback} from '../../mocks/MockCallback.sol';

contract AgentHandler is Test {
    address public immutable router;
    address public immutable agent;
    address public immutable mCallback;
    address public immutable mFallback;

    // Empty arrays
    IParam.Logic[] logicsEmpty;
    IParam.Fee[] feesEmpty;
    IParam.Input[] inputsEmpty;
    address[] tokensReturnEmpty;

    mapping(bytes32 => uint256) public numCalls;

    constructor(address router_, address agent_, address mCallback_, address mFallback_) {
        router = router_;
        agent = agent_;
        mCallback = mCallback_;
        mFallback = mFallback_;
    }

    function executeWithoutCallback() external {
        numCalls['executeWithoutCallback']++;
        vm.prank(router);
        IMockAgent(agent).execute(logicsEmpty, tokensReturnEmpty);
    }

    function executeWithCallback() external {
        numCalls['executeWithCallback']++;
        // Prep
        IParam.Logic[] memory callbacks = new IParam.Logic[](1);
        callbacks[0] = IParam.Logic(
            mFallback, // to
            '',
            inputsEmpty,
            IParam.WrapMode.NONE,
            address(0), // approveTo
            address(0) // callback
        );
        bytes memory data = abi.encodeWithSelector(
            IAgent.executeByCallback.selector,
            callbacks,
            feesEmpty,
            tokensReturnEmpty
        );
        IParam.Logic[] memory logics = new IParam.Logic[](1);
        logics[0] = IParam.Logic(
            mCallback,
            abi.encodeWithSelector(ICallback.callback.selector, data),
            inputsEmpty,
            IParam.WrapMode.NONE,
            address(0), // approveTo
            mCallback // callback
        );

        // Execute
        vm.prank(router);
        IMockAgent(agent).execute(logics, tokensReturnEmpty);
    }
}
