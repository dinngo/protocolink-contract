// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {console2} from 'forge-std/console2.sol';
import {DeployBase} from './DeployBase.s.sol';
import {CompoundV3BorrowFeeCalculator} from 'src/fees/CompoundV3BorrowFeeCalculator.sol';

import {ICREATE3Factory} from 'create3-factory/ICREATE3Factory.sol';

contract DeployCompoundV3BorrowFeeCalculator is DeployBase {
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
        bytes32 salt = keccak256('composable.router.compound.v3.borrow.fee.calculator');
        bytes memory creationCode = abi.encodePacked(
            type(CompoundV3BorrowFeeCalculator).creationCode,
            abi.encode(params.router, params.compoundV3BorrowFeeCalculatorFeeRate)
        );
        deployedAddress = factory.deploy(salt, creationCode);
        console2.log('CompoundV3BorrowFeeCalculator Deployed:', deployedAddress);
    }
}
