// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {console2} from 'forge-std/console2.sol';
import {DeployBase} from './DeployBase.s.sol';
import {Permit2FeeCalculator} from 'src/fees/Permit2FeeCalculator.sol';
import {ICREATE3Factory} from 'create3-factory/ICREATE3Factory.sol';

contract DeployPermit2FeeCalculator is DeployBase {
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
        bytes32 salt = keccak256('permit2.fee.calculator');
        bytes memory creationCode = abi.encodePacked(
            type(Permit2FeeCalculator).creationCode,
            abi.encode(params.router, params.permit2FeeCalculatorFeeRate)
        );
        deployedAddress = factory.deploy(salt, creationCode);
        console2.log('Permit2FeeCalculator Deployed:', deployedAddress);
    }
}
