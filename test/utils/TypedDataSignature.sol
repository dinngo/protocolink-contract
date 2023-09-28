// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {DataType} from 'src/libraries/DataType.sol';
import {MockTypedDataHash} from '../mocks/MockTypedDataHash.sol';

contract TypedDataSignature is Test {
    MockTypedDataHash mockTypedDataHash;

    constructor() {
        initialize();
    }

    // For createSelectFork
    function initialize() internal {
        mockTypedDataHash = new MockTypedDataHash();
    }

    function getHashedTypedData(
        DataType.LogicBatch memory logicBatch,
        bytes32 domainSeparator
    ) internal view returns (bytes32) {
        return keccak256(abi.encodePacked('\x19\x01', domainSeparator, mockTypedDataHash.hash(logicBatch)));
    }

    function getHashedTypedData(
        DataType.ExecutionDetails memory details,
        bytes32 domainSeparator
    ) internal view returns (bytes32) {
        return keccak256(abi.encodePacked('\x19\x01', domainSeparator, mockTypedDataHash.hash(details)));
    }

    function getHashedTypedData(
        DataType.ExecutionBatchDetails memory details,
        bytes32 domainSeparator
    ) internal view returns (bytes32) {
        return keccak256(abi.encodePacked('\x19\x01', domainSeparator, mockTypedDataHash.hash(details)));
    }

    function getHashedTypedData(
        DataType.DelegationDetails memory details,
        bytes32 domainSeparator
    ) internal view returns (bytes32) {
        return keccak256(abi.encodePacked('\x19\x01', domainSeparator, mockTypedDataHash.hash(details)));
    }

    function getTypedDataSignature(
        DataType.LogicBatch memory logicBatch,
        bytes32 domainSeparator,
        uint256 privateKey
    ) internal view returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, getHashedTypedData(logicBatch, domainSeparator));
        return bytes.concat(r, s, bytes1(v));
    }

    function getTypedDataSignature(
        DataType.ExecutionDetails memory details,
        bytes32 domainSeparator,
        uint256 privateKey
    ) internal view returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, getHashedTypedData(details, domainSeparator));
        return bytes.concat(r, s, bytes1(v));
    }

    function getTypedDataSignature(
        DataType.ExecutionBatchDetails memory details,
        bytes32 domainSeparator,
        uint256 privateKey
    ) internal view returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, getHashedTypedData(details, domainSeparator));
        return bytes.concat(r, s, bytes1(v));
    }

    function getTypedDataSignature(
        DataType.DelegationDetails memory details,
        bytes32 domainSeparator,
        uint256 privateKey
    ) internal view returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, getHashedTypedData(details, domainSeparator));
        return bytes.concat(r, s, bytes1(v));
    }
}
