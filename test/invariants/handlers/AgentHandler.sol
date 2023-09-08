// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {IAgent} from 'src/interfaces/IAgent.sol';
import {DataType} from 'src/libraries/DataType.sol';
import {IMockAgent} from '../../mocks/MockAgentImplementation.sol';
import {ICallback} from '../../mocks/MockCallback.sol';

contract AgentHandler is Test {
    address public immutable router;
    address public immutable agent;
    address public immutable mCallback;
    address public immutable mFallback;

    // Empty arrays
    bytes[] permit2DatasEmpty;
    DataType.Logic[] logicsEmpty;
    DataType.Fee[] feesEmpty;
    DataType.Input[] inputsEmpty;
    address[] tokensReturnEmpty;
    bytes32[] referralsEmpty;

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
        IMockAgent(agent).executeWithSignerFee(
            permit2DatasEmpty,
            _logicsWithCallback(),
            feesEmpty,
            referralsEmpty,
            tokensReturnEmpty
        );
    }

    function executeByCallback() external {
        numCalls['executeByCallback']++;
        vm.prank(address(bytes20(IMockAgent(agent).INIT_CALLBACK_WITH_CHARGE())));
        IMockAgent(agent).executeByCallback(_logicsWithCallback());
    }

    function _logicsWithCallback() internal view returns (DataType.Logic[] memory) {
        DataType.Logic[] memory callbacks = new DataType.Logic[](1);
        callbacks[0] = DataType.Logic(
            mFallback, // to
            new bytes(0),
            inputsEmpty,
            DataType.WrapMode.NONE,
            address(0), // approveTo
            address(0) // callback
        );
        bytes memory data = abi.encodeWithSelector(IAgent.executeByCallback.selector, callbacks);
        DataType.Logic[] memory logics = new DataType.Logic[](1);
        logics[0] = DataType.Logic(
            mCallback,
            abi.encodeWithSelector(ICallback.callback.selector, data),
            inputsEmpty,
            DataType.WrapMode.NONE,
            address(0), // approveTo
            mCallback // callback
        );

        return logics;
    }
}
