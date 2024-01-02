// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {console2} from 'forge-std/console2.sol';
import {ICREATE3Factory} from 'create3-factory/ICREATE3Factory.sol';

import {MorphoFlashLoanCallback} from 'src/callbacks/MorphoFlashLoanCallback.sol';
import {DeployBaseScript} from 'script/DeployBaseScript.s.sol';

abstract contract DeployMorphoFlashLoanCallback is DeployBaseScript {
    struct MorphoFlashLoanCallbackConfig {
        address deployedAddress;
        // constructor params
        address morpho;
        uint256 feeRate;
    }

    MorphoFlashLoanCallbackConfig internal morphoFlashLoanCallbackConfig;

    function _deployMorphoFlashLoanCallback(
        address create3Factory,
        address router
    )
        internal
        isRouterAddressZero(router)
        isCREATE3FactoryAddressZero(create3Factory)
        returns (address deployedAddress)
    {
        MorphoFlashLoanCallbackConfig memory cfg = morphoFlashLoanCallbackConfig;
        deployedAddress = cfg.deployedAddress;
        if (deployedAddress == UNDEPLOYED) {
            ICREATE3Factory factory = ICREATE3Factory(create3Factory);
            bytes32 salt = keccak256('protocolink.morpho.flash.loan.callback.v1');
            bytes memory creationCode = abi.encodePacked(
                type(MorphoFlashLoanCallback).creationCode,
                abi.encode(router, cfg.morpho, cfg.feeRate)
            );
            deployedAddress = factory.deploy(salt, creationCode);

            // check deployed parameters
            MorphoFlashLoanCallback callback = MorphoFlashLoanCallback(deployedAddress);
            require(callback.router() == router, 'MorphoFlashLoanCallback router is invalid');
            require(callback.morpho() == cfg.morpho, 'MorphoFlashLoanCallback morpho is invalid');
            require(callback.feeRate() == cfg.feeRate, 'MorphoFlashLoanCallback fee rate is invalid');
            console2.log('MorphoFlashLoanCallback Deployed:', deployedAddress);
        } else {
            console2.log(
                'MorphoFlashLoanCallback Exists. Skip deployment of MorphoFlashLoanCallback:',
                deployedAddress
            );
        }
    }
}
