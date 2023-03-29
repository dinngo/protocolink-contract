// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {SignatureChecker} from 'openzeppelin-contracts/contracts/utils/cryptography/SignatureChecker.sol';
import {IParam} from 'src/interfaces/IParam.sol';
import {LogicSignature} from './utils/LogicSignature.sol';

contract LogicTypehash is Test, LogicSignature {
    using SignatureChecker for address;

    uint256 public constant PRIVATE_KEY = 0x290441b34d375a426eb23e32d27296fe944c734f58b21a1d2736191dfaafce90;
    address public constant SIGNER = 0x8C9dB529b394C8E1a9Fa34AE90F228202ca40712;

    uint256 public chainId;
    address public verifyingContract;

    function setUp() public {
        verifyingContract = 0x712BcCD6b7f8f5c3faE0418AC917f8929b371804;
        chainId = 1;
    }

    function _buildDomainSeparator() private view returns (bytes32) {
        bytes32 typeHash = keccak256(
            'EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)'
        );
        bytes32 nameHash = keccak256('Composable Router');
        bytes32 versionHash = keccak256('1');
        return keccak256(abi.encode(typeHash, nameHash, versionHash, chainId, verifyingContract));
    }

    function testLogicBatchTypehash() external {
        // Signed a logicBatch using metamask to obtain an external sig
        bytes32 r = 0xb2155e489c35b747610457550a11899e775bc4a1681260baaffc92b30c8bc892;
        bytes32 s = 0x492c85b3613440c640debdc2cbf6ff960de6a363e238f42e0b7612229f2cc57b;
        uint8 v = 0x1c;
        bytes memory sig = bytes.concat(r, s, bytes1(v));

        // Create the logicBatch with the same parameters as above
        IParam.Input[] memory inputs = new IParam.Input[](2);
        inputs[0] = IParam.Input(
            address(1), // token
            type(uint256).max, // amountBps
            1 // amountOrOffset
        );
        inputs[1] = IParam.Input(
            address(2), // token
            10000, // amountBps
            0x20 // amountOrOffset
        );
        IParam.Logic[] memory logics = new IParam.Logic[](2);
        logics[0] = IParam.Logic(
            address(3), // to
            '0123456789abcdef',
            inputs,
            IParam.WrapMode.WRAP_BEFORE,
            address(4), // approveTo
            address(5) // callback
        );
        logics[1] = logics[0]; // Duplicate logic
        IParam.Fee[] memory fees = new IParam.Fee[](2);
        fees[0] = IParam.Fee(address(6), 1, bytes32(abi.encodePacked('metadata')));
        fees[1] = fees[0]; // Duplicate fee
        uint256 deadline = 1704067200;
        IParam.LogicBatch memory logicBatch = IParam.LogicBatch(logics, fees, deadline);

        // Verify the locally generated signature using the private key is the same as the external sig
        assertEq(getLogicBatchSignature(logicBatch, _buildDomainSeparator(), PRIVATE_KEY), sig);

        // Verify the signer can be recovered using the external sig
        bytes32 hashedTypedData = getLogicBatchHashedTypedData(logicBatch, _buildDomainSeparator());
        assertEq(SIGNER.isValidSignatureNow(hashedTypedData, sig), true);
    }
}
