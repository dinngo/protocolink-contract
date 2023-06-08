// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {console2} from 'forge-std/console2.sol';
import {ICREATE3Factory} from 'create3-factory/ICREATE3Factory.sol';

import {AaveBorrowFeeCalculator} from 'src/fees/AaveBorrowFeeCalculator.sol';
import {DeployBase} from 'script/DeployBase.s.sol';

abstract contract DeployAaveBorrowFeeCalculator is DeployBase {
    struct AaveBorrowFeeCalculatorConfig {
        address deployedAddress;
        // deploy params
        uint256 feeRate;
        address aaveV3Provider;
    }

    AaveBorrowFeeCalculatorConfig internal aaveBorrowFeeCalculatorConfig;

    function _deployAaveBorrowFeeCalculator(
        address create3Factory,
        address router
    )
        internal
        isRouterAddressZero(router)
        isCREATE3FactoryAddressZero(create3Factory)
        returns (address deployedAddress)
    {
        AaveBorrowFeeCalculatorConfig memory cfg = aaveBorrowFeeCalculatorConfig;
        deployedAddress = cfg.deployedAddress;
        if (deployedAddress == address(0)) {
            ICREATE3Factory factory = ICREATE3Factory(create3Factory);
            bytes32 salt = keccak256('composable.router.aave.borrow.fee.calculator');
            bytes memory creationCode = abi.encodePacked(
                type(AaveBorrowFeeCalculator).creationCode,
                abi.encode(router, cfg.feeRate, cfg.aaveV3Provider)
            );
            deployedAddress = factory.deploy(salt, creationCode);
            console2.log('AaveBorrowFeeCalculator Deployed:', deployedAddress);
        } else {
            console2.log(
                'AaveBorrowFeeCalculator Exists. Skip deployment of AaveBorrowFeeCalculator:',
                deployedAddress
            );
        }
    }
}
