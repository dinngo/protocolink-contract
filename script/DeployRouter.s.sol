// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {console2} from 'forge-std/console2.sol';
import {ICREATE3Factory} from 'create3-factory/ICREATE3Factory.sol';

import {Router} from 'src/Router.sol';
import {DeployBase} from './DeployBase.s.sol';

abstract contract DeployRouter is DeployBase {
    address public constant SIGNER = 0xffFf5a88840FF1f168E163ACD771DFb292164cFA;

    struct RouterConfig {
        address deployedAddress;
        // deploy params
        address wrappedNative;
        address permit2;
        address owner;
        address pauser;
        address feeCollector;
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
            router.addSigner(SIGNER);
            if (router.signers(SIGNER)) {
                console2.log('Router Signer:', SIGNER);
            } else {
                console2.log('Router Signer is invalid');
            }
        } else {
            console2.log('Router Exists. Skip deployment of Router:', deployedAddress);
        }
    }
}
