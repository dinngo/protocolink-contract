// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import {Address} from 'lib/openzeppelin-contracts/contracts/utils/Address.sol';

interface ICallback {
    function callback(bytes calldata data_) external;
}

contract MockCallback is ICallback {
    using Address for address;

    function callback(bytes calldata data_) external {
        msg.sender.functionCall(data_);
    }
}
