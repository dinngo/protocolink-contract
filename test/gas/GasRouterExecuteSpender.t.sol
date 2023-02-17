// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {Router, IRouter} from '../../src/Router.sol';
import {MockSpender} from '../mocks/MockSpender.sol';

contract GasRouterExecuteSpenderTest is Test {
    address public user;
    IRouter public router;
    address public mockSpender;

    // Empty arrays
    address[] tokensReturnEmpty;
    IRouter.Input[] inputsEmpty;
    IRouter.Output[] outputsEmpty;

    function setUp() external {
        user = makeAddr('User');

        router = new Router();
        mockSpender = address(new MockSpender(address(router)));

        vm.label(address(router), 'Router');
        vm.label(address(mockSpender), 'mSpender');
    }

    function testGas() external {
        IRouter.Logic[] memory logics = new IRouter.Logic[](1);
        logics[0] = IRouter.Logic(
            address(mockSpender),
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
