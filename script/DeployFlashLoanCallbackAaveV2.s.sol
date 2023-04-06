// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'forge-std/console2.sol';
import {DeployBase} from './DeployBase.s.sol';
import {FlashLoanCallbackAaveV2} from 'src/FlashLoanCallbackAaveV2.sol';

contract DeployFlashLoanCallbackAaveV2 is DeployBase {
    function _run(DeployParameters memory params) internal virtual override returns (address) {
        address callbackAaveV2 = address(new FlashLoanCallbackAaveV2(params.router, params.aaveV2Provider));
        console2.log('FlashLoanCallbackAaveV2 Deployed:', callbackAaveV2);
        return callbackAaveV2;
    }
}
