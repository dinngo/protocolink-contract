// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {console2} from 'forge-std/console2.sol';
import {DeployBase} from './DeployBase.s.sol';
import {FlashLoanCallbackAaveV2} from 'src/FlashLoanCallbackAaveV2.sol';

contract DeployFlashLoanCallbackAaveV2 is DeployBase {
    function _run(
        DeployParameters memory params
    ) internal virtual override isRouterAddressZero(params.router) returns (address deployedAddress) {
        deployedAddress = address(new FlashLoanCallbackAaveV2(params.router, params.aaveV2Provider));
        console2.log('FlashLoanCallbackAaveV2 Deployed:', deployedAddress);
    }
}
