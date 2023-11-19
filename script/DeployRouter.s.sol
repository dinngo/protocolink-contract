// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {console2} from 'forge-std/console2.sol';
import {ICREATE3Factory} from 'create3-factory/ICREATE3Factory.sol';

import {Router} from 'src/Router.sol';
import {DeployBaseScript} from './DeployBaseScript.s.sol';

abstract contract DeployRouter is DeployBaseScript {
    struct RouterConfig {
        address deployedAddress;
        // constructor params
        address wrappedNative;
        address permit2;
        address deployer;
        // extra params
        address owner;
        address pauser;
        address defaultCollector;
        address signer;
        uint256 feeRate;
    }

    RouterConfig internal routerConfig;

    function _deployRouter(
        address create3Factory
    ) internal isCREATE3FactoryAddressZero(create3Factory) returns (address deployedAddress) {
        RouterConfig memory cfg = routerConfig;
        deployedAddress = cfg.deployedAddress;
        if (deployedAddress == UNDEPLOYED) {
            ICREATE3Factory factory = ICREATE3Factory(create3Factory);
            bytes32 salt = keccak256('protocolink.router.v1');
            bytes memory creationCode = abi.encodePacked(
                type(Router).creationCode,
                abi.encode(cfg.wrappedNative, cfg.permit2, cfg.deployer)
            );
            deployedAddress = factory.deploy(salt, creationCode);
            Router router = Router(deployedAddress);

            // Set and check pauser
            router.setPauser(cfg.pauser);
            require(router.pauser() == cfg.pauser, 'Router pauser is invalid');

            // Set and check fee collector
            router.setFeeCollector(cfg.defaultCollector);
            require(router.defaultCollector() == cfg.defaultCollector, 'Router fee collector is invalid');

            // Set and check signer
            router.addSigner(cfg.signer);
            require(router.signers(cfg.signer), 'Router signer is invalid');

            // Set and check fee rate
            if (cfg.feeRate > 0) {
                router.setFeeRate(cfg.feeRate);
            }
            require(router.feeRate() == cfg.feeRate, 'Router fee rate is invalid');

            // Set and check owner
            if (router.owner() != cfg.owner) router.transferOwnership(cfg.owner);
            require(router.owner() == cfg.owner, 'Router owner is invalid');
            console2.log('Router Deployed:', deployedAddress);
            console2.log('Router Owner:', router.owner());
        } else {
            console2.log('Router Exists. Skip deployment of Router:', deployedAddress);
        }
    }
}
