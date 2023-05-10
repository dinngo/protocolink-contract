// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {console2} from 'forge-std/console2.sol';
import {DeployBase} from './DeployBase.s.sol';
import {AaveBorrowFeeCalculator} from 'src/fees/AaveBorrowFeeCalculator.sol';
import {ICREATE3Factory} from 'create3-factory/ICREATE3Factory.sol';

contract DeployAaveBorrowFeeCalculator is DeployBase {
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
        bytes32 salt = keccak256('aave.borrow.fee.calculator');
        bytes memory creationCode = abi.encodePacked(
            type(AaveBorrowFeeCalculator).creationCode,
            abi.encode(params.router, params.aaveBorrowFeeCalculatorFeeRate, params.aaveV3Provider)
        );
        deployedAddress = factory.deploy(salt, creationCode);
        console2.log('AaveBorrowFeeCalculator Deployed:', deployedAddress);
    }
}
