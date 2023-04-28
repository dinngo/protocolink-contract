// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {Router} from '../../src/Router.sol';
import {RouterHandler} from './handlers/RouterHandler.sol';

contract RouterInvariantsTest is Test {
    address internal constant _INIT_USER = address(1);

    Router public router;
    RouterHandler public handler;

    function setUp() public {
        router = new Router(makeAddr('WrappedNative'), makeAddr('Pauser'), makeAddr('Signer'));
        handler = new RouterHandler(router);

        bytes4[] memory selectors = new bytes4[](4);
        selectors[0] = RouterHandler.execute.selector;
        selectors[1] = RouterHandler.executeWithSignature.selector;
        selectors[2] = RouterHandler.newAgent.selector;
        selectors[3] = RouterHandler.newAgentFor.selector;

        targetSelector(FuzzSelector({addr: address(handler), selectors: selectors}));

        targetContract(address(handler));
    }

    function invariant_InitializedUser() public {
        assertEq(router.user(), _INIT_USER);
    }

    function invariant_ExactAgentsLength() public {
        assertEq(handler.ghostAgentsLength(), handler.actors().length);
    }

    function invariant_UniqueAgent() public {}

    function invariant_callSummary() public view {
        handler.callSummary();
    }
}
