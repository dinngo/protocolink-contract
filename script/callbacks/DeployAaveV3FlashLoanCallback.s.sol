// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {console2} from 'forge-std/console2.sol';
import {ICREATE3Factory} from 'create3-factory/ICREATE3Factory.sol';

import {AaveV3FlashLoanCallback} from 'src/callbacks/AaveV3FlashLoanCallback.sol';
import {DeployBase} from 'script/DeployBase.s.sol';

contract DeployAaveV3FlashLoanCallback is DeployBase {
    struct AaveV3FlashLoanCallbackConfig {
        address deployedAddress;
        // deploy params
        // address router; use value from deployedRouterAddress
        address aaveV3Provider;
    }

    AaveV3FlashLoanCallbackConfig internal aaveV3FlashLoanCallbackConfig;

    function _deployAaveV3FlashLoanCallback(
        address create3Factory,
        address router
    )
        internal
        isRouterAddressZero(router)
        isCREATE3FactoryAddressZero(create3Factory)
        returns (address deployedAddress)
    {
        AaveV3FlashLoanCallbackConfig memory cfgs = aaveV3FlashLoanCallbackConfig;
        deployedAddress = cfgs.deployedAddress;
        if (deployedAddress == address(0)) {
            ICREATE3Factory factory = ICREATE3Factory(create3Factory);
            bytes32 salt = keccak256('composable.router.aave.v3.flash.loan.callback');
            bytes memory creationCode = abi.encodePacked(
                type(AaveV3FlashLoanCallback).creationCode,
                abi.encode(router, cfgs.aaveV3Provider)
            );
            deployedAddress = factory.deploy(salt, creationCode);
            console2.log('AaveV3FlashLoanCallback Deployed:', deployedAddress);
        } else {
            console2.log(
                'AaveV3FlashLoanCallback Exists. Skip deployment of AaveV3FlashLoanCallback:',
                deployedAddress
            );
        }
    }
}
