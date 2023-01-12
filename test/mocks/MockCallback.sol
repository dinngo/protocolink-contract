// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;
import {Address} from 'openzeppelin-contracts/contracts/utils/Address.sol';
import {IRouter} from '../../src/interfaces/IRouter.sol';

interface ICallback {
    function callback(bytes calldata data_) external;
}

contract MockCallback is ICallback {
    using Address for address;

    function callback(bytes calldata data_) external {
        msg.sender.functionCall(data_);
    }
}
