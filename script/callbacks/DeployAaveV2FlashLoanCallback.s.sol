// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {console2} from 'forge-std/console2.sol';
import {ICREATE3Factory} from 'create3-factory/ICREATE3Factory.sol';

import {AaveV2FlashLoanCallback} from 'src/callbacks/AaveV2FlashLoanCallback.sol';
import {DeployBase} from 'script/DeployBase.s.sol';

abstract contract DeployAaveV2FlashLoanCallback is DeployBase {
    struct AaveV2FlashLoanCallbackConfig {
        address deployedAddress;
        // deploy params
        address aaveV2Provider;
        uint256 feeRate;
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
        AaveV2FlashLoanCallbackConfig memory cfg = aaveV2FlashLoanCallbackConfig;
        deployedAddress = cfg.deployedAddress;
        if (deployedAddress == UNDEPLOYED) {
            ICREATE3Factory factory = ICREATE3Factory(create3Factory);
            bytes32 salt = keccak256('protocolink.aave.v2.flash.loan.callback.v1');
            bytes memory creationCode = abi.encodePacked(
                type(AaveV2FlashLoanCallback).creationCode,
                abi.encode(router, cfg.aaveV2Provider, cfg.feeRate)
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
