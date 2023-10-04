// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from 'forge-std/Script.sol';

abstract contract DeployBaseScript is Script {
    address public constant UNDEPLOYED = address(0);

    error InvalidRouterAddress();
    error InvalidCREATE3FactoryAddress();

    modifier isRouterAddressZero(address router) {
        if (router == UNDEPLOYED) revert InvalidRouterAddress();
        _;
    }

    modifier isCREATE3FactoryAddressZero(address factory) {
        if (factory == UNDEPLOYED) revert InvalidCREATE3FactoryAddress();
        _;
    }

    function run() external {
        vm.startBroadcast();
        _run();
        vm.stopBroadcast();
    }

    function _run() internal virtual {}
}
