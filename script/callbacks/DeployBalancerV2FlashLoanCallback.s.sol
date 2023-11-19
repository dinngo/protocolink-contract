// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {console2} from 'forge-std/console2.sol';
import {ICREATE3Factory} from 'create3-factory/ICREATE3Factory.sol';

import {BalancerV2FlashLoanCallback} from 'src/callbacks/BalancerV2FlashLoanCallback.sol';
import {DeployBaseScript} from 'script/DeployBaseScript.s.sol';

abstract contract DeployBalancerV2FlashLoanCallback is DeployBaseScript {
    struct BalancerV2FlashLoanCallbackConfig {
        address deployedAddress;
        // constructor params
        address balancerV2Vault;
        uint256 feeRate;
    }

    BalancerV2FlashLoanCallbackConfig internal balancerV2FlashLoanCallbackConfig;

    function _deployBalancerV2FlashLoanCallback(
        address create3Factory,
        address router
    )
        internal
        isRouterAddressZero(router)
        isCREATE3FactoryAddressZero(create3Factory)
        returns (address deployedAddress)
    {
        BalancerV2FlashLoanCallbackConfig memory cfg = balancerV2FlashLoanCallbackConfig;
        deployedAddress = cfg.deployedAddress;
        if (deployedAddress == UNDEPLOYED) {
            ICREATE3Factory factory = ICREATE3Factory(create3Factory);
            bytes32 salt = keccak256('protocolink.balancer.v2.flash.loan.callback.v1');
            bytes memory creationCode = abi.encodePacked(
                type(BalancerV2FlashLoanCallback).creationCode,
                abi.encode(router, cfg.balancerV2Vault, cfg.feeRate)
            );
            deployedAddress = factory.deploy(salt, creationCode);

            // check deployed parameters
            BalancerV2FlashLoanCallback callback = BalancerV2FlashLoanCallback(deployedAddress);
            require(callback.router() == router, 'BalancerV2FlashLoanCallback router is invalid');
            require(callback.balancerV2Vault() == cfg.balancerV2Vault, 'BalancerV2FlashLoanCallback vault is invalid');
            require(callback.feeRate() == cfg.feeRate, 'BalancerV2FlashLoanCallback fee rate is invalid');
            console2.log('BalancerV2FlashLoanCallback Deployed:', deployedAddress);
        } else {
            console2.log(
                'BalancerV2FlashLoanCallback Exists. Skip deployment of BalancerV2FlashLoanCallback:',
                deployedAddress
            );
        }
    }
}
