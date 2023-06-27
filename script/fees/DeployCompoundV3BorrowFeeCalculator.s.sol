// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {console2} from 'forge-std/console2.sol';
import {ICREATE3Factory} from 'create3-factory/ICREATE3Factory.sol';

import {CompoundV3BorrowFeeCalculator} from 'src/fees/CompoundV3BorrowFeeCalculator.sol';
import {DeployBase} from 'script/DeployBase.s.sol';

abstract contract DeployCompoundV3BorrowFeeCalculator is DeployBase {
    struct CompoundV3BorrowFeeCalculatorConfig {
        address deployedAddress;
        // deploy params
        uint256 feeRate;
    }

    CompoundV3BorrowFeeCalculatorConfig internal compoundV3BorrowFeeCalculatorConfig;

    function _deployCompoundV3BorrowFeeCalculator(
        address create3Factory,
        address router
    )
        internal
        isRouterAddressZero(router)
        isCREATE3FactoryAddressZero(create3Factory)
        returns (address deployedAddress)
    {
        CompoundV3BorrowFeeCalculatorConfig memory cfg = compoundV3BorrowFeeCalculatorConfig;
        deployedAddress = cfg.deployedAddress;
        if (deployedAddress == UNDEPLOYED) {
            ICREATE3Factory factory = ICREATE3Factory(create3Factory);
            bytes32 salt = keccak256('protocolink.compound.v3.borrow.fee.calculator');
            bytes memory creationCode = abi.encodePacked(
                type(CompoundV3BorrowFeeCalculator).creationCode,
                abi.encode(router, cfg.feeRate)
            );
            deployedAddress = factory.deploy(salt, creationCode);
            console2.log('CompoundV3BorrowFeeCalculator Deployed:', deployedAddress);
        } else {
            console2.log(
                'CompoundV3BorrowFeeCalculator Exists. Skip deployment of CompoundV3BorrowFeeCalculator:',
                deployedAddress
            );
        }
    }
}
