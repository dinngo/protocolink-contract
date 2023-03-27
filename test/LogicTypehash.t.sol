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
        bytes32 r = 0xae92e276a83c8b3bab88309dee49269a597eb5bf28a7a2883afcbd2381a86509;
        bytes32 s = 0x195f1f918a6063d82202fe41e1c54b23072594a63dbf6c735fba86c9425329dc;
        uint8 v = 0x1c;
        bytes memory sig = bytes.concat(r, s, bytes1(v));

        // Create the logicBatch with the same parameters as above
        IParam.Input[] memory inputs = new IParam.Input[](2);
        inputs[0] = IParam.Input(
            IParam.WrapMode.NONE,
            address(1), // token
            type(uint256).max, // amountBps
            0 // amountOrOffset
        );
        inputs[1] = IParam.Input(
            IParam.WrapMode.NONE,
            address(2), // token
            10000, // amountBps
            0x20 // amountOrOffset
        );
        IParam.Logic[] memory logics = new IParam.Logic[](2);
        logics[0] = IParam.Logic(
            address(3), // to
            '0123456789abcdef',
            inputs,
            address(4), // approveTo
            address(5) // callback
        );
        logics[1] = logics[0]; // Duplicate logic
        uint256 deadline = 1704067200;
        IParam.LogicBatch memory logicBatch = IParam.LogicBatch(logics, deadline);

        // Verify the locally generated signature using the private key is the same as the external sig
        assertEq(getLogicBatchSignature(logicBatch, _buildDomainSeparator(), PRIVATE_KEY), sig);

        // Verify the signer can be recovered using the external sig
        bytes32 hashedTypedData = getLogicBatchHashedTypedData(logicBatch, _buildDomainSeparator());
        assertEq(SIGNER.isValidSignatureNow(hashedTypedData, sig), true);
    }
}
