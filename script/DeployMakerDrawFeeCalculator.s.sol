// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {console2} from 'forge-std/console2.sol';
import {DeployBase} from './DeployBase.s.sol';
import {MakerDrawFeeCalculator} from 'src/fees/MakerDrawFeeCalculator.sol';
import {ICREATE3Factory} from 'create3-factory/ICREATE3Factory.sol';

contract DeployMakerDrawFeeCalculator is DeployBase {
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
        bytes32 salt = keccak256('furucombo.composable.fee.makerdraw');
        bytes memory creationCode = abi.encodePacked(
            type(MakerDrawFeeCalculator).creationCode,
            abi.encode(params.router, params.makerDrawFeeCalculatorFeeRate, params.dai)
        );
        deployedAddress = factory.deploy(salt, creationCode);
        console2.log('MakerDrawFeeCalculator Deployed:', deployedAddress);
    }
}
