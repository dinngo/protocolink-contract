// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {DeployRouter} from './DeployRouter.s.sol';
import {DeployAaveV3FlashLoanCallback} from './callbacks/DeployAaveV3FlashLoanCallback.s.sol';
import {DeployBalancerV2FlashLoanCallback} from './callbacks/DeployBalancerV2FlashLoanCallback.s.sol';
import {DeploySparkFlashLoanCallback} from './callbacks/DeploySparkFlashLoanCallback.s.sol';

contract DeployGnosis is
    DeployRouter,
    DeployAaveV3FlashLoanCallback,
    DeployBalancerV2FlashLoanCallback,
    DeploySparkFlashLoanCallback
{
    address public constant DEPLOYER = 0xBcb909975715DC8fDe643EE44b89e3FD6A35A259;
    address public constant OWNER = 0x13D09F09EF1f201D18d6b2fD4578D8feBf1c774d;
    address public constant PAUSER = 0x23535221bC116F3b8a17b768806C5d7Cd36b020D;
    address public constant DEFAULT_COLLECTOR = 0x4207b828b673EDC01d7f0020E8e8A99D8b454136;
    address public constant CREATE3_FACTORY = 0xFa3e9a110E6975ec868E9ed72ac6034eE4255B64;

    /// @notice Set up deploy parameters and deploy contracts whose `deployedAddress` equals `UNDEPLOYED`.
    function setUp() external {
        routerConfig = RouterConfig({
            deployedAddress: 0xDec80E988F4baF43be69c13711453013c212feA8,
            wrappedNative: 0xe91D153E0b41518A2Ce8Dd3D7944Fa863463a97d,
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
            aaveV3Provider: 0x36616cf17557639614c1cdDb356b1B83fc0B2132,
            feeRate: 5
        });

        balancerV2FlashLoanCallbackConfig = BalancerV2FlashLoanCallbackConfig({
            deployedAddress: 0xA15B9C132F29e91D99b51E3080020eF7c7F5E350,
            balancerV2Vault: 0xBA12222222228d8Ba445958a75a0704d566BF2C8,
            feeRate: 5
        });

        sparkFlashLoanCallbackConfig = SparkFlashLoanCallbackConfig({
            deployedAddress: 0x9174a45468d055Cc2Fa18e708E8CeACD46050359,
            sparkProvider: 0xA98DaCB3fC964A6A0d2ce3B77294241585EAbA6d,
            feeRate: 5
        });
    }

    function _run() internal override {
        // router
        address deployedRouterAddress = _deployRouter(CREATE3_FACTORY);

        // callback
        _deployAaveV3FlashLoanCallback(CREATE3_FACTORY, deployedRouterAddress);
        _deployBalancerV2FlashLoanCallback(CREATE3_FACTORY, deployedRouterAddress);
        _deploySparkFlashLoanCallback(CREATE3_FACTORY, deployedRouterAddress);
    }
}
