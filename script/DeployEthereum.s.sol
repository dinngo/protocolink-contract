// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {DeployRouter} from './DeployRouter.s.sol';
import {DeployAaveV2FlashLoanCallback} from './callbacks/DeployAaveV2FlashLoanCallback.s.sol';
import {DeployAaveV3FlashLoanCallback} from './callbacks/DeployAaveV3FlashLoanCallback.s.sol';
import {DeployBalancerV2FlashLoanCallback} from './callbacks/DeployBalancerV2FlashLoanCallback.s.sol';
import {DeployRadiantV2FlashLoanCallback} from './callbacks/DeployRadiantV2FlashLoanCallback.s.sol';
import {DeploySparkFlashLoanCallback} from './callbacks/DeploySparkFlashLoanCallback.s.sol';

contract DeployEthereum is
    DeployRouter,
    DeployAaveV2FlashLoanCallback,
    DeployAaveV3FlashLoanCallback,
    DeployBalancerV2FlashLoanCallback,
    DeployRadiantV2FlashLoanCallback,
    DeploySparkFlashLoanCallback
{
    address public constant DEPLOYER = 0xBcb909975715DC8fDe643EE44b89e3FD6A35A259;
    address public constant OWNER = 0xA7248F4B85FB6261c314d08e7938285d1d86cd61;
    address public constant PAUSER = 0x4d2D634Bf4b271f74bBf3A30f50497EC3D90024e;
    address public constant DEFAULT_COLLECTOR = 0x6304EB1B1eC2135a64a90bA901B12Cf769657579;
    address public constant CREATE3_FACTORY = 0xFa3e9a110E6975ec868E9ed72ac6034eE4255B64;

    /// @notice Set up deploy parameters and deploy contracts whose `deployedAddress` equals `UNDEPLOYED`.
    function setUp() external {
        routerConfig = RouterConfig({
            deployedAddress: 0xDec80E988F4baF43be69c13711453013c212feA8,
            wrappedNative: 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2,
            permit2: 0x000000000022D473030F116dDEE9F6B43aC78BA3,
            deployer: DEPLOYER,
            owner: OWNER,
            pauser: PAUSER,
            defaultCollector: DEFAULT_COLLECTOR,
            signer: 0xffFf5a88840FF1f168E163ACD771DFb292164cFA,
            feeRate: 20
        });

        aaveV2FlashLoanCallbackConfig = AaveV2FlashLoanCallbackConfig({
            deployedAddress: 0x727c55092C7196d65594A8e4F39ae8dC0cB39173,
            aaveV2Provider: 0xB53C1a33016B2DC2fF3653530bfF1848a515c8c5,
            feeRate: 5
        });

        aaveV3FlashLoanCallbackConfig = AaveV3FlashLoanCallbackConfig({
            deployedAddress: 0x6f81cf774052D03873b32944a036BF0647bFB5bF,
            aaveV3Provider: 0x2f39d218133AFaB8F2B819B1066c7E434Ad94E9e,
            feeRate: 5
        });

        balancerV2FlashLoanCallbackConfig = BalancerV2FlashLoanCallbackConfig({
            deployedAddress: 0xA15B9C132F29e91D99b51E3080020eF7c7F5E350,
            balancerV2Vault: 0xBA12222222228d8Ba445958a75a0704d566BF2C8,
            feeRate: 5
        });

        radiantV2FlashLoanCallbackConfig = RadiantV2FlashLoanCallbackConfig({
            deployedAddress: 0x6bfCE075A1c4F0fD4067A401dA8f159354e1a916,
            radiantV2Provider: 0x70e507f1d20AeC229F435cd1EcaC6A7200119B9F,
            feeRate: 5
        });

        sparkFlashLoanCallbackConfig = SparkFlashLoanCallbackConfig({
            deployedAddress: 0x9174a45468d055Cc2Fa18e708E8CeACD46050359,
            sparkProvider: 0x02C3eA4e34C0cBd694D2adFa2c690EECbC1793eE,
            feeRate: 5
        });
    }

    function _run() internal override {
        // router
        address deployedRouterAddress = _deployRouter(CREATE3_FACTORY);

        // callback
        _deployAaveV2FlashLoanCallback(CREATE3_FACTORY, deployedRouterAddress);
        _deployAaveV3FlashLoanCallback(CREATE3_FACTORY, deployedRouterAddress);
        _deployBalancerV2FlashLoanCallback(CREATE3_FACTORY, deployedRouterAddress);
        _deployRadiantV2FlashLoanCallback(CREATE3_FACTORY, deployedRouterAddress);
        _deploySparkFlashLoanCallback(CREATE3_FACTORY, deployedRouterAddress);
    }
}
