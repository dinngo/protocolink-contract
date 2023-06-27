// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {console2} from 'forge-std/console2.sol';
import {ICREATE3Factory} from 'create3-factory/ICREATE3Factory.sol';

import {AaveFlashLoanFeeCalculator} from 'src/fees/AaveFlashLoanFeeCalculator.sol';
import {DeployBase} from 'script/DeployBase.s.sol';

abstract contract DeployAaveFlashLoanFeeCalculator is DeployBase {
    struct AaveFlashLoanFeeCalculatorConfig {
        address deployedAddress;
        // deploy params
        uint256 feeRate;
        address aaveV3Provider;
    }

    AaveFlashLoanFeeCalculatorConfig internal aaveFlashLoanFeeCalculatorConfig;

    function _deployAaveFlashLoanFeeCalculator(
        address create3Factory,
        address router
    )
        internal
        isRouterAddressZero(router)
        isCREATE3FactoryAddressZero(create3Factory)
        returns (address deployedAddress)
    {
        AaveFlashLoanFeeCalculatorConfig memory cfg = aaveFlashLoanFeeCalculatorConfig;
        deployedAddress = cfg.deployedAddress;
        if (deployedAddress == UNDEPLOYED) {
            ICREATE3Factory factory = ICREATE3Factory(create3Factory);
            bytes32 salt = keccak256('protocolink.aave.flash.loan.fee.calculator');
            bytes memory creationCode = abi.encodePacked(
                type(AaveFlashLoanFeeCalculator).creationCode,
                abi.encode(router, cfg.feeRate, cfg.aaveV3Provider)
            );
            deployedAddress = factory.deploy(salt, creationCode);
            console2.log('AaveFlashLoanFeeCalculator Deployed:', deployedAddress);
        } else {
            console2.log(
                'AaveFlashLoanFeeCalculator Exists. Skip deployment of AaveFlashLoanFeeCalculator:',
                deployedAddress
            );
        }
    }
}
