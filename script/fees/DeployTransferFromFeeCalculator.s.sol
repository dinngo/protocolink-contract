// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {console2} from 'forge-std/console2.sol';
import {ICREATE3Factory} from 'create3-factory/ICREATE3Factory.sol';

import {TransferFromFeeCalculator} from 'src/fees/TransferFromFeeCalculator.sol';
import {DeployBase} from 'script/DeployBase.s.sol';

abstract contract DeployTransferFromFeeCalculator is DeployBase {
    struct TransferFromFeeCalculatorConfig {
        address deployedAddress;
        // deploy params
        uint256 feeRate;
    }

    TransferFromFeeCalculatorConfig internal transferFromFeeCalculatorConfig;

    function _deployTransferFromFeeCalculator(
        address create3Factory,
        address router
    )
        internal
        isRouterAddressZero(router)
        isCREATE3FactoryAddressZero(create3Factory)
        returns (address deployedAddress)
    {
        TransferFromFeeCalculatorConfig memory cfg = transferFromFeeCalculatorConfig;
        deployedAddress = cfg.deployedAddress;
        if (deployedAddress == UNDEPLOYED) {
            ICREATE3Factory factory = ICREATE3Factory(create3Factory);
            bytes32 salt = keccak256('composable.router.transfer.from.fee.calculator');
            bytes memory creationCode = abi.encodePacked(
                type(TransferFromFeeCalculator).creationCode,
                abi.encode(router, cfg.feeRate)
            );
            deployedAddress = factory.deploy(salt, creationCode);
            console2.log('TransferFromFeeCalculator Deployed:', deployedAddress);
        } else {
            console2.log(
                'TransferFromFeeCalculator Exists. Skip deployment of TransferFromFeeCalculator:',
                deployedAddress
            );
        }
    }
}
