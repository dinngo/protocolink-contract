// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {console2} from 'forge-std/console2.sol';
import {DeployBase} from './DeployBase.s.sol';
import {FlashLoanCallbackBalancerV2} from 'src/FlashLoanCallbackBalancerV2.sol';

contract DeployFlashLoanCallbackBalancerV2 is DeployBase {
    function _run(
        DeployParameters memory params
    ) internal virtual override isRouterAddressZero(params.router) returns (address deployedAddress) {
        deployedAddress = address(new FlashLoanCallbackBalancerV2(params.router, params.balancerV2Vault));
        console2.log('FlashLoanCallbackBalancerV2 Deployed:', deployedAddress);
    }
}
