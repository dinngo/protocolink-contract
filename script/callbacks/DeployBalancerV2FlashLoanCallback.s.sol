// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {console2} from 'forge-std/console2.sol';
import {ICREATE3Factory} from 'create3-factory/ICREATE3Factory.sol';

import {BalancerV2FlashLoanCallback} from 'src/callbacks/BalancerV2FlashLoanCallback.sol';
import {DeployBase} from 'script/DeployBase.s.sol';

contract DeployBalancerV2FlashLoanCallback is DeployBase {
    struct BalancerV2FlashLoanCallbackConfig {
        address deployedAddress;
        // deploy params
        // address router; use value from deployedRouterAddress
        address balancerV2Vault;
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
        BalancerV2FlashLoanCallbackConfig memory cfgs = balancerV2FlashLoanCallbackConfig;
        deployedAddress = cfgs.deployedAddress;
        if (deployedAddress == address(0)) {
            ICREATE3Factory factory = ICREATE3Factory(create3Factory);
            bytes32 salt = keccak256('composable.router.balancer.v2.flash.loan.callback');
            bytes memory creationCode = abi.encodePacked(
                type(BalancerV2FlashLoanCallback).creationCode,
                abi.encode(router, cfgs.balancerV2Vault)
            );
            deployedAddress = factory.deploy(salt, creationCode);
            console2.log('BalancerV2FlashLoanCallback Deployed:', deployedAddress);
        } else {
            console2.log(
                'BalancerV2FlashLoanCallback Exists. Skip deployment of BalancerV2FlashLoanCallback:',
                deployedAddress
            );
        }
    }
}
