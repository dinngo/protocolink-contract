// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {console2} from 'forge-std/console2.sol';
import {ICREATE3Factory} from 'create3-factory/ICREATE3Factory.sol';

import {Permit2FeeCalculator} from 'src/fees/Permit2FeeCalculator.sol';
import {DeployBase} from 'script/DeployBase.s.sol';

abstract contract DeployPermit2FeeCalculator is DeployBase {
    struct Permit2FeeCalculatorConfig {
        address deployedAddress;
        // deploy params
        uint256 feeRate;
    }

    Permit2FeeCalculatorConfig internal permit2FeeCalculatorConfig;

    function _deployPermit2FeeCalculator(
        address create3Factory,
        address router
    )
        internal
        isRouterAddressZero(router)
        isCREATE3FactoryAddressZero(create3Factory)
        returns (address deployedAddress)
    {
        Permit2FeeCalculatorConfig memory cfg = permit2FeeCalculatorConfig;
        deployedAddress = cfg.deployedAddress;
        if (deployedAddress == UNDEPLOYED) {
            ICREATE3Factory factory = ICREATE3Factory(create3Factory);
            bytes32 salt = keccak256('protocolink.permit2.fee.calculator');
            bytes memory creationCode = abi.encodePacked(
                type(Permit2FeeCalculator).creationCode,
                abi.encode(router, cfg.feeRate)
            );
            deployedAddress = factory.deploy(salt, creationCode);
            console2.log('Permit2FeeCalculator Deployed:', deployedAddress);
        } else {
            console2.log('Permit2FeeCalculator Exists. Skip deployment of Permit2FeeCalculator:', deployedAddress);
        }
    }
}
