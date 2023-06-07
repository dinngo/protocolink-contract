// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {console2} from 'forge-std/console2.sol';
import {ICREATE3Factory} from 'create3-factory/ICREATE3Factory.sol';

import {NativeFeeCalculator} from 'src/fees/NativeFeeCalculator.sol';
import {DeployBase} from 'script/DeployBase.s.sol';

contract DeployNativeFeeCalculator is DeployBase {
    struct NativeFeeCalculatorConfig {
        address deployedAddress;
        // deploy params
        // address router; use value from deployedRouterAddress
        uint256 feeRate;
    }

    NativeFeeCalculatorConfig internal nativeFeeCalculatorConfig;

    function _deployNativeFeeCalculator(
        address create3Factory,
        address router
    )
        internal
        isRouterAddressZero(router)
        isCREATE3FactoryAddressZero(create3Factory)
        returns (address deployedAddress)
    {
        NativeFeeCalculatorConfig memory cfgs = nativeFeeCalculatorConfig;
        deployedAddress = cfgs.deployedAddress;
        if (deployedAddress == address(0)) {
            ICREATE3Factory factory = ICREATE3Factory(create3Factory);
            bytes32 salt = keccak256('composable.router.native.fee.calculator');
            bytes memory creationCode = abi.encodePacked(
                type(NativeFeeCalculator).creationCode,
                abi.encode(router, cfgs.feeRate)
            );
            deployedAddress = factory.deploy(salt, creationCode);
            console2.log('NativeFeeCalculator Deployed:', deployedAddress);
        } else {
            console2.log('NativeFeeCalculator Exists. Skip deployment of NativeFeeCalculator:', deployedAddress);
        }
    }
}
