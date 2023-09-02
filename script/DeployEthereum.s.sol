// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {DeployCREATE3Factory} from './DeployCREATE3Factory.s.sol';
import {DeployRouter} from './DeployRouter.s.sol';
import {DeployAaveV2FlashLoanCallback} from './callbacks/DeployAaveV2FlashLoanCallback.s.sol';
import {DeployAaveV3FlashLoanCallback} from './callbacks/DeployAaveV3FlashLoanCallback.s.sol';
import {DeployBalancerV2FlashLoanCallback} from './callbacks/DeployBalancerV2FlashLoanCallback.s.sol';

contract DeployEthereum is
    DeployCREATE3Factory,
    DeployRouter,
    DeployAaveV2FlashLoanCallback,
    DeployAaveV3FlashLoanCallback,
    DeployBalancerV2FlashLoanCallback
{
    /// @notice Set up deploy parameters and deploy contracts whose `deployedAddress` equals `UNDEPLOYED`.
    function setUp() external {
        create3FactoryConfig = Create3FactoryConfig({
            deployedAddress: 0xB9504E656866cCB985Aa3f1Af7b8B886f8485Df6,
            deployer: 0xDdbe07CB6D77e81802C55bB381546c0DA51163dd
        });

        routerConfig = RouterConfig({
            deployedAddress: UNDEPLOYED,
            wrappedNative: 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2,
            permit2: 0x000000000022D473030F116dDEE9F6B43aC78BA3,
            owner: 0xDdbe07CB6D77e81802C55bB381546c0DA51163dd,
            pauser: 0xDdbe07CB6D77e81802C55bB381546c0DA51163dd,
            feeCollector: 0xDdbe07CB6D77e81802C55bB381546c0DA51163dd
        });

        aaveV2FlashLoanCallbackConfig = AaveV2FlashLoanCallbackConfig({
            deployedAddress: UNDEPLOYED,
            aaveV2Provider: 0xB53C1a33016B2DC2fF3653530bfF1848a515c8c5,
            feeRate: 5
        });

        aaveV3FlashLoanCallbackConfig = AaveV3FlashLoanCallbackConfig({
            deployedAddress: UNDEPLOYED,
            aaveV3Provider: 0x2f39d218133AFaB8F2B819B1066c7E434Ad94E9e,
            feeRate: 5
        });

        balancerV2FlashLoanCallbackConfig = BalancerV2FlashLoanCallbackConfig({
            deployedAddress: UNDEPLOYED,
            balancerV2Vault: 0xBA12222222228d8Ba445958a75a0704d566BF2C8,
            feeRate: 5
        });
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
    }
}
