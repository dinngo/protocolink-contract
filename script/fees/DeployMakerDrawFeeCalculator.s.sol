// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {console2} from 'forge-std/console2.sol';
import {ICREATE3Factory} from 'create3-factory/ICREATE3Factory.sol';

import {MakerDrawFeeCalculator} from 'src/fees/MakerDrawFeeCalculator.sol';
import {DeployBase} from 'script/DeployBase.s.sol';

contract DeployMakerDrawFeeCalculator is DeployBase {
    struct MakerDrawFeeCalculatorConfig {
        address deployedAddress;
        // deploy params
        // address router; use value from deployedRouterAddress
        uint256 feeRate;
        address daiToken;
    }

    MakerDrawFeeCalculatorConfig internal makerDrawFeeCalculatorConfig;

    function _deployMakerDrawFeeCalculator(
        address create3Factory,
        address router
    )
        internal
        isRouterAddressZero(router)
        isCREATE3FactoryAddressZero(create3Factory)
        returns (address deployedAddress)
    {
        MakerDrawFeeCalculatorConfig memory cfgs = makerDrawFeeCalculatorConfig;
        deployedAddress = cfgs.deployedAddress;
        if (deployedAddress == address(0)) {
            ICREATE3Factory factory = ICREATE3Factory(create3Factory);
            bytes32 salt = keccak256('composable.router.maker.draw.fee.calculator');
            bytes memory creationCode = abi.encodePacked(
                type(MakerDrawFeeCalculator).creationCode,
                abi.encode(router, cfgs.feeRate, cfgs.daiToken)
            );
            deployedAddress = factory.deploy(salt, creationCode);
            console2.log('MakerDrawFeeCalculator Deployed:', deployedAddress);
        } else {
            console2.log('MakerDrawFeeCalculator Exists. Skip deployment of MakerDrawFeeCalculator:', deployedAddress);
        }
    }
}
