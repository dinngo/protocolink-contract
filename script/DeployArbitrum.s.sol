// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {DeployCREATE3Factory} from './DeployCREATE3Factory.s.sol';
import {DeployRouter} from './DeployRouter.s.sol';
import {DeployAaveV3FlashLoanCallback} from './callbacks/DeployAaveV3FlashLoanCallback.s.sol';
import {DeployBalancerV2FlashLoanCallback} from './callbacks/DeployBalancerV2FlashLoanCallback.s.sol';

contract DeployArbitrum is
    DeployCREATE3Factory,
    DeployRouter,
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
            wrappedNative: 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1,
            permit2: 0x000000000022D473030F116dDEE9F6B43aC78BA3,
            owner: 0xDdbe07CB6D77e81802C55bB381546c0DA51163dd,
            pauser: 0xDdbe07CB6D77e81802C55bB381546c0DA51163dd,
            feeCollector: 0xDdbe07CB6D77e81802C55bB381546c0DA51163dd
        });

        aaveV3FlashLoanCallbackConfig = AaveV3FlashLoanCallbackConfig({
            deployedAddress: UNDEPLOYED,
            aaveV3Provider: 0xa97684ead0e402dC232d5A977953DF7ECBaB3CDb,
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
        _deployAaveV3FlashLoanCallback(deployedCreate3FactoryAddress, deployedRouterAddress);
        _deployBalancerV2FlashLoanCallback(deployedCreate3FactoryAddress, deployedRouterAddress);
    }
}
