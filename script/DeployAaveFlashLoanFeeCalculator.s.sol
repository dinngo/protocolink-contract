// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {console2} from 'forge-std/console2.sol';
import {DeployBase} from './DeployBase.s.sol';
import {AaveFlashLoanFeeCalculator} from 'src/fees/AaveFlashLoanFeeCalculator.sol';
import {ICREATE3Factory} from 'create3-factory/ICREATE3Factory.sol';

contract DeployAaveFlashLoanFeeCalculator is DeployBase {
    function _run(
        DeployParameters memory params
    )
        internal
        virtual
        override
        isRouterAddressZero(params.router)
        isCREATE3FactoryAddressZero(params.create3Factory)
        returns (address deployedAddress)
    {
        ICREATE3Factory factory = ICREATE3Factory(params.create3Factory);
        bytes32 salt = keccak256('composable.router.aave.flash.loan.fee.calculator');
        bytes memory creationCode = abi.encodePacked(
            type(AaveFlashLoanFeeCalculator).creationCode,
            abi.encode(params.router, params.aaveFlashLoanFeeCalculatorFeeRate, params.aaveV3Provider)
        );
        deployedAddress = factory.deploy(salt, creationCode);
        console2.log('AaveFlashLoanFeeCalculator Deployed:', deployedAddress);
    }
}
