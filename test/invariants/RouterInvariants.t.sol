// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {Router} from '../../src/Router.sol';
import {RouterHandler} from './handlers/RouterHandler.sol';

contract RouterInvariantsTest is Test {
    address internal constant _INIT_USER = address(1);

    Router public router;
    RouterHandler public handler;

    function setUp() external {
        router = new Router(makeAddr('WrappedNative'), makeAddr('Pauser'), makeAddr('Signer'));
        handler = new RouterHandler(router);

        bytes4[] memory selectors = new bytes4[](4);
        selectors[0] = RouterHandler.execute.selector;
        selectors[1] = RouterHandler.executeWithSignature.selector;
        selectors[2] = RouterHandler.newAgent.selector;
        selectors[3] = RouterHandler.newAgentFor.selector;
        targetSelector(FuzzSelector({addr: address(handler), selectors: selectors}));
        targetContract(address(handler));

        vm.label(address(router), 'Router');
        vm.label(address(handler), 'RouterHandler');
    }

    function invariant_initializedUser() external {
        assertEq(router.user(), _INIT_USER);
    }

    function invariant_matchedAgentsLength() external {
        assertEq(handler.ghostAgentsLength(), handler.actorsLength());
    }

    function invariant_matchedAgents() external {
        for (uint256 i; i < handler.ghostAgentsLength(); ++i) {
            address ghostAgent = handler.ghostAgents(i);
            assertFalse(ghostAgent == address(0));

            bool found;
            for (uint256 j; j < handler.actorsLength(); ++j) {
                address user = handler.actors(j);
                // Each ghost agent should be found in router agents by each user
                if (ghostAgent == address(router.agents(user))) {
                    found = true;
                    break;
                }
            }
            assertTrue(found);
        }
    }

    function invariant_uniqueAgent() external {
        for (uint256 i; i < handler.ghostAgentsLength(); ++i) {
            for (uint256 j = i + 1; j < handler.ghostAgentsLength(); ++j) {
                assertFalse(handler.ghostAgents(i) == handler.ghostAgents(j));
            }
        }
    }

    function invariant_callSummary() external view {
        handler.callSummary();
    }
}
