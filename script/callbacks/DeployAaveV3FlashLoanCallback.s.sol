// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {console2} from 'forge-std/console2.sol';
import {ICREATE3Factory} from 'create3-factory/ICREATE3Factory.sol';

import {AaveV3FlashLoanCallback} from 'src/callbacks/AaveV3FlashLoanCallback.sol';
import {DeployBaseScript} from 'script/DeployBaseScript.s.sol';

abstract contract DeployAaveV3FlashLoanCallback is DeployBaseScript {
    struct AaveV3FlashLoanCallbackConfig {
        address deployedAddress;
        // constructor params
        address aaveV3Provider;
        uint256 feeRate;
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
        AaveV3FlashLoanCallbackConfig memory cfg = aaveV3FlashLoanCallbackConfig;
        deployedAddress = cfg.deployedAddress;
        if (deployedAddress == UNDEPLOYED) {
            ICREATE3Factory factory = ICREATE3Factory(create3Factory);
            bytes32 salt = keccak256('protocolink.aave.v3.flash.loan.callback.v1');
            bytes memory creationCode = abi.encodePacked(
                type(AaveV3FlashLoanCallback).creationCode,
                abi.encode(router, cfg.aaveV3Provider, cfg.feeRate)
            );
            deployedAddress = factory.deploy(salt, creationCode);

            // check deployed parameters
            AaveV3FlashLoanCallback callback = AaveV3FlashLoanCallback(deployedAddress);
            require(callback.router() == router, 'AaveV3FlashLoanCallback router is invalid');
            require(callback.aaveV3Provider() == cfg.aaveV3Provider, 'AaveV3FlashLoanCallback provider is invalid');
            require(callback.feeRate() == cfg.feeRate, 'AaveV3FlashLoanCallback fee rate is invalid');
            console2.log('AaveV3FlashLoanCallback Deployed:', deployedAddress);
        } else {
            console2.log(
                'AaveV3FlashLoanCallback Exists. Skip deployment of AaveV3FlashLoanCallback:',
                deployedAddress
            );
        }
    }
}
