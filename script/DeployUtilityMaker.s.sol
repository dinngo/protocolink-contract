// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {console2} from 'forge-std/console2.sol';
import {DeployBase} from './DeployBase.s.sol';
import {UtilityMaker} from 'src/utility/UtilityMaker.sol';

contract DeployUtilityMaker is DeployBase {
    function _run(
        DeployParameters memory params
    ) internal virtual override isRouterAddressZero(params.router) returns (address deployedAddress) {
        deployedAddress = address(
            new UtilityMaker(
                params.router,
                params.makerProxyRegistry,
                params.makerCdpManager,
                params.makerProxyActions,
                params.dai,
                params.makerJug
            )
        );

        console2.log('UtilityMaker Deployed:', deployedAddress);
    }
}
