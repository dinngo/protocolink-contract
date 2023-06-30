// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IParam} from 'src/interfaces/IParam.sol';
import {DelegationHash} from 'src/libraries/DelegationHash.sol';

contract MockDelegationHash {
    using DelegationHash for IParam.DelegationDetails;

    function hash(IParam.DelegationDetails calldata details) external pure returns (bytes32) {
        return details._hash();
    }
}
