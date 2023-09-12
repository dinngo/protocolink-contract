// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {DeployCREATE3Factory} from './DeployCREATE3Factory.s.sol';
import {DeployRouter} from './DeployRouter.s.sol';
import {DeployAaveV3FlashLoanCallback} from './callbacks/DeployAaveV3FlashLoanCallback.s.sol';
import {DeployBalancerV2FlashLoanCallback} from './callbacks/DeployBalancerV2FlashLoanCallback.s.sol';
import {DeployRadiantV2FlashLoanCallback} from './callbacks/DeployRadiantV2FlashLoanCallback.s.sol';

contract DeployArbitrum is
    DeployCREATE3Factory,
    DeployRouter,
    DeployAaveV3FlashLoanCallback,
    DeployBalancerV2FlashLoanCallback,
    DeployRadiantV2FlashLoanCallback
{
    address public constant DEPLOYER = 0xDdbe07CB6D77e81802C55bB381546c0DA51163dd;

    /// @notice Set up deploy parameters and deploy contracts whose `deployedAddress` equals `UNDEPLOYED`.
    function setUp() external {
        create3FactoryConfig = Create3FactoryConfig({
            deployedAddress: 0xB9504E656866cCB985Aa3f1Af7b8B886f8485Df6,
            deployer: DEPLOYER
        });

        routerConfig = RouterConfig({
            deployedAddress: 0x4E744c3E6973D34ee130B7E668Abc14CD49ca16e,
            wrappedNative: 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1,
            permit2: 0x000000000022D473030F116dDEE9F6B43aC78BA3,
            deployer: DEPLOYER,
            owner: DEPLOYER,
            pauser: DEPLOYER,
            defaultCollector: DEPLOYER,
            signer: 0xffFf5a88840FF1f168E163ACD771DFb292164cFA,
            feeRate: 20
        });

        aaveV3FlashLoanCallbackConfig = AaveV3FlashLoanCallbackConfig({
            deployedAddress: 0x8f2Ed9cE5DF73210c5Fa21d0cFDFF98bB1027a1F,
            aaveV3Provider: 0xa97684ead0e402dC232d5A977953DF7ECBaB3CDb,
            feeRate: 5
        });

        balancerV2FlashLoanCallbackConfig = BalancerV2FlashLoanCallbackConfig({
            deployedAddress: 0x13431cd779FD770D55701B96F2675dFF63BDD756,
            balancerV2Vault: 0xBA12222222228d8Ba445958a75a0704d566BF2C8,
            feeRate: 5
        });

        radiantV2FlashLoanCallbackConfig = RadiantV2FlashLoanCallbackConfig({
            deployedAddress: UNDEPLOYED,
            radiantV2Provider: 0x091d52CacE1edc5527C99cDCFA6937C1635330E4,
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
        _deployRadiantV2FlashLoanCallback(deployedCreate3FactoryAddress, deployedRouterAddress);
    }
}
