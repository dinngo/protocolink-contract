// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {console2} from 'forge-std/console2.sol';
import {DeployBase} from './DeployBase.s.sol';
import {AaveV2FlashLoanCallback} from 'src/callbacks/AaveV2FlashLoanCallback.sol';

contract DeployAaveV2FlashLoanCallback is DeployBase {
    function _run(
        DeployParameters memory params
    ) internal virtual override isRouterAddressZero(params.router) returns (address deployedAddress) {
        deployedAddress = address(new AaveV2FlashLoanCallback(params.router, params.aaveV2Provider));
        console2.log('AaveV2FlashLoanCallback Deployed:', deployedAddress);
    }
}
