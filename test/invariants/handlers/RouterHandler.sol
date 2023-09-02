// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {console2} from 'forge-std/Test.sol';
import {Router} from 'src/Router.sol';
import {DataType} from 'src/interfaces/IRouter.sol';
import {TypedDataSignature} from '../../utils/TypedDataSignature.sol';

contract RouterHandler is Test, TypedDataSignature {
    uint256 public constant SIGNER_REFERRAL = 1;

    // Setup
    Router public router;
    address public owner;
    address public signer;
    uint256 public signerPrivateKey;

    // Actors
    address public currentActor;
    address[] public actors;
    mapping(address actor => bool exist) actorsExist;

    // Ghost variables
    address[] public ghostAgents;

    // Summary
    mapping(bytes32 => uint256) public calls;

    // Empty arrays
    address[] public tokensReturnEmpty;
    DataType.Fee[] public feesEmpty;
    DataType.Logic[] public logicsEmpty;
    bytes[] public permit2DatasEmpty;

    constructor(Router router_) {
        owner = msg.sender;
        router = router_;

        (signer, signerPrivateKey) = makeAddrAndKey('Signer');
        vm.prank(owner);
        router.addSigner(signer);
    }

    modifier useActor(uint256 actorSeed) {
        if (actors.length == 0 || actorSeed % 10 < 9) {
            // 90% probability of creating an new actor
            currentActor = msg.sender;
            if (!actorsExist[currentActor]) {
                actorsExist[currentActor] = true;
                actors.push(currentActor);
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
        console2.log('newAgent', calls['newAgent']);
        console2.log('newAgentFor', calls['newAgentFor']);
        console2.log('actorsNum', calls['actorsNum']);
    }

    function execute(uint256 actorSeed) external useActor(actorSeed) recordAgent countCall('execute') {
        vm.prank(currentActor);
        router.execute(permit2DatasEmpty, logicsEmpty, tokensReturnEmpty, SIGNER_REFERRAL);
    }

    function executeWithSignerFee(
        uint256 actorSeed
    ) external useActor(actorSeed) recordAgent countCall('executeWithSignerFee') {
        vm.startPrank(currentActor);
        uint256 deadline = block.timestamp;
        DataType.LogicBatch memory logicBatch = DataType.LogicBatch(logicsEmpty, feesEmpty, deadline);
        bytes memory sigature = getTypedDataSignature(logicBatch, router.domainSeparator(), signerPrivateKey);
        router.executeWithSignerFee(
            permit2DatasEmpty,
            logicBatch,
            signer,
            sigature,
            tokensReturnEmpty,
            SIGNER_REFERRAL
        );
        vm.stopPrank();
    }

    function newAgent(uint256 actorSeed) external useActor(actorSeed) recordAgent countCall('newAgent') {
        vm.prank(currentActor);
        router.newAgent();
    }

    function newAgentFor(uint256 actorSeed) external useActor(actorSeed) recordAgent countCall('newAgentFor') {
        router.newAgent(currentActor);
    }
}
