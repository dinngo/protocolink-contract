// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {console2} from 'forge-std/console2.sol';
import {CREATE3Factory} from 'create3-factory/CREATE3Factory.sol';
import {DeployBase} from './DeployBase.s.sol';

contract DeployCREATE3Factory is DeployBase {
    struct Create3FactoryConfig {
        address deployedAddress;
        // deploy params
        address deployer;
    }

    Create3FactoryConfig internal create3FactoryConfig;

    function _deployCreate3Factory() internal returns (address deployedAddress) {
        Create3FactoryConfig memory cfgs = create3FactoryConfig;
        deployedAddress = cfgs.deployedAddress;
        if (deployedAddress == address(0)) {
            deployedAddress = address(new CREATE3Factory(cfgs.deployer));
            console2.log('CREATE3Factory Deployed:', deployedAddress);
        } else {
            console2.log('CREATE3Factory Exists. Skip deployment of CREATE3Factory:', deployedAddress);
        }
    }
}
