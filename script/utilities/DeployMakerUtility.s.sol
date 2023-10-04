// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {console2} from 'forge-std/console2.sol';
import {ICREATE3Factory} from 'create3-factory/ICREATE3Factory.sol';

import {MakerUtility} from 'src/utilities/MakerUtility.sol';
import {DeployBaseScript} from 'script/DeployBaseScript.s.sol';

abstract contract DeployMakerUtility is DeployBaseScript {
    struct MakerUtilityConfig {
        address deployedAddress;
        // constructor params
        address proxyRegistry;
        address cdpManager;
        address proxyActions;
        address daiToken;
        address jug;
    }

    MakerUtilityConfig internal makerUtilityConfig;

    function _deployMakerUtility(
        address create3Factory,
        address router
    )
        internal
        isRouterAddressZero(router)
        isCREATE3FactoryAddressZero(create3Factory)
        returns (address deployedAddress)
    {
        MakerUtilityConfig memory cfg = makerUtilityConfig;
        deployedAddress = cfg.deployedAddress;
        if (deployedAddress == UNDEPLOYED) {
            ICREATE3Factory factory = ICREATE3Factory(create3Factory);
            bytes32 salt = keccak256('protocolink.maker.utility.v1');
            bytes memory creationCode = abi.encodePacked(
                type(MakerUtility).creationCode,
                abi.encode(router, cfg.proxyRegistry, cfg.cdpManager, cfg.proxyActions, cfg.daiToken, cfg.jug)
            );
            deployedAddress = factory.deploy(salt, creationCode);
            console2.log('MakerUtility Deployed:', deployedAddress);
        } else {
            console2.log('MakerUtility Exists. Skip deployment of MakerUtility:', deployedAddress);
        }
    }
}
