// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {console2} from 'forge-std/console2.sol';
import {DeployBase} from './DeployBase.s.sol';
import {MakerUtility} from 'src/utilities/MakerUtility.sol';

contract DeployMakerUtility is DeployBase {
    function _run(
        DeployParameters memory params
    ) internal virtual override isRouterAddressZero(params.router) returns (address deployedAddress) {
        deployedAddress = address(
            new MakerUtility(
                params.router,
                params.makerProxyRegistry,
                params.makerCdpManager,
                params.makerProxyActions,
                params.dai,
                params.makerJug
            )
        );

        console2.log('MakerUtility Deployed:', deployedAddress);
    }
}
