// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {console2} from 'forge-std/console2.sol';
import {ICREATE3Factory} from 'create3-factory/ICREATE3Factory.sol';

import {RadiantV2FlashLoanCallback} from 'src/callbacks/RadiantV2FlashLoanCallback.sol';
import {DeployBaseScript} from 'script/DeployBaseScript.s.sol';

abstract contract DeployRadiantV2FlashLoanCallback is DeployBaseScript {
    struct RadiantV2FlashLoanCallbackConfig {
        address deployedAddress;
        // constructor params
        address radiantV2Provider;
        uint256 feeRate;
    }

    RadiantV2FlashLoanCallbackConfig internal radiantV2FlashLoanCallbackConfig;

    function _deployRadiantV2FlashLoanCallback(
        address create3Factory,
        address router
    )
        internal
        isRouterAddressZero(router)
        isCREATE3FactoryAddressZero(create3Factory)
        returns (address deployedAddress)
    {
        RadiantV2FlashLoanCallbackConfig memory cfg = radiantV2FlashLoanCallbackConfig;
        deployedAddress = cfg.deployedAddress;
        if (deployedAddress == UNDEPLOYED) {
            ICREATE3Factory factory = ICREATE3Factory(create3Factory);
            bytes32 salt = keccak256('protocolink.radiant.v2.flash.loan.callback.v1');
            bytes memory creationCode = abi.encodePacked(
                type(RadiantV2FlashLoanCallback).creationCode,
                abi.encode(router, cfg.radiantV2Provider, cfg.feeRate)
            );
            deployedAddress = factory.deploy(salt, creationCode);

            // check deployed parameters
            RadiantV2FlashLoanCallback callback = RadiantV2FlashLoanCallback(deployedAddress);
            require(callback.router() == router, 'RadiantV2FlashLoanCallback router is invalid');
            require(
                callback.radiantV2Provider() == cfg.radiantV2Provider,
                'RadiantV2FlashLoanCallback provider is invalid'
            );
            require(callback.feeRate() == cfg.feeRate, 'RadiantV2FlashLoanCallback fee rate is invalid');
            console2.log('RadiantV2FlashLoanCallback Deployed:', deployedAddress);
        } else {
            console2.log(
                'RadiantV2FlashLoanCallback Exists. Skip deployment of RadiantV2FlashLoanCallback:',
                deployedAddress
            );
        }
    }
}
