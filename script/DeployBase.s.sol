// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from 'forge-std/Script.sol';

abstract contract DeployBase is Script {
    address internal constant UNDEPLOYED = address(0);

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

    function run() external {
        vm.startBroadcast();
        _run();
        vm.stopBroadcast();
    }

    function _run() internal virtual {}
}
