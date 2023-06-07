// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {console2} from 'forge-std/console2.sol';
import {ICREATE3Factory} from 'create3-factory/ICREATE3Factory.sol';

import {AaveV2FlashLoanCallback} from 'src/callbacks/AaveV2FlashLoanCallback.sol';
import {DeployBase} from 'script/DeployBase.s.sol';

contract DeployAaveV2FlashLoanCallback is DeployBase {
    struct AaveV2FlashLoanCallbackConfig {
        address deployedAddress;
        // deploy params
        // address router; use value from RouterConfig.deployedAddress
        address aaveV2Provider;
    }

    AaveV2FlashLoanCallbackConfig internal aaveV2FlashLoanCallbackConfig;

    function _deployAaveV2FlashLoanCallback(
        address create3Factory,
        address router
    )
        internal
        isRouterAddressZero(router)
        isCREATE3FactoryAddressZero(create3Factory)
        returns (address deployedAddress)
    {
        AaveV2FlashLoanCallbackConfig memory cfgs = aaveV2FlashLoanCallbackConfig;
        deployedAddress = cfgs.deployedAddress;
        if (deployedAddress == address(0)) {
            ICREATE3Factory factory = ICREATE3Factory(create3Factory);
            bytes32 salt = keccak256('composable.router.aave.v2.flash.loan.callback');
            bytes memory creationCode = abi.encodePacked(
                type(AaveV2FlashLoanCallback).creationCode,
                abi.encode(router, cfgs.aaveV2Provider)
            );
            deployedAddress = factory.deploy(salt, creationCode);
            console2.log('AaveV2FlashLoanCallback Deployed:', deployedAddress);
        } else {
            console2.log(
                'AaveV2FlashLoanCallback Exists. Skip deployment of AaveV2FlashLoanCallback:',
                deployedAddress
            );
        }
    }
}
