// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {console2} from 'forge-std/console2.sol';
import {ICREATE3Factory} from 'create3-factory/ICREATE3Factory.sol';

import {Router} from 'src/Router.sol';
import {DeployBase} from './DeployBase.s.sol';

abstract contract DeployRouter is DeployBase {
    struct RouterConfig {
        address deployedAddress;
        // constructor params
        address wrappedNative;
        address permit2;
        address owner;
        address pauser;
        address feeCollector;
        // extra params
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
                abi.encode(cfg.wrappedNative, cfg.permit2, cfg.owner, cfg.pauser, cfg.feeCollector)
            );
            deployedAddress = factory.deploy(salt, creationCode);
            console2.log('Router Deployed:', deployedAddress);
            Router router = Router(deployedAddress);
            console2.log('Router Owner:', router.owner());

            // Set and check signer
            router.addSigner(cfg.signer);
            require(router.signers(cfg.signer), 'Router signer is invalid');

            // Set and check fee rate
            if (cfg.feeRate > 0) {
                router.setFeeRate(cfg.feeRate);
            }
            require(router.feeRate() == cfg.feeRate, 'Router fee rate is invalid');
        } else {
            console2.log('Router Exists. Skip deployment of Router:', deployedAddress);
        }
    }
}
