// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {console2} from 'forge-std/console2.sol';
import {DeployBase} from './DeployBase.s.sol';
import {Router} from 'src/Router.sol';
import {ICREATE3Factory} from 'create3-factory/ICREATE3Factory.sol';

contract DeployRouter is DeployBase {
    function _run(
        address create3Factory,
        RouterConfigs memory cfgs
    ) internal isCREATE3FactoryAddressZero(create3Factory) returns (address deployedAddress) {
        deployedAddress = cfgs.deployedAddress;
        if (deployedAddress == address(0)) {
            ICREATE3Factory factory = ICREATE3Factory(create3Factory);
            bytes32 salt = keccak256('composable.router.router');
            bytes memory creationCode = abi.encodePacked(
                type(Router).creationCode,
                abi.encode(cfgs.wrappedNative, cfgs.owner, cfgs.pauser, cfgs.feeCollector)
            );
            deployedAddress = factory.deploy(salt, creationCode);
            console2.log('Router Deployed:', deployedAddress);
            Router router = Router(deployedAddress);
            console2.log('Router Owner:', router.owner());
        } else {
            console2.log('Router Exists. Skip deployment of Router:', deployedAddress);
        }
    }
}
