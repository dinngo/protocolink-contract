// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {console2} from 'forge-std/console2.sol';
import {ICREATE3Factory} from 'create3-factory/ICREATE3Factory.sol';

import {SparkFlashLoanCallback} from 'src/callbacks/SparkFlashLoanCallback.sol';
import {DeployBaseScript} from 'script/DeployBaseScript.s.sol';

abstract contract DeploySparkFlashLoanCallback is DeployBaseScript {
    struct SparkFlashLoanCallbackConfig {
        address deployedAddress;
        // constructor params
        address sparkProvider;
        uint256 feeRate;
    }

    SparkFlashLoanCallbackConfig internal sparkFlashLoanCallbackConfig;

    function _deploySparkFlashLoanCallback(
        address create3Factory,
        address router
    )
        internal
        isRouterAddressZero(router)
        isCREATE3FactoryAddressZero(create3Factory)
        returns (address deployedAddress)
    {
        SparkFlashLoanCallbackConfig memory cfg = sparkFlashLoanCallbackConfig;
        deployedAddress = cfg.deployedAddress;
        if (deployedAddress == UNDEPLOYED) {
            ICREATE3Factory factory = ICREATE3Factory(create3Factory);
            bytes32 salt = keccak256('protocolink.spark.flash.loan.callback.v1');
            bytes memory creationCode = abi.encodePacked(
                type(SparkFlashLoanCallback).creationCode,
                abi.encode(router, cfg.sparkProvider, cfg.feeRate)
            );
            deployedAddress = factory.deploy(salt, creationCode);

            // check deployed parameters
            SparkFlashLoanCallback callback = SparkFlashLoanCallback(deployedAddress);
            require(callback.router() == router, 'SparkFlashLoanCallback router is invalid');
            require(callback.sparkProvider() == cfg.sparkProvider, 'SparkFlashLoanCallback provider is invalid');
            require(callback.feeRate() == cfg.feeRate, 'SparkFlashLoanCallback fee rate is invalid');
            console2.log('SparkFlashLoanCallback Deployed:', deployedAddress);
        } else {
            console2.log('SparkFlashLoanCallback Exists. Skip deployment of SparkFlashLoanCallback:', deployedAddress);
        }
    }
}
