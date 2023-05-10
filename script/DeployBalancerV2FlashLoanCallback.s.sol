// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {console2} from 'forge-std/console2.sol';
import {DeployBase} from './DeployBase.s.sol';
import {BalancerV2FlashLoanCallback} from 'src/callbacks/BalancerV2FlashLoanCallback.sol';
import {ICREATE3Factory} from 'create3-factory/ICREATE3Factory.sol';

contract DeployBalancerV2FlashLoanCallback is DeployBase {
    function _run(
        DeployParameters memory params
    )
        internal
        virtual
        override
        isRouterAddressZero(params.router)
        isCREATE3FactoryAddressZero(params.create3Factory)
        returns (address deployedAddress)
    {
        ICREATE3Factory factory = ICREATE3Factory(params.create3Factory);
        bytes32 salt = keccak256('balancer.v2.flash.loan.callback');
        bytes memory creationCode = abi.encodePacked(
            type(BalancerV2FlashLoanCallback).creationCode,
            abi.encode(params.router, params.balancerV2Vault)
        );
        deployedAddress = factory.deploy(salt, creationCode);
        console2.log('BalancerV2FlashLoanCallback Deployed:', deployedAddress);
    }
}
