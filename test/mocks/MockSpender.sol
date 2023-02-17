// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import {Address} from 'openzeppelin-contracts/contracts/utils/Address.sol';
import {IRouter} from '../../src/interfaces/IRouter.sol';

contract MockSpender {
    using Address for address;

    address public immutable router;

    constructor(address router_) {
        router = router_;
    }

    fallback() external {
        if (msg.sender != router) revert();
        (bool success, ) = (msg.sender).staticcall(abi.encodeWithSelector(IRouter.user.selector));
        require(success);
    }
}
