// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {console2} from 'forge-std/console2.sol';
import {DeployBase} from './DeployBase.s.sol';
import {BalancerV2FlashLoanCallback} from 'src/callbacks/BalancerV2FlashLoanCallback.sol';
import {ICREATE3Factory} from 'create3-factory/ICREATE3Factory.sol';

contract DeployBalancerV2FlashLoanCallback is DeployBase {
    function _run(
        address create3Factory,
        address router,
        BalancerV2FlashLoanCallbackConfigs memory cfgs
    )
        internal
        isRouterAddressZero(router)
        isCREATE3FactoryAddressZero(create3Factory)
        returns (address deployedAddress)
    {
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
