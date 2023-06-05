// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {DeployCREATE3Factory} from './DeployCREATE3Factory.s.sol';
import {DeployRouter} from './DeployRouter.s.sol';
import {DeployAaveV2FlashLoanCallback} from './DeployAaveV2FlashLoanCallback.s.sol';
import {DeployAaveV3FlashLoanCallback} from './DeployAaveV3FlashLoanCallback.s.sol';
import {DeployBalancerV2FlashLoanCallback} from './DeployBalancerV2FlashLoanCallback.s.sol';

// import {DeployMakerUtility} from './DeployMakerUtility.s.sol';
// import {DeployAaveBorrowFeeCalculator} from './DeployAaveBorrowFeeCalculator.s.sol';
// import {DeployAaveFlashLoanFeeCalculator} from './DeployAaveFlashLoanFeeCalculator.s.sol';
// import {DeployCompoundV3BorrowFeeCalculator} from './DeployCompoundV3BorrowFeeCalculator.s.sol';
// import {DeployMakerDrawFeeCalculator} from './DeployMakerDrawFeeCalculator.s.sol';
// import {DeployNativeFeeCalculator} from './DeployNativeFeeCalculator.s.sol';
// import {DeployPermit2FeeCalculator} from './DeployPermit2FeeCalculator.s.sol';
// import {DeployTransferFromFeeCalculator} from './DeployTransferFromFeeCalculator.s.sol';

contract DeployLocal is
    DeployCREATE3Factory,
    DeployRouter,
    DeployAaveV2FlashLoanCallback,
    DeployAaveV3FlashLoanCallback,
    DeployBalancerV2FlashLoanCallback
    // DeployMakerUtility,
    // DeployAaveBorrowFeeCalculator,
    // DeployAaveFlashLoanFeeCalculator,
    // DeployCompoundV3BorrowFeeCalculator,
    // DeployMakerDrawFeeCalculator,
    // DeployNativeFeeCalculator,
    // DeployPermit2FeeCalculator,
    // DeployTransferFromFeeCalculator
{
    struct DeployConfigs {
        Create3FactoryConfigs create3FactoryConfigs;
        RouterConfigs routerConfigs;
        AaveV2FlashLoanCallbackConfigs aaveV2FlashLoanCallbackConfigs;
        AaveV3FlashLoanCallbackConfigs aaveV3FlashLoanCallbackConfigs;
        BalancerV2FlashLoanCallbackConfigs balancerV2FlashLoanCallbackConfigs;
    }

    DeployConfigs public cfgs;

    function setUp() external /*override*/ {
        // init value
        Create3FactoryConfigs memory create3FactoryConfigs = Create3FactoryConfigs({
            deployedAddress: UNDEPLOYED,
            deployer: 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
        });

        RouterConfigs memory routerConfigs = RouterConfigs({
            deployedAddress: UNDEPLOYED,
            wrappedNative: 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2,
            owner: 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266,
            pauser: 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266,
            feeCollector: 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
        });

        AaveV2FlashLoanCallbackConfigs memory aaveV2FlashLoanCallbackConfigs = AaveV2FlashLoanCallbackConfigs({
            deployedAddress: UNDEPLOYED,
            aaveV2Provider: 0xB53C1a33016B2DC2fF3653530bfF1848a515c8c5
        });

        AaveV3FlashLoanCallbackConfigs memory aaveV3FlashLoanCallbackConfigs = AaveV3FlashLoanCallbackConfigs({
            deployedAddress: UNDEPLOYED,
            aaveV3Provider: 0x2f39d218133AFaB8F2B819B1066c7E434Ad94E9e
        });

        BalancerV2FlashLoanCallbackConfigs
            memory balancerV2FlashLoanCallbackConfigs = BalancerV2FlashLoanCallbackConfigs({
                deployedAddress: UNDEPLOYED,
                balancerV2Vault: 0xBA12222222228d8Ba445958a75a0704d566BF2C8
            });

        // assign value
        cfgs = DeployConfigs({
            create3FactoryConfigs: create3FactoryConfigs,
            routerConfigs: routerConfigs,
            aaveV2FlashLoanCallbackConfigs: aaveV2FlashLoanCallbackConfigs,
            aaveV3FlashLoanCallbackConfigs: aaveV3FlashLoanCallbackConfigs,
            balancerV2FlashLoanCallbackConfigs: balancerV2FlashLoanCallbackConfigs
        });
    }

    function _run() internal override {
        // create3 factory
        address deployedCreate3FactoryAddress = DeployCREATE3Factory._run(cfgs.create3FactoryConfigs);

        // router
        address deployedRouterAddress = DeployRouter._run(deployedCreate3FactoryAddress, cfgs.routerConfigs);

        // callback
        DeployAaveV2FlashLoanCallback._run(
            deployedCreate3FactoryAddress,
            deployedRouterAddress,
            cfgs.aaveV2FlashLoanCallbackConfigs
        );
        DeployAaveV3FlashLoanCallback._run(
            deployedCreate3FactoryAddress,
            deployedRouterAddress,
            cfgs.aaveV3FlashLoanCallbackConfigs
        );
        DeployBalancerV2FlashLoanCallback._run(
            deployedCreate3FactoryAddress,
            deployedRouterAddress,
            cfgs.balancerV2FlashLoanCallbackConfigs
        );

        // utility
        // DeployMakerUtility._run(params);

        // fee
        // DeployAaveBorrowFeeCalculator._run(params);
        // DeployAaveFlashLoanFeeCalculator._run(params);
        // DeployCompoundV3BorrowFeeCalculator._run(params);
        // DeployMakerDrawFeeCalculator._run(params);
        // DeployNativeFeeCalculator._run(params);
        // DeployPermit2FeeCalculator._run(params);
        // DeployTransferFromFeeCalculator._run(params);
    }
}
