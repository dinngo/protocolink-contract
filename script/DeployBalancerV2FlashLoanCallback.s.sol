// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {console2} from 'forge-std/console2.sol';
import {DeployBase} from './DeployBase.s.sol';
import {BalancerV2FlashLoanCallback} from 'src/callbacks/BalancerV2FlashLoanCallback.sol';

contract DeployBalancerV2FlashLoanCallback is DeployBase {
    function _run(
        DeployParameters memory params
    ) internal virtual override isRouterAddressZero(params.router) returns (address deployedAddress) {
        deployedAddress = address(new BalancerV2FlashLoanCallback(params.router, params.balancerV2Vault));
        console2.log('BalancerV2FlashLoanCallback Deployed:', deployedAddress);
    }
}
