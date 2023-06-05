// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// import {stdJson} from 'forge-std/StdJson.sol';
import {Script} from 'forge-std/Script.sol';

abstract contract DeployBase is Script {
    address internal constant UNDEPLOYED = address(0);

    struct Create3FactoryConfigs {
        address deployedAddress;
        // deploy params
        address deployer;
    }

    struct RouterConfigs {
        address deployedAddress;
        // deploy params
        address wrappedNative;
        address owner;
        address pauser;
        address feeCollector;
    }

    struct AaveV2FlashLoanCallbackConfigs {
        address deployedAddress;
        // deploy params
        // address router; use value from RouterConfigs.deployedAddress
        address aaveV2Provider;
    }

    struct AaveV3FlashLoanCallbackConfigs {
        address deployedAddress;
        // deploy params
        // address router; use value from RouterConfigs.deployedAddress
        address aaveV3Provider;
    }

    struct BalancerV2FlashLoanCallbackConfigs {
        address deployedAddress;
        // deploy params
        // address router; use value from RouterConfigs.deployedAddress
        address balancerV2Vault;
    }

    error InvalidRouterAddress();
    error InvalidCREATE3FactoryAddress();

    modifier isRouterAddressZero(address router) {
        if (router == address(0)) revert InvalidRouterAddress();
        _;
    }

    modifier isCREATE3FactoryAddressZero(address factory) {
        if (factory == address(0)) revert InvalidCREATE3FactoryAddress();
        _;
    }

    // function setUp() external virtual {}

    function run() external {
        vm.startBroadcast();
        _run();
        vm.stopBroadcast();
    }

    function _run() internal virtual {}
}
