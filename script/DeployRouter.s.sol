// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {console2} from 'forge-std/console2.sol';
import {DeployBase} from './DeployBase.s.sol';
import {Router} from 'src/Router.sol';

contract DeployRouter is DeployBase {
    function _run(DeployParameters memory params) internal virtual override returns (address deployedAddress) {
        deployedAddress = address(new Router(params.wrappedNative, params.pauser, params.feeCollector));
        console2.log('Router Deployed:', deployedAddress);
    }
}
