// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {DeployRouter} from './DeployRouter.s.sol';
import {DeployAaveV3FlashLoanCallback} from './callbacks/DeployAaveV3FlashLoanCallback.s.sol';
import {DeployBalancerV2FlashLoanCallback} from './callbacks/DeployBalancerV2FlashLoanCallback.s.sol';
import {DeployRadiantV2FlashLoanCallback} from './callbacks/DeployRadiantV2FlashLoanCallback.s.sol';

contract DeployArbitrum is
    DeployRouter,
    DeployAaveV3FlashLoanCallback,
    DeployBalancerV2FlashLoanCallback,
    DeployRadiantV2FlashLoanCallback
{
    address public constant DEPLOYER = 0xBcb909975715DC8fDe643EE44b89e3FD6A35A259;
    address public constant OWNER = 0x64585922a9703d9EdE7d353a6522eb2970f75066;
    address public constant PAUSER = 0x660Cc6D82925Cc804aC4EBD1d5870Fa32C9aBDb8;
    address public constant DEFAULT_COLLECTOR = 0x3EBe4dfaF95cd320BF34633B3BDf773FbE732E63;
    address public constant CREATE3_FACTORY = 0xFa3e9a110E6975ec868E9ed72ac6034eE4255B64;

    /// @notice Set up deploy parameters and deploy contracts whose `deployedAddress` equals `UNDEPLOYED`.
    function setUp() external {
        routerConfig = RouterConfig({
            deployedAddress: 0xDec80E988F4baF43be69c13711453013c212feA8,
            wrappedNative: 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1,
            permit2: 0x000000000022D473030F116dDEE9F6B43aC78BA3,
            deployer: DEPLOYER,
            owner: OWNER,
            pauser: PAUSER,
            defaultCollector: DEFAULT_COLLECTOR,
            signer: 0xffFf5a88840FF1f168E163ACD771DFb292164cFA,
            feeRate: 20
        });

        aaveV3FlashLoanCallbackConfig = AaveV3FlashLoanCallbackConfig({
            deployedAddress: 0x6f81cf774052D03873b32944a036BF0647bFB5bF,
            aaveV3Provider: 0xa97684ead0e402dC232d5A977953DF7ECBaB3CDb,
            feeRate: 5
        });

        balancerV2FlashLoanCallbackConfig = BalancerV2FlashLoanCallbackConfig({
            deployedAddress: 0xA15B9C132F29e91D99b51E3080020eF7c7F5E350,
            balancerV2Vault: 0xBA12222222228d8Ba445958a75a0704d566BF2C8,
            feeRate: 5
        });

        radiantV2FlashLoanCallbackConfig = RadiantV2FlashLoanCallbackConfig({
            deployedAddress: 0x6bfCE075A1c4F0fD4067A401dA8f159354e1a916,
            radiantV2Provider: 0x091d52CacE1edc5527C99cDCFA6937C1635330E4,
            feeRate: 5
        });
    }

    function _run() internal override {
        // router
        address deployedRouterAddress = _deployRouter(CREATE3_FACTORY);

        // callback
        _deployAaveV3FlashLoanCallback(CREATE3_FACTORY, deployedRouterAddress);
        _deployBalancerV2FlashLoanCallback(CREATE3_FACTORY, deployedRouterAddress);
        _deployRadiantV2FlashLoanCallback(CREATE3_FACTORY, deployedRouterAddress);
    }
}
