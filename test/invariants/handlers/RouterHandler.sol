// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {console2} from 'forge-std/Test.sol';
import {Router} from 'src/Router.sol';
import {DataType} from 'src/interfaces/IRouter.sol';
import {TypedDataSignature} from '../../utils/TypedDataSignature.sol';

contract RouterHandler is Test, TypedDataSignature {
    // Setup
    Router public router;
    address public owner;
    address public signer;
    uint256 public signerPrivateKey;

    // Actors
    address public currentActor;
    address[] public actors;
    mapping(address actor => uint256 privateKey) actorPrivateKeys;

    // Ghost variables
    address[] public ghostAgents;

    // Summary
    mapping(bytes32 => uint256) public calls;

    // Empty arrays
    address[] public tokensReturnEmpty;
    DataType.Fee[] public feesEmpty;
    DataType.Logic[] public logicsEmpty;
    bytes[] public permit2DatasEmpty;
    bytes32[] public referralsEmpty;

    constructor(Router router_) {
        owner = msg.sender;
        router = router_;

        (signer, signerPrivateKey) = makeAddrAndKey('Signer');
        vm.prank(owner);
        router.addSigner(signer);
    }

    modifier useActor(string calldata name) {
        (address user, uint256 userPrivateKey) = makeAddrAndKey(name);
        uint256 actorSeed = uint160(user);

        if (actors.length == 0 || actorSeed % 10 < 9) {
            // 90% probability of creating a new actor
            currentActor = user;
            if (actorPrivateKeys[currentActor] == 0) {
                actors.push(currentActor);
                actorPrivateKeys[currentActor] = userPrivateKey;
                calls['actorsNum']++;
            }
        } else {
            // 10% probability of using an existing actor
            currentActor = actors[actorSeed % actors.length];
        }
        _;
    }

    modifier recordAgent() {
        bool isExistingAgent = address(router.agents(currentActor)) != address(0) ? true : false;
        _;
        if (!isExistingAgent) {
            ghostAgents.push(address(router.agents(currentActor)));
        }
    }

    modifier countCall(bytes32 key) {
        calls[key]++;
        _;
    }

    function actorsLength() external view returns (uint256) {
        return actors.length;
    }

    function ghostAgentsLength() external view returns (uint256) {
        return ghostAgents.length;
    }

    function callSummary() external view {
        console2.log('\nCall Summary\n');
        console2.log('execute', calls['execute']);
        console2.log('executeWithSignerFee', calls['executeWithSignerFee']);
        console2.log('executeBySig', calls['executeBySig']);
        console2.log('executeBySigWithSignerFee', calls['executeBySigWithSignerFee']);
        console2.log('executeFor', calls['executeFor']);
        console2.log('executeForWithSignerFee', calls['executeForWithSignerFee']);
        console2.log('newAgent', calls['newAgent']);
        console2.log('newAgentFor', calls['newAgentFor']);
        console2.log('actorsNum', calls['actorsNum']);
    }

    function execute(string calldata name) external useActor(name) recordAgent countCall('execute') {
        vm.prank(currentActor);
        router.execute(permit2DatasEmpty, logicsEmpty, tokensReturnEmpty);
    }

    function executeWithSignerFee(
        string calldata name
    ) external useActor(name) recordAgent countCall('executeWithSignerFee') {
        uint256 deadline = block.timestamp;
        DataType.LogicBatch memory logicBatch = DataType.LogicBatch(logicsEmpty, feesEmpty, referralsEmpty, deadline);
        bytes memory signerSignature = getTypedDataSignature(logicBatch, router.domainSeparator(), signerPrivateKey);
        vm.prank(currentActor);
        router.executeWithSignerFee(permit2DatasEmpty, logicBatch, signer, signerSignature, tokensReturnEmpty);
    }

    function executeBySig(string calldata name) external useActor(name) recordAgent countCall('executeBySig') {
        uint256 deadline = block.timestamp + 1 days;
        uint256 nonce = router.executionNonces(currentActor);
        DataType.ExecutionDetails memory details = DataType.ExecutionDetails(
            permit2DatasEmpty,
            logicsEmpty,
            tokensReturnEmpty,
            nonce,
            deadline
        );
        bytes memory currentActorSignature = getTypedDataSignature(
            details,
            router.domainSeparator(),
            actorPrivateKeys[currentActor]
        );
        vm.prank(msg.sender);
        router.executeBySig(details, currentActor, currentActorSignature);
    }

    function executeBySigWithSignerFee(
        string calldata name
    ) external useActor(name) recordAgent countCall('executeBySigWithSignerFee') {
        uint256 deadline = block.timestamp;
        DataType.LogicBatch memory logicBatch = DataType.LogicBatch(logicsEmpty, feesEmpty, referralsEmpty, deadline);
        bytes memory signerSignature = getTypedDataSignature(logicBatch, router.domainSeparator(), signerPrivateKey);
        deadline = block.timestamp + 1 days;
        uint256 nonce = router.executionNonces(currentActor);
        DataType.ExecutionBatchDetails memory details = DataType.ExecutionBatchDetails(
            permit2DatasEmpty,
            logicBatch,
            tokensReturnEmpty,
            nonce,
            deadline
        );
        bytes memory currentActorSignature = getTypedDataSignature(
            details,
            router.domainSeparator(),
            actorPrivateKeys[currentActor]
        );
        vm.prank(msg.sender);
        router.executeBySigWithSignerFee(details, currentActor, currentActorSignature, signer, signerSignature);
    }

    function executeFor(string calldata name) external useActor(name) recordAgent countCall('executeFor') {
        uint128 expiry = uint128(block.timestamp) + 1 days;
        address delegatee = msg.sender;
        vm.prank(currentActor);
        router.allow(delegatee, expiry);
        vm.prank(delegatee);
        router.executeFor(currentActor, permit2DatasEmpty, logicsEmpty, tokensReturnEmpty);
    }

    function executeForWithSignerFee(
        string calldata name
    ) external useActor(name) recordAgent countCall('executeForWithSignerFee') {
        uint128 expiry = uint128(block.timestamp) + 1 days;
        address delegatee = msg.sender;
        vm.prank(currentActor);
        router.allow(delegatee, expiry);
        uint256 deadline = block.timestamp;
        DataType.LogicBatch memory logicBatch = DataType.LogicBatch(logicsEmpty, feesEmpty, referralsEmpty, deadline);
        bytes memory signerSignature = getTypedDataSignature(logicBatch, router.domainSeparator(), signerPrivateKey);
        vm.prank(delegatee);
        router.executeForWithSignerFee(
            currentActor,
            permit2DatasEmpty,
            logicBatch,
            signer,
            signerSignature,
            tokensReturnEmpty
        );
    }

    function newAgent(string calldata name) external useActor(name) recordAgent countCall('newAgent') {
        vm.prank(currentActor);
        router.newAgent();
    }

    function newAgentFor(string calldata name) external useActor(name) recordAgent countCall('newAgentFor') {
        vm.prank(msg.sender);
        router.newAgent(currentActor);
    }
}
