// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {console2} from 'forge-std/console2.sol';
import {DeployBase} from './DeployBase.s.sol';
import {Router} from 'src/Router.sol';
import {ICREATE3Factory} from 'create3-factory/ICREATE3Factory.sol';

contract DeployRouter is DeployBase {
    function _run(
        DeployParameters memory params
    ) internal virtual override isCREATE3FactoryAddressZero(params.create3Factory) returns (address deployedAddress) {
        ICREATE3Factory factory = ICREATE3Factory(params.create3Factory);
        bytes32 salt = keccak256('composable.router.router');
        bytes memory creationCode = abi.encodePacked(
            type(Router).creationCode,
            abi.encode(params.wrappedNative, params.owner, params.pauser, params.feeCollector)
        );
        deployedAddress = factory.deploy(salt, creationCode);
        console2.log('Router Deployed:', deployedAddress);

        Router router = Router(deployedAddress);
        console2.log('Router Owner:', router.owner());
    }
}
