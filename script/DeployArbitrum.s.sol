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
            deployedAddress: 0x2a36F87b2Ec3dE23617907461aa3DA0cC4bc3f1f,
            deployer: 0xa3C1C91403F0026b9dd086882aDbC8Cdbc3b3cfB
        });

        routerConfig = RouterConfig({
            deployedAddress: UNDEPLOYED,
            wrappedNative: 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1,
            owner: 0xa3C1C91403F0026b9dd086882aDbC8Cdbc3b3cfB,
            pauser: 0xa3C1C91403F0026b9dd086882aDbC8Cdbc3b3cfB,
            feeCollector: 0xa3C1C91403F0026b9dd086882aDbC8Cdbc3b3cfB
        });

        aaveV3FlashLoanCallbackConfig = AaveV3FlashLoanCallbackConfig({
            deployedAddress: UNDEPLOYED,
            aaveV3Provider: 0xa97684ead0e402dC232d5A977953DF7ECBaB3CDb
        });

        balancerV2FlashLoanCallbackConfig = BalancerV2FlashLoanCallbackConfig({
            deployedAddress: UNDEPLOYED,
            balancerV2Vault: 0xBA12222222228d8Ba445958a75a0704d566BF2C8
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
