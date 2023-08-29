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
    bytes[] permit2DatasEmpty;
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

    function execute() external {
        numCalls['execute']++;
        vm.prank(router);
        IMockAgent(agent).execute(permit2DatasEmpty, _logicsWithCallback(), tokensReturnEmpty);
    }

    function executeWithoutCallback() external {
        numCalls['executeWithoutCallback']++;
        vm.prank(router);
        IMockAgent(agent).execute(permit2DatasEmpty, logicsEmpty, tokensReturnEmpty);
    }

    function executeWithSignerFee() external {
        numCalls['executeWithSignerFee']++;
        vm.prank(router);
        IMockAgent(agent).executeWithSignerFee(permit2DatasEmpty, _logicsWithCallback(), feesEmpty, tokensReturnEmpty);
    }

    function executeByCallback() external {
        numCalls['executeByCallback']++;
        vm.prank(address(bytes20(IMockAgent(agent).INIT_CALLBACK_WITH_CHARGE())));
        IMockAgent(agent).executeByCallback(_logicsWithCallback());
    }

    function _logicsWithCallback() internal view returns (IParam.Logic[] memory) {
        IParam.Logic[] memory callbacks = new IParam.Logic[](1);
        callbacks[0] = IParam.Logic(
            mFallback, // to
            new bytes(0),
            inputsEmpty,
            IParam.WrapMode.NONE,
            address(0), // approveTo
            address(0) // callback
        );
        bytes memory data = abi.encodeWithSelector(IAgent.executeByCallback.selector, callbacks);
        IParam.Logic[] memory logics = new IParam.Logic[](1);
        logics[0] = IParam.Logic(
            mCallback,
            abi.encodeWithSelector(ICallback.callback.selector, data),
            inputsEmpty,
            IParam.WrapMode.NONE,
            address(0), // approveTo
            mCallback // callback
        );

        return logics;
    }
}
