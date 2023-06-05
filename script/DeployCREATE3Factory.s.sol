// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {console2} from 'forge-std/console2.sol';
import {CREATE3Factory} from 'create3-factory/CREATE3Factory.sol';
import {DeployBase} from './DeployBase.s.sol';

contract DeployCREATE3Factory is DeployBase {
    function _run(Create3FactoryConfigs memory cfgs) internal returns (address deployedAddress) {
        deployedAddress = cfgs.deployedAddress;
        if ( deployedAddress == address(0)) {
            deployedAddress = address(new CREATE3Factory(cfgs.deployer));
            console2.log('CREATE3Factory Deployed:', deployedAddress);
        } else {
            console2.log('CREATE3Factory Exists. Skip deployment of CREATE3Factory:', deployedAddress);
        }
    }
}
