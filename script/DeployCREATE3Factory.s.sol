// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {console2} from 'forge-std/console2.sol';
import {CREATE3Factory} from 'create3-factory/CREATE3Factory.sol';
import {DeployBaseScript} from './DeployBaseScript.s.sol';

abstract contract DeployCREATE3Factory is DeployBaseScript {
    struct Create3FactoryConfig {
        address deployedAddress;
        // constructor params
        address deployer;
    }

    Create3FactoryConfig internal create3FactoryConfig;

    function _deployCreate3Factory() internal returns (address deployedAddress) {
        Create3FactoryConfig memory cfg = create3FactoryConfig;
        deployedAddress = cfg.deployedAddress;
        if (deployedAddress == UNDEPLOYED) {
            deployedAddress = address(new CREATE3Factory(cfg.deployer));
            console2.log('CREATE3Factory Deployed:', deployedAddress);
        } else {
            console2.log('CREATE3Factory Exists. Skip deployment of CREATE3Factory:', deployedAddress);
        }
    }
}
