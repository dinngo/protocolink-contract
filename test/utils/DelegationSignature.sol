// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {IParam} from 'src/interfaces/IParam.sol';
import {MockDelegationHash} from '../mocks/MockDelegationHash.sol';

contract DelegationSignature is Test {
    MockDelegationHash mockDelegationHash;

    constructor() {
        mockDelegationHash = new MockDelegationHash();
    }

    function getDelegationHashedTypedData(
        IParam.DelegationDetails memory details,
        bytes32 domainSeparator
    ) internal view returns (bytes32) {
        return keccak256(abi.encodePacked('\x19\x01', domainSeparator, mockDelegationHash.hash(details)));
    }

    function getDelegationSignature(
        IParam.DelegationDetails memory details,
        bytes32 domainSeparator,
        uint256 privateKey
    ) internal view returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, getDelegationHashedTypedData(details, domainSeparator));
        return bytes.concat(r, s, bytes1(v));
    }
}
