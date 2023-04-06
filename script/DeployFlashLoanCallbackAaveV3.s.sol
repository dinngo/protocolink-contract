// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'forge-std/console2.sol';
import {DeployBase} from './DeployBase.s.sol';
import {FlashLoanCallbackAaveV3} from 'src/FlashLoanCallbackAaveV3.sol';

contract DeployFlashLoanCallbackAaveV3 is DeployBase {
    function _run(DeployParameters memory params) internal virtual override returns (address deployedAddress) {
        deployedAddress = address(new FlashLoanCallbackAaveV3(params.router, params.aaveV3Provider));
        console2.log('FlashLoanCallbackAaveV3 Deployed:', deployedAddress);
    }
}
