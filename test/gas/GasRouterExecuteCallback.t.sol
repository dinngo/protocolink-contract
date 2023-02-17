// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {Router, IRouter} from '../../src/Router.sol';
import {ICallback, MockCallback} from '../mocks/MockCallback.sol';
import {MockFallback} from '../mocks/MockFallback.sol';

contract GasRouterExecuteCallbackTest is Test {
    address public user;
    IRouter public router;
    ICallback public mockCallback;
    address public mockFallback;

    // Empty arrays
    address[] tokensReturnEmpty;
    IRouter.Input[] inputsEmpty;
    IRouter.Output[] outputsEmpty;

    function setUp() external {
        user = makeAddr('User');

        router = new Router();
        mockCallback = new MockCallback();
        mockFallback = address(new MockFallback());

        vm.label(address(router), 'Router');
        vm.label(address(mockCallback), 'mCallback');
        vm.label(address(mockFallback), 'mFallback');
    }

    function testGas() external {
        IRouter.Logic[] memory callbacks = new IRouter.Logic[](1);
        callbacks[0] = IRouter.Logic(
            address(mockFallback), // to
            '',
            inputsEmpty,
            outputsEmpty,
            address(0), // approveTo
            address(0) // callback
        );
        bytes memory data = abi.encodeWithSelector(IRouter.execute.selector, callbacks, tokensReturnEmpty);
        IRouter.Logic[] memory logics = new IRouter.Logic[](1);
        logics[0] = IRouter.Logic(
            address(mockCallback),
            abi.encodeWithSelector(ICallback.callback.selector, data),
            inputsEmpty,
            outputsEmpty,
            address(0), // approveTo
            address(mockCallback) // callback
        );
        vm.prank(user);
        router.execute(logics, tokensReturnEmpty);
    }
}
