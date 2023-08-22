// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {ERC20, IERC20} from 'openzeppelin-contracts/contracts/token/ERC20/ERC20.sol';
import {Router, IRouter} from 'src/Router.sol';
import {IParam} from 'src/interfaces/IParam.sol';
import {MockFallback} from './mocks/MockFallback.sol';
import {TypedDataSignature} from './utils/TypedDataSignature.sol';

contract RouterTest is Test, TypedDataSignature {
    address public constant PAUSED = address(0);
    address public constant INIT_CURRENT_USER = address(1);
    uint256 public constant BPS_NOT_USED = 0;
    uint256 public constant SIGNER_REFERRAL = 1;
    address public constant INVALID_PAUSER = address(0);

    address public user;
    uint256 public userPrivateKey;
    address public delegatee;
    address public pauser;
    address public feeCollector;
    address public signer;
    uint256 public signerPrivateKey;
    IRouter public router;
    IERC20 public mockERC20;
    address public mockTo;

    // Empty types
    address[] public tokensReturnEmpty;
    IParam.Fee[] public feesEmpty;
    IParam.Input[] public inputsEmpty;
    IParam.Logic[] public logicsEmpty;
    IParam.LogicBatch public logicBatchEmpty;
    bytes[] public permit2DatasEmpty;

    event SignerAdded(address indexed signer);
    event SignerRemoved(address indexed signer);
    event FeeCollectorSet(address indexed feeCollector_);
    event PauserSet(address indexed pauser);
    event Paused();
    event Unpaused();
    event AgentCreated(address indexed agent, address indexed user);
    event Execute(address indexed user, address indexed agent, uint256 indexed referralCode);
    event Delegated(address indexed delegator, address indexed delegatee, uint128 expiry);
    event DelegationNonceInvalidation(
        address indexed user,
        address indexed delegatee,
        uint128 newNonce,
        uint128 oldNonce
    );
    event ExecutionNonceInvalidation(address indexed user, uint256 newNonce, uint256 oldNonce);

    function setUp() external {
        (user, userPrivateKey) = makeAddrAndKey('User');
        delegatee = makeAddr('Delegatee');
        pauser = makeAddr('Pauser');
        feeCollector = makeAddr('FeeCollector');
        (signer, signerPrivateKey) = makeAddrAndKey('Signer');
        router = new Router(makeAddr('WrappedNative'), makeAddr('Permit2'), address(this), pauser, feeCollector);
        mockERC20 = new ERC20('mockERC20', 'mock');
        mockTo = address(new MockFallback());

        vm.label(address(mockERC20), 'mERC20');
        vm.label(address(mockTo), 'mTo');
    }

    function testSetUp() external {
        assertTrue(router.agentImplementation() != address(0));
        assertEq(router.currentUser(), INIT_CURRENT_USER);
        assertEq(router.pauser(), pauser);
        assertEq(router.feeCollector(), feeCollector);
        assertEq(router.owner(), address(this));
    }

    function testNewAgent() external {
        vm.prank(user);
        address agent = router.newAgent();
        assertEq(router.getAgent(user), agent);
    }

    function testNewAgentForUser() external {
        address calcAgent = router.calcAgent(user);
        vm.expectEmit(true, true, true, true, address(router));
        emit AgentCreated(calcAgent, user);
        address agent = router.newAgent(user);
        assertEq(router.getAgent(user), agent);
    }

    function testCalcAgent() external {
        address predictAddress = router.calcAgent(user);
        vm.prank(user);
        router.newAgent();
        assertEq(router.getAgent(user), predictAddress);
    }

    function testCannotNewAgentAgain() external {
        vm.startPrank(user);
        router.newAgent();
        vm.expectRevert(IRouter.AgentAlreadyCreated.selector);
        router.newAgent();
        vm.stopPrank();
    }

    function testNewUserExecute() external {
        assertEq(router.getAgent(user), address(0));
        vm.prank(user);
        router.execute(permit2DatasEmpty, logicsEmpty, tokensReturnEmpty, SIGNER_REFERRAL);
        assertFalse(router.getAgent(user) == address(0));
    }

    function testOldUserExecute() external {
        vm.startPrank(user);
        router.newAgent();
        assertFalse(router.getAgent(user) == address(0));
        vm.expectEmit(true, true, true, true, address(router));
        emit Execute(user, address(router.agents(user)), SIGNER_REFERRAL);
        router.execute(permit2DatasEmpty, logicsEmpty, tokensReturnEmpty, SIGNER_REFERRAL);
        vm.stopPrank();
    }

    function testGetAgentWithUserExecuting() external {
        vm.prank(user);
        router.newAgent();
        address agent = router.getAgent(user);
        vm.prank(user);
        router.execute(permit2DatasEmpty, logicsEmpty, tokensReturnEmpty, SIGNER_REFERRAL);
        (, agent) = router.getCurrentUserAgent();
        // The executing agent should be reset to 0
        assertEq(agent, address(0));
    }

    function checkExecutingAgent(address agent) external view {
        (, address executingAgent) = router.getCurrentUserAgent();
        if (agent != executingAgent) revert();
    }

    function testExecuteBySig() external {
        vm.prank(user);
        router.newAgent();
        // Ensure correct EIP-712 encodeData
        uint256 deadline = block.timestamp + 3600;
        uint256 nonce = 0;
        IParam.ExecutionDetails memory details = IParam.ExecutionDetails(
            permit2DatasEmpty,
            logicsEmpty,
            tokensReturnEmpty,
            SIGNER_REFERRAL,
            nonce,
            deadline
        );
        bytes memory signature = getTypedDataSignature(details, router.domainSeparator(), userPrivateKey);
        vm.expectEmit(true, true, true, true, address(router));
        emit Execute(user, address(router.agents(user)), SIGNER_REFERRAL);
        router.executeBySig(details, user, signature);
        uint256 newNonce = router.executionNonces(user);
        assertEq(newNonce, nonce + 1);
    }

    function testCannotExecuteBySigWithIncorrectSignature() external {
        vm.prank(user);
        router.newAgent();
        // Ensure correct EIP-712 encodeData
        uint256 deadline = block.timestamp + 3600;
        uint256 nonce = 0;
        IParam.ExecutionDetails memory details = IParam.ExecutionDetails(
            permit2DatasEmpty,
            logicsEmpty,
            tokensReturnEmpty,
            SIGNER_REFERRAL,
            nonce,
            deadline
        );
        bytes memory signature = getTypedDataSignature(details, router.domainSeparator(), signerPrivateKey);
        vm.expectRevert(IRouter.InvalidSignature.selector);
        router.executeBySig(details, user, signature);
    }

    function testAddSigner(address signer_) external {
        vm.expectEmit(true, true, true, true, address(router));
        emit SignerAdded(signer_);
        router.addSigner(signer_);
        assertTrue(router.signers(signer_));
    }

    function testCannotAddSignerByNonOwner() external {
        vm.expectRevert('Ownable: caller is not the owner');
        vm.prank(user);
        router.addSigner(signer);
    }

    function testRemoveSigner(address signer_) external {
        router.addSigner(signer_);
        vm.expectEmit(true, true, true, true, address(router));
        emit SignerRemoved(signer_);
        router.removeSigner(signer_);
        assertFalse(router.signers(signer_));
    }

    function testCannotRemoveSignerByNonOwner() external {
        vm.expectRevert('Ownable: caller is not the owner');
        vm.prank(user);
        router.removeSigner(signer);
    }

    function testExecuteWithSignerFee() external {
        router.addSigner(signer);
        uint256 deadline = block.timestamp;
        IParam.LogicBatch memory logicBatch = IParam.LogicBatch(logicsEmpty, feesEmpty, deadline);
        bytes memory signature = getTypedDataSignature(logicBatch, router.domainSeparator(), signerPrivateKey);

        vm.expectEmit(true, true, true, true, address(router));
        address calcAgent = router.calcAgent(user);
        emit Execute(user, calcAgent, SIGNER_REFERRAL);
        vm.prank(user);
        router.executeWithSignerFee(
            permit2DatasEmpty,
            logicBatch,
            signer,
            signature,
            tokensReturnEmpty,
            SIGNER_REFERRAL
        );
    }

    function testCannotExecuteWhenPaused() external {
        vm.prank(pauser);
        router.pause();

        vm.startPrank(user);
        // `execute` should revert when router is paused
        vm.expectRevert(IRouter.NotReady.selector);
        router.execute(permit2DatasEmpty, logicsEmpty, tokensReturnEmpty, SIGNER_REFERRAL);

        // `executeWithSignerFee` should revert when router is paused
        vm.expectRevert(IRouter.NotReady.selector);
        router.executeWithSignerFee(
            permit2DatasEmpty,
            logicBatchEmpty,
            signer,
            new bytes(0),
            tokensReturnEmpty,
            SIGNER_REFERRAL
        );
        vm.stopPrank();
    }

    function testCannotExecuteReentrance() external {
        IParam.Logic[] memory logics = new IParam.Logic[](1);
        logics[0] = IParam.Logic(
            address(router), // to
            abi.encodeCall(IRouter.execute, (permit2DatasEmpty, logics, tokensReturnEmpty, SIGNER_REFERRAL)),
            inputsEmpty,
            IParam.WrapMode.NONE,
            address(0), // approveTo
            address(0) // callback
        );
        vm.expectRevert(IRouter.NotReady.selector);
        vm.prank(user);
        router.execute(permit2DatasEmpty, logics, tokensReturnEmpty, SIGNER_REFERRAL);
    }

    function testCannotExecuteSignatureExpired() external {
        uint256 deadline = block.timestamp - 1; // Expired
        IParam.LogicBatch memory logicBatch = IParam.LogicBatch(logicsEmpty, feesEmpty, deadline);
        bytes memory signature = getTypedDataSignature(logicBatch, router.domainSeparator(), signerPrivateKey);

        vm.expectRevert(abi.encodeWithSelector(IRouter.SignatureExpired.selector, deadline));
        vm.prank(user);
        router.executeWithSignerFee(
            permit2DatasEmpty,
            logicBatch,
            signer,
            signature,
            tokensReturnEmpty,
            SIGNER_REFERRAL
        );
    }

    function testCannotExecuteInvalidSigner() external {
        // Don't add signer
        uint256 deadline = block.timestamp;
        IParam.LogicBatch memory logicBatch = IParam.LogicBatch(logicsEmpty, feesEmpty, deadline);
        bytes memory signature = getTypedDataSignature(logicBatch, router.domainSeparator(), signerPrivateKey);

        vm.expectRevert(abi.encodeWithSelector(IRouter.InvalidSigner.selector, signer));
        vm.prank(user);
        router.executeWithSignerFee(
            permit2DatasEmpty,
            logicBatch,
            signer,
            signature,
            tokensReturnEmpty,
            SIGNER_REFERRAL
        );
    }

    function testCannotExecuteInvalidSignature() external {
        router.addSigner(signer);

        // Sign correct deadline and logicBatch
        uint256 deadline = block.timestamp;
        IParam.LogicBatch memory logicBatch = IParam.LogicBatch(logicsEmpty, feesEmpty, deadline);
        bytes memory signature = getTypedDataSignature(logicBatch, router.domainSeparator(), signerPrivateKey);

        // Tamper deadline
        logicBatch = IParam.LogicBatch(logicsEmpty, feesEmpty, deadline + 1);
        vm.prank(user);
        vm.expectRevert(IRouter.InvalidSignature.selector);
        router.executeWithSignerFee(
            permit2DatasEmpty,
            logicBatch,
            signer,
            signature,
            tokensReturnEmpty,
            SIGNER_REFERRAL
        );

        // Tamper logics
        IParam.Logic[] memory logics = new IParam.Logic[](1);
        logicBatch = IParam.LogicBatch(logics, feesEmpty, deadline);
        vm.prank(user);
        vm.expectRevert(IRouter.InvalidSignature.selector);
        router.executeWithSignerFee(
            permit2DatasEmpty,
            logicBatch,
            signer,
            signature,
            tokensReturnEmpty,
            SIGNER_REFERRAL
        );
    }

    function testExecuteBySigWithSignerFee() external {
        router.addSigner(signer);
        uint256 deadline = block.timestamp;
        IParam.LogicBatch memory logicBatch = IParam.LogicBatch(logicsEmpty, feesEmpty, deadline);
        bytes memory signerSignature = getTypedDataSignature(logicBatch, router.domainSeparator(), signerPrivateKey);
        // Ensure correct EIP-712 encodeData
        deadline = block.timestamp + 3600;
        uint256 nonce = 0;
        IParam.ExecutionBatchDetails memory details = IParam.ExecutionBatchDetails(
            permit2DatasEmpty,
            logicBatch,
            tokensReturnEmpty,
            SIGNER_REFERRAL,
            nonce,
            deadline
        );
        bytes memory userSignature = getTypedDataSignature(details, router.domainSeparator(), userPrivateKey);
        vm.expectEmit(true, true, true, true, address(router));
        address calcAgent = router.calcAgent(user);
        emit Execute(user, calcAgent, SIGNER_REFERRAL);
        router.executeBySigWithSignerFee(details, user, userSignature, signer, signerSignature);
        uint256 newNonce = router.executionNonces(user);
        assertEq(newNonce, nonce + 1);
    }

    function testExecuteBySigWithSignerFeeWithIncorrectUserSignature() external {
        router.addSigner(signer);
        uint256 deadline = block.timestamp;
        IParam.LogicBatch memory logicBatch = IParam.LogicBatch(logicsEmpty, feesEmpty, deadline);
        bytes memory signerSignature = getTypedDataSignature(logicBatch, router.domainSeparator(), signerPrivateKey);
        // Ensure correct EIP-712 encodeData
        deadline = block.timestamp + 3600;
        uint256 nonce = 0;
        IParam.ExecutionBatchDetails memory details = IParam.ExecutionBatchDetails(
            permit2DatasEmpty,
            logicBatch,
            tokensReturnEmpty,
            SIGNER_REFERRAL,
            nonce,
            deadline
        );
        bytes memory userSignature = getTypedDataSignature(details, router.domainSeparator(), signerPrivateKey);
        vm.expectRevert(IRouter.InvalidSignature.selector);
        router.executeBySigWithSignerFee(details, user, userSignature, signer, signerSignature);
    }

    function testSetPauser(address pauser_) external {
        vm.assume(pauser_ != INVALID_PAUSER);
        vm.expectEmit(true, true, true, true, address(router));
        emit PauserSet(pauser_);
        router.setPauser(pauser_);
        assertEq(router.pauser(), pauser_);
    }

    function testCannotSetPauserByNonOwner(address pauser_) external {
        vm.assume(pauser_ != INVALID_PAUSER);
        vm.expectRevert('Ownable: caller is not the owner');
        vm.prank(user);
        router.setPauser(pauser_);
    }

    function testCannotSetPauserInvalidNewPauser() external {
        vm.expectRevert(IRouter.InvalidNewPauser.selector);
        router.setPauser(INVALID_PAUSER);
    }

    function testPause() external {
        vm.expectEmit(true, true, true, true, address(router));
        emit Paused();
        vm.prank(pauser);
        router.pause();
        assertEq(router.currentUser(), PAUSED);
    }

    function testCannotPauseByNonPauser() external {
        vm.expectRevert(IRouter.InvalidPauser.selector);
        vm.prank(user);
        router.pause();
    }

    function testCannotPauseWhenAlreadyPaused() external {
        vm.startPrank(pauser);
        router.pause();
        vm.expectRevert(IRouter.AlreadyPaused.selector);
        router.pause();
        vm.stopPrank();
    }

    function testUnpause() external {
        vm.startPrank(pauser);
        router.pause();
        vm.expectEmit(true, true, true, true, address(router));
        emit Unpaused();
        router.unpause();
        assertEq(router.currentUser(), INIT_CURRENT_USER);
        vm.stopPrank();
    }

    function testCannotUnpauseByNonPauser() external {
        vm.expectRevert(IRouter.InvalidPauser.selector);
        vm.prank(user);
        router.unpause();
    }

    function testCannotUnpauseWhenNotPaused() external {
        vm.expectRevert(IRouter.NotPaused.selector);
        vm.prank(pauser);
        router.unpause();
    }

    function testRescue(uint256 amount) external {
        deal(address(mockERC20), address(router), amount);

        router.rescue(address(mockERC20), user, amount);

        assertEq(mockERC20.balanceOf(address(router)), 0);
        assertEq(mockERC20.balanceOf(user), amount);
    }

    function testCannotRescueByNonOwner() external {
        uint256 amount = 1 ether;
        deal(address(mockERC20), address(router), amount);

        vm.expectRevert('Ownable: caller is not the owner');
        vm.prank(user);
        router.rescue(address(mockERC20), user, amount);
    }

    function testCannotReceiveNativeToken() external {
        uint256 value = 1 ether;
        vm.deal(address(this), value);

        vm.expectRevert();
        (bool succ, ) = address(router).call{value: value}('');
        assertTrue(succ);
    }

    function testSetFeeCollector(address feeCollector_) external {
        vm.assume(feeCollector_ != address(0));
        vm.expectEmit(true, true, true, true, address(router));
        emit FeeCollectorSet(feeCollector_);
        router.setFeeCollector(feeCollector_);
        assertEq(router.feeCollector(), feeCollector_);
    }

    function testCannotSetFeeCollectorByNonOwner() external {
        vm.expectRevert('Ownable: caller is not the owner');
        vm.prank(user);
        router.setFeeCollector(address(user));
    }

    function testCannotSetFeeCollectorInvalidFeeCollector() external {
        vm.expectRevert(IRouter.InvalidFeeCollector.selector);
        router.setFeeCollector(address(0));
    }

    function testAllowByUser() external {
        uint128 expiry = uint128(block.timestamp) + 3600;
        vm.expectEmit(true, true, true, true, address(router));
        emit Delegated(user, delegatee, expiry);
        vm.prank(user);
        router.allow(delegatee, expiry);
        (uint128 resultExpiry, uint128 resultNonce) = router.delegations(user, delegatee);
        assertEq(resultExpiry, expiry);
        assertEq(resultNonce, 0);
    }

    function testAllowBySig() external {
        // Ensure correct EIP-712 encodeData
        uint256 deadline = block.timestamp + 3600;
        uint128 expiry = uint128(deadline) + 3600;
        uint128 nonce = 0;
        IParam.DelegationDetails memory details = IParam.DelegationDetails(delegatee, expiry, nonce, deadline);
        bytes memory signature = getTypedDataSignature(details, router.domainSeparator(), userPrivateKey);
        vm.expectEmit(true, true, true, true, address(router));
        emit Delegated(user, delegatee, expiry);
        router.allowBySig(details, user, signature);
        (uint128 resultExpiry, uint128 resultNonce) = router.delegations(user, delegatee);
        assertEq(resultExpiry, expiry);
        assertEq(resultNonce, nonce + 1);
    }

    function testCannotAllowBySigWithIncorrectNonce() external {
        uint256 deadline = block.timestamp + 3600;
        uint128 expiry = uint128(deadline) + 3600;
        uint128 nonce = 1;
        IParam.DelegationDetails memory details = IParam.DelegationDetails(delegatee, expiry, nonce, deadline);
        bytes memory signature = getTypedDataSignature(details, router.domainSeparator(), userPrivateKey);
        vm.expectRevert(IRouter.InvalidNonce.selector);
        router.allowBySig(details, user, signature);
    }

    function testDisallow() external {
        uint128 expiry = uint128(block.timestamp) + 3600;
        vm.startPrank(user);
        router.allow(delegatee, expiry);
        vm.expectEmit(true, true, true, true, address(router));
        emit Delegated(user, delegatee, 0);
        router.disallow(delegatee);
        vm.stopPrank();
    }

    function testInvalidateDelegationNonces() external {
        uint128 newNonce = 10;
        vm.expectEmit(true, true, true, true, address(router));
        emit DelegationNonceInvalidation(user, delegatee, newNonce, 0);
        vm.prank(user);
        router.invalidateDelegationNonces(delegatee, newNonce);
        (, uint128 nonce) = router.delegations(user, delegatee);
        assertEq(nonce, newNonce);
    }

    function testCannotInvalidateExcessiveDelegationNonces() external {
        uint128 newNonce = uint128(type(uint16).max) + 1;
        vm.prank(user);
        vm.expectRevert(IRouter.ExcessiveInvalidation.selector);
        router.invalidateDelegationNonces(delegatee, newNonce);
    }

    function testCannotInvalidateOldDelegationNonce() external {
        uint128 newNonce = 0;
        vm.prank(user);
        vm.expectRevert(IRouter.InvalidNonce.selector);
        router.invalidateDelegationNonces(delegatee, newNonce);
    }

    function testExecuteForBeforeExpiry() external {
        uint128 expiry = uint128(block.timestamp) + 3600;
        vm.prank(user);
        router.allow(delegatee, expiry);
        vm.prank(delegatee);
        router.executeFor(user, permit2DatasEmpty, logicsEmpty, tokensReturnEmpty, SIGNER_REFERRAL);
        assertFalse(router.getAgent(user) == address(0));
    }

    function testExecuteForAfterExpiry() external {
        uint128 expiry = uint128(block.timestamp) + 3600;
        vm.prank(user);
        router.allow(delegatee, expiry);
        vm.prank(delegatee);
        vm.expectRevert(IRouter.InvalidDelegatee.selector);
        vm.warp(expiry + 1);
        router.executeFor(user, permit2DatasEmpty, logicsEmpty, tokensReturnEmpty, SIGNER_REFERRAL);
    }

    function testExecuteForWithSignerFeeBeforeExpiry() external {
        uint128 expiry = uint128(block.timestamp) + 3600;
        vm.prank(user);
        router.allow(delegatee, expiry);
        router.addSigner(signer);
        uint256 deadline = block.timestamp;
        IParam.LogicBatch memory logicBatch = IParam.LogicBatch(logicsEmpty, feesEmpty, deadline);
        bytes memory signature = getTypedDataSignature(logicBatch, router.domainSeparator(), signerPrivateKey);

        vm.expectEmit(true, true, true, true, address(router));
        address calcAgent = router.calcAgent(user);
        emit Execute(user, calcAgent, SIGNER_REFERRAL);
        vm.prank(delegatee);
        router.executeForWithSignerFee(
            user,
            permit2DatasEmpty,
            logicBatch,
            signer,
            signature,
            tokensReturnEmpty,
            SIGNER_REFERRAL
        );
    }

    function testExecuteForWithSignerFeeAfterExpiry() external {
        uint128 expiry = uint128(block.timestamp) + 3600;
        vm.prank(user);
        router.allow(delegatee, expiry);
        router.addSigner(signer);
        uint256 deadline = block.timestamp;
        IParam.LogicBatch memory logicBatch = IParam.LogicBatch(logicsEmpty, feesEmpty, deadline);
        bytes memory signature = getTypedDataSignature(logicBatch, router.domainSeparator(), signerPrivateKey);

        vm.prank(delegatee);
        vm.expectRevert(IRouter.InvalidDelegatee.selector);
        vm.warp(expiry + 1);
        router.executeForWithSignerFee(
            user,
            permit2DatasEmpty,
            logicBatch,
            signer,
            signature,
            tokensReturnEmpty,
            SIGNER_REFERRAL
        );
    }

    function testInvalidateExecutionNonces() external {
        uint256 newNonce = 10;
        vm.expectEmit(true, true, true, true, address(router));
        emit ExecutionNonceInvalidation(user, newNonce, 0);
        vm.prank(user);
        router.invalidateExecutionNonces(newNonce);
        uint256 nonce = router.executionNonces(user);
        assertEq(nonce, newNonce);
    }

    function testCannotInvalidateExcessiveExecutionNonces() external {
        uint256 newNonce = uint256(type(uint16).max) + 1;
        vm.prank(user);
        vm.expectRevert(IRouter.ExcessiveInvalidation.selector);
        router.invalidateExecutionNonces(newNonce);
    }

    function testCannotInvalidateOldExecutionNonce() external {
        uint256 newNonce = 0;
        vm.prank(user);
        vm.expectRevert(IRouter.InvalidNonce.selector);
        router.invalidateExecutionNonces(newNonce);
    }
}
