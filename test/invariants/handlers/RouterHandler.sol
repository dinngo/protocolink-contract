// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {console} from 'forge-std/Test.sol';
import {Router} from '../../../src/Router.sol';
import {IParam} from '../../../src/interfaces/IRouter.sol';
import {LogicSignature} from '../../utils/LogicSignature.sol';
import {AddressSet, LibAddressSet} from '../helpers/AddressSet.sol';

contract RouterHandler is Test, LogicSignature {
    using LibAddressSet for AddressSet;

    uint256 public constant SIGNER_REFERRAL = 1;

    // Setup
    Router public router;
    address public owner;
    address public signer;
    uint256 public signerPrivateKey;

    // Actors
    address public currentActor;
    AddressSet internal _actors;

    // Ghost variables
    address[] public ghostAgents;

    // Summary
    mapping(bytes32 => uint256) public calls;

    // Empty arrays
    address[] public tokensReturnEmpty;
    IParam.Fee[] public feesEmpty;
    IParam.Input[] public inputsEmpty;
    IParam.Logic[] public logicsEmpty;

    constructor(Router router_) {
        owner = msg.sender;
        router = router_;

        (signer, signerPrivateKey) = makeAddrAndKey('Signer');
        vm.prank(owner);
        router.addSigner(signer);
    }

    modifier createActor() {
        currentActor = msg.sender;
        _actors.add(currentActor);
        _;
    }

    modifier useActor(uint256 actorIndexSeed) {
        // 10% probability of using an existing user
        if (_actors.count() == 0 || actorIndexSeed % 10 < 9) {
            currentActor = msg.sender;
            _actors.add(currentActor);
            calls['actorsNum']++;
        } else {
            currentActor = _actors.rand(actorIndexSeed);
        }
        _;
    }

    modifier recordAgent() {
        bool isExistingAgent = address(router.agents(currentActor)) != address(0) ? true : false;
        _;
        if (!isExistingAgent) {
            ghostAgents.push(router.calcAgent(currentActor));
        }
    }

    modifier countCall(bytes32 key) {
        calls[key]++;
        _;
    }

    receive() external payable {}

    function actors() external view returns (address[] memory) {
        return _actors.addrs;
    }

    function ghostAgentsLength() external view returns (uint256) {
        return ghostAgents.length;
    }

    function callSummary() external view {
        console.log('Call summary:');
        console.log('-------------');
        console.log('execute', calls['execute']);
        console.log('executeWithSignature', calls['executeWithSignature']);
        console.log('newAgent', calls['newAgent']);
        console.log('newAgentFor', calls['newAgentFor']);
        console.log('actorsNum', calls['actorsNum']);
        console.log('-------------');
    }

    function execute(uint256 actorSeed) external useActor(actorSeed) recordAgent countCall('execute') {
        vm.prank(currentActor);
        router.execute(logicsEmpty, feesEmpty, tokensReturnEmpty, SIGNER_REFERRAL);
    }

    function executeWithSignature(
        uint256 actorSeed
    ) external useActor(actorSeed) recordAgent countCall('executeWithSignature') {
        vm.startPrank(currentActor);
        uint256 deadline = block.timestamp;
        IParam.LogicBatch memory logicBatch = IParam.LogicBatch(logicsEmpty, feesEmpty, deadline);
        bytes memory sigature = getLogicBatchSignature(logicBatch, router.domainSeparator(), signerPrivateKey);
        router.executeWithSignature(logicBatch, signer, sigature, tokensReturnEmpty, SIGNER_REFERRAL);
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
