// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {console2} from 'forge-std/console2.sol';
import {DeployBase} from './DeployBase.s.sol';
import {AaveV2FlashLoanCallback} from 'src/callbacks/AaveV2FlashLoanCallback.sol';
import {ICREATE3Factory} from 'create3-factory/ICREATE3Factory.sol';

contract DeployAaveV2FlashLoanCallback is DeployBase {
    function _run(
        address create3Factory,
        address router,
        AaveV2FlashLoanCallbackConfigs memory cfgs
    )
        internal
        isRouterAddressZero(router)
        isCREATE3FactoryAddressZero(create3Factory)
        returns (address deployedAddress)
    {
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
