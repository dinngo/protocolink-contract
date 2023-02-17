// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {Router, IRouter} from '../../src/Router.sol';
import {MockFallback} from '../mocks/MockFallback.sol';

contract GasRouterExecuteTest is Test {
    address public user;
    IRouter public router;
    address public mockFallback;

    // Empty arrays
    address[] tokensReturnEmpty;
    IRouter.Input[] inputsEmpty;
    IRouter.Output[] outputsEmpty;

    function setUp() external {
        user = makeAddr('User');

        router = new Router();
        mockFallback = address(new MockFallback());

        vm.label(address(router), 'Router');
        vm.label(address(mockFallback), 'mFallback');
    }

    function testGas() external {
        IRouter.Logic[] memory logics = new IRouter.Logic[](1);
        logics[0] = IRouter.Logic(
            address(mockFallback),
            '',
            inputsEmpty,
            outputsEmpty,
            address(0), // approveTo
            address(0) // callback
        );
        vm.prank(user);
        router.execute(logics, tokensReturnEmpty);
    }
}
