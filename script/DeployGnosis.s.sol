// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {DeployCREATE3Factory} from './DeployCREATE3Factory.s.sol';
import {DeployRouter} from './DeployRouter.s.sol';
import {DeployAaveV3FlashLoanCallback} from './callbacks/DeployAaveV3FlashLoanCallback.s.sol';
import {DeployBalancerV2FlashLoanCallback} from './callbacks/DeployBalancerV2FlashLoanCallback.s.sol';
import {DeploySparkFlashLoanCallback} from './callbacks/DeploySparkFlashLoanCallback.s.sol';

contract DeployGnosis is
    DeployCREATE3Factory,
    DeployRouter,
    DeployAaveV3FlashLoanCallback,
    DeployBalancerV2FlashLoanCallback,
    DeploySparkFlashLoanCallback
{
    address public constant DEPLOYER = 0xDdbe07CB6D77e81802C55bB381546c0DA51163dd;

    /// @notice Set up deploy parameters and deploy contracts whose `deployedAddress` equals `UNDEPLOYED`.
    function setUp() external {
        create3FactoryConfig = Create3FactoryConfig({
            deployedAddress: 0xB9504E656866cCB985Aa3f1Af7b8B886f8485Df6,
            deployer: DEPLOYER
        });

        routerConfig = RouterConfig({
            deployedAddress: UNDEPLOYED,
            wrappedNative: 0xe91D153E0b41518A2Ce8Dd3D7944Fa863463a97d,
            permit2: 0x000000000022D473030F116dDEE9F6B43aC78BA3,
            deployer: DEPLOYER,
            owner: DEPLOYER,
            pauser: DEPLOYER,
            defaultCollector: DEPLOYER,
            signer: 0xffFf5a88840FF1f168E163ACD771DFb292164cFA,
            feeRate: 20
        });

        aaveV3FlashLoanCallbackConfig = AaveV3FlashLoanCallbackConfig({
            deployedAddress: UNDEPLOYED,
            aaveV3Provider: 0x36616cf17557639614c1cdDb356b1B83fc0B2132,
            feeRate: 5
        });

        balancerV2FlashLoanCallbackConfig = BalancerV2FlashLoanCallbackConfig({
            deployedAddress: UNDEPLOYED,
            balancerV2Vault: 0xBA12222222228d8Ba445958a75a0704d566BF2C8,
            feeRate: 5
        });

        sparkFlashLoanCallbackConfig = SparkFlashLoanCallbackConfig({
            deployedAddress: UNDEPLOYED,
            sparkProvider: 0xA98DaCB3fC964A6A0d2ce3B77294241585EAbA6d,
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
        _deploySparkFlashLoanCallback(deployedCreate3FactoryAddress, deployedRouterAddress);
    }
}
