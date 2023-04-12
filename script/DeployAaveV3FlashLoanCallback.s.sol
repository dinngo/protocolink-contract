// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {console2} from 'forge-std/console2.sol';
import {DeployBase} from './DeployBase.s.sol';
import {AaveV3FlashLoanCallback} from 'src/callbacks/AaveV3FlashLoanCallback.sol';

contract DeployAaveV3FlashLoanCallback is DeployBase {
    function _run(
        DeployParameters memory params
    ) internal virtual override isRouterAddressZero(params.router) returns (address deployedAddress) {
        deployedAddress = address(new AaveV3FlashLoanCallback(params.router, params.aaveV3Provider));
        console2.log('AaveV3FlashLoanCallback Deployed:', deployedAddress);
    }
}
