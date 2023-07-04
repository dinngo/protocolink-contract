// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {DeployCREATE3Factory} from './DeployCREATE3Factory.s.sol';
import {DeployRouter} from './DeployRouter.s.sol';
import {DeployAaveV2FlashLoanCallback} from './callbacks/DeployAaveV2FlashLoanCallback.s.sol';
import {DeployAaveV3FlashLoanCallback} from './callbacks/DeployAaveV3FlashLoanCallback.s.sol';
import {DeployBalancerV2FlashLoanCallback} from './callbacks/DeployBalancerV2FlashLoanCallback.s.sol';
import {DeployMakerUtility} from './utilities/DeployMakerUtility.s.sol';
import {DeployAaveBorrowFeeCalculator} from './fees/DeployAaveBorrowFeeCalculator.s.sol';
import {DeployAaveFlashLoanFeeCalculator} from './fees/DeployAaveFlashLoanFeeCalculator.s.sol';
import {DeployCompoundV3BorrowFeeCalculator} from './fees/DeployCompoundV3BorrowFeeCalculator.s.sol';
import {DeployMakerDrawFeeCalculator} from './fees/DeployMakerDrawFeeCalculator.s.sol';
import {DeployNativeFeeCalculator} from './fees/DeployNativeFeeCalculator.s.sol';
import {DeployPermit2FeeCalculator} from './fees/DeployPermit2FeeCalculator.s.sol';
import {DeployTransferFromFeeCalculator} from './fees/DeployTransferFromFeeCalculator.s.sol';

contract DeployLocal is
    DeployCREATE3Factory,
    DeployRouter,
    DeployAaveV2FlashLoanCallback,
    DeployAaveV3FlashLoanCallback,
    DeployBalancerV2FlashLoanCallback,
    DeployMakerUtility,
    DeployAaveBorrowFeeCalculator,
    DeployAaveFlashLoanFeeCalculator,
    DeployCompoundV3BorrowFeeCalculator,
    DeployMakerDrawFeeCalculator,
    DeployNativeFeeCalculator,
    DeployPermit2FeeCalculator,
    DeployTransferFromFeeCalculator
{
    /// @notice Set up deploy parameters and deploy contracts whose `deployedAddress` equals `UNDEPLOYED`.
    function setUp() external {
        create3FactoryConfig = Create3FactoryConfig({
            deployedAddress: UNDEPLOYED,
            deployer: 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
        });

        routerConfig = RouterConfig({
            deployedAddress: UNDEPLOYED,
            wrappedNative: 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2,
            owner: 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266,
            pauser: 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266,
            feeCollector: 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
        });

        aaveV2FlashLoanCallbackConfig = AaveV2FlashLoanCallbackConfig({
            deployedAddress: UNDEPLOYED,
            aaveV2Provider: 0xB53C1a33016B2DC2fF3653530bfF1848a515c8c5
        });

        aaveV3FlashLoanCallbackConfig = AaveV3FlashLoanCallbackConfig({
            deployedAddress: UNDEPLOYED,
            aaveV3Provider: 0x2f39d218133AFaB8F2B819B1066c7E434Ad94E9e
        });

        balancerV2FlashLoanCallbackConfig = BalancerV2FlashLoanCallbackConfig({
            deployedAddress: UNDEPLOYED,
            balancerV2Vault: 0xBA12222222228d8Ba445958a75a0704d566BF2C8
        });

        makerUtilityConfig = MakerUtilityConfig({
            deployedAddress: UNDEPLOYED,
            proxyRegistry: 0x4678f0a6958e4D2Bc4F1BAF7Bc52E8F3564f3fE4,
            cdpManager: 0x5ef30b9986345249bc32d8928B7ee64DE9435E39,
            proxyActions: 0x82ecD135Dce65Fbc6DbdD0e4237E0AF93FFD5038,
            daiToken: 0x6B175474E89094C44Da98b954EedeAC495271d0F,
            jug: 0x19c0976f590D67707E62397C87829d896Dc0f1F1
        });

        aaveBorrowFeeCalculatorConfig = AaveBorrowFeeCalculatorConfig({
            deployedAddress: UNDEPLOYED,
            feeRate: 0,
            aaveV3Provider: 0x2f39d218133AFaB8F2B819B1066c7E434Ad94E9e
        });

        aaveFlashLoanFeeCalculatorConfig = AaveFlashLoanFeeCalculatorConfig({
            deployedAddress: UNDEPLOYED,
            feeRate: 0,
            aaveV3Provider: 0x2f39d218133AFaB8F2B819B1066c7E434Ad94E9e
        });

        compoundV3BorrowFeeCalculatorConfig = CompoundV3BorrowFeeCalculatorConfig({
            deployedAddress: UNDEPLOYED,
            feeRate: 0
        });
        makerDrawFeeCalculatorConfig = MakerDrawFeeCalculatorConfig({
            deployedAddress: UNDEPLOYED,
            feeRate: 0,
            daiToken: 0x6B175474E89094C44Da98b954EedeAC495271d0F
        });
        nativeFeeCalculatorConfig = NativeFeeCalculatorConfig({deployedAddress: UNDEPLOYED, feeRate: 0});
        permit2FeeCalculatorConfig = Permit2FeeCalculatorConfig({deployedAddress: UNDEPLOYED, feeRate: 0});
        transferFromFeeCalculatorConfig = TransferFromFeeCalculatorConfig({deployedAddress: UNDEPLOYED, feeRate: 0});
    }

    function _run() internal override {
        // create3 factory
        address deployedCreate3FactoryAddress = _deployCreate3Factory();

        // router
        address deployedRouterAddress = _deployRouter(deployedCreate3FactoryAddress);

        // callback
        _deployAaveV2FlashLoanCallback(deployedCreate3FactoryAddress, deployedRouterAddress);
        _deployAaveV3FlashLoanCallback(deployedCreate3FactoryAddress, deployedRouterAddress);
        _deployBalancerV2FlashLoanCallback(deployedCreate3FactoryAddress, deployedRouterAddress);

        // utility
        _deployMakerUtility(deployedCreate3FactoryAddress, deployedRouterAddress);

        // fee
        _deployAaveBorrowFeeCalculator(deployedCreate3FactoryAddress, deployedRouterAddress);
        _deployAaveFlashLoanFeeCalculator(deployedCreate3FactoryAddress, deployedRouterAddress);
        _deployCompoundV3BorrowFeeCalculator(deployedCreate3FactoryAddress, deployedRouterAddress);
        _deployMakerDrawFeeCalculator(deployedCreate3FactoryAddress, deployedRouterAddress);
        _deployNativeFeeCalculator(deployedCreate3FactoryAddress, deployedRouterAddress);
        _deployPermit2FeeCalculator(deployedCreate3FactoryAddress, deployedRouterAddress);
        _deployTransferFromFeeCalculator(deployedCreate3FactoryAddress, deployedRouterAddress);
    }
}
