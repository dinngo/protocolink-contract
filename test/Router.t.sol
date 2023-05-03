// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {ERC20} from 'openzeppelin-contracts/contracts/token/ERC20/ERC20.sol';
import {SafeERC20, IERC20} from 'openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol';
import {Router, IRouter} from 'src/Router.sol';
import {IParam} from 'src/interfaces/IParam.sol';
import {MockFallback} from './mocks/MockFallback.sol';
import {LogicSignature} from './utils/LogicSignature.sol';

contract RouterTest is Test, LogicSignature {
    using SafeERC20 for IERC20;

    uint256 public constant SKIP = 0x8000000000000000000000000000000000000000000000000000000000000000;
    uint256 public constant SIGNER_REFERRAL = 1;
    address public constant INVALID_PAUSER = address(0);

    address public user;
    address public pauser;
    address public signer;
    uint256 public signerPrivateKey;
    IRouter public router;
    IERC20 public mockERC20;
    address public mockTo;

    // Empty arrays
    address[] public tokensReturnEmpty;
    IParam.Fee[] public feesEmpty;
    IParam.Input[] public inputsEmpty;
    IParam.Logic[] public logicsEmpty;

    event SignerAdded(address indexed signer);
    event SignerRemoved(address indexed signer);
    event PauserSet(address indexed pauser);
    event Paused();
    event Resumed();
    event AgentCreated(address indexed agent, address indexed user);
    event Execute(address indexed user, address indexed agent, uint256 indexed referralCode);

    function setUp() external {
        user = makeAddr('User');
        pauser = makeAddr('Pauser');
        (signer, signerPrivateKey) = makeAddrAndKey('Signer');
        address feeCollector = makeAddr('FeeCollector');
        router = new Router(makeAddr('WrappedNative'), pauser, feeCollector);
        mockERC20 = new ERC20('mockERC20', 'mock');
        mockTo = address(new MockFallback());

        vm.label(address(mockERC20), 'mERC20');
        vm.label(address(mockTo), 'mTo');
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
        IParam.Logic[] memory logics = new IParam.Logic[](1);
        logics[0] = IParam.Logic(
            address(mockTo), // to
            '',
            inputsEmpty,
            IParam.WrapMode.NONE,
            address(0), // approveTo
            address(0) // callback
        );
        assertEq(router.getAgent(user), address(0));
        vm.prank(user);
        router.execute(logics, feesEmpty, tokensReturnEmpty, SIGNER_REFERRAL);
        assertFalse(router.getAgent(user) == address(0));
    }

    function testOldUserExecute() external {
        IParam.Logic[] memory logics = new IParam.Logic[](1);
        logics[0] = IParam.Logic(
            address(mockTo), // to
            '',
            inputsEmpty,
            IParam.WrapMode.NONE,
            address(0), // approveTo
            address(0) // callback
        );
        vm.startPrank(user);
        router.newAgent();
        assertFalse(router.getAgent(user) == address(0));
        vm.expectEmit(true, true, true, true, address(router));
        emit Execute(user, address(router.agents(user)), SIGNER_REFERRAL);
        router.execute(logics, feesEmpty, tokensReturnEmpty, SIGNER_REFERRAL);
        vm.stopPrank();
    }

    function testCannotExecuteReentrance() external {
        IParam.Logic[] memory logics = new IParam.Logic[](1);
        logics[0] = IParam.Logic(
            address(router), // to
            abi.encodeCall(IRouter.execute, (logicsEmpty, feesEmpty, tokensReturnEmpty, SIGNER_REFERRAL)),
            inputsEmpty,
            IParam.WrapMode.NONE,
            address(0), // approveTo
            address(0) // callback
        );
        vm.startPrank(user);
        router.newAgent();
        vm.expectRevert(IRouter.Reentrancy.selector);
        router.execute(logics, feesEmpty, tokensReturnEmpty, SIGNER_REFERRAL);
        vm.stopPrank();
    }

    function testGetAgentWithUserExecuting() external {
        vm.prank(user);
        router.newAgent();
        address agent = router.getAgent(user);
        IParam.Logic[] memory logics = new IParam.Logic[](1);
        logics[0] = IParam.Logic(
            address(this), // to
            abi.encodeCall(this.checkExecutingAgent, (agent)),
            inputsEmpty,
            IParam.WrapMode.NONE,
            address(0), // approveTo
            address(0) // callback
        );
        vm.prank(user);
        router.execute(logics, feesEmpty, tokensReturnEmpty, SIGNER_REFERRAL);
        (, agent) = router.getUserAgent();
        // The executing agent should be reset to 0
        assertEq(agent, address(0));
    }

    function checkExecutingAgent(address agent) external view {
        (, address executingAgent) = router.getUserAgent();
        if (agent != executingAgent) revert();
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

    function testExecuteWithSignature() external {
        router.addSigner(signer);

        // Ensure correct EIP-712 encodeData for non-empty Input, Logic, Fee
        IParam.Input[] memory inputs = new IParam.Input[](1);
        inputs[0] = IParam.Input(
            address(mockERC20),
            SKIP, // amountBps
            0 // amountOrOffset
        );
        IParam.Logic[] memory logics = new IParam.Logic[](1);
        logics[0] = IParam.Logic(
            address(mockTo),
            '',
            inputs,
            IParam.WrapMode.NONE,
            address(0), // approveTo
            address(0) // callback
        );
        IParam.Fee[] memory fees = new IParam.Fee[](1);
        fees[0] = IParam.Fee(address(mockERC20), 0, bytes32(0));
        uint256 deadline = block.timestamp;
        IParam.LogicBatch memory logicBatch = IParam.LogicBatch(logics, fees, deadline);
        bytes memory sigature = getLogicBatchSignature(logicBatch, router.domainSeparator(), signerPrivateKey);

        vm.startPrank(user);
        vm.expectEmit(true, true, true, true, address(router));
        address calcAgent = router.calcAgent(user);
        emit Execute(user, calcAgent, SIGNER_REFERRAL);
        router.executeWithSignature(logicBatch, signer, sigature, tokensReturnEmpty, SIGNER_REFERRAL);
        vm.stopPrank();
    }

    function testCannotExecutePaused() external {
        vm.prank(pauser);
        router.pause();
        assertTrue(router.paused());

        // Execution revert when router paused
        vm.expectRevert(IRouter.RouterIsPaused.selector);
        vm.prank(user);
        router.execute(logicsEmpty, feesEmpty, tokensReturnEmpty, SIGNER_REFERRAL);

        // Execution success when router resumed
        vm.prank(pauser);
        router.resume();
        assertFalse(router.paused());
        router.execute(logicsEmpty, feesEmpty, tokensReturnEmpty, SIGNER_REFERRAL);
    }

    function testCannotExecuteSignatureExpired() external {
        uint256 deadline = block.timestamp - 1; // Expired
        IParam.LogicBatch memory logicBatch = IParam.LogicBatch(logicsEmpty, feesEmpty, deadline);
        bytes memory sigature = getLogicBatchSignature(logicBatch, router.domainSeparator(), signerPrivateKey);

        vm.expectRevert(abi.encodeWithSelector(IRouter.SignatureExpired.selector, deadline));
        vm.prank(user);
        router.executeWithSignature(logicBatch, signer, sigature, tokensReturnEmpty, SIGNER_REFERRAL);
    }

    function testCannotExecuteInvalidSigner() external {
        // Don't add signer
        uint256 deadline = block.timestamp;
        IParam.LogicBatch memory logicBatch = IParam.LogicBatch(logicsEmpty, feesEmpty, deadline);
        bytes memory sigature = getLogicBatchSignature(logicBatch, router.domainSeparator(), signerPrivateKey);

        vm.expectRevert(abi.encodeWithSelector(IRouter.InvalidSigner.selector, signer));
        vm.prank(user);
        router.executeWithSignature(logicBatch, signer, sigature, tokensReturnEmpty, SIGNER_REFERRAL);
    }

    function testCannotExecuteInvalidSignature() external {
        router.addSigner(signer);

        // Sign correct deadline and logicBatch
        uint256 deadline = block.timestamp;
        IParam.LogicBatch memory logicBatch = IParam.LogicBatch(logicsEmpty, feesEmpty, deadline);
        bytes memory sigature = getLogicBatchSignature(logicBatch, router.domainSeparator(), signerPrivateKey);

        // Tamper deadline
        logicBatch = IParam.LogicBatch(logicsEmpty, feesEmpty, deadline + 1);
        vm.prank(user);
        vm.expectRevert(IRouter.InvalidSignature.selector);
        router.executeWithSignature(logicBatch, signer, sigature, tokensReturnEmpty, SIGNER_REFERRAL);

        // Tamper logics
        IParam.Logic[] memory logics = new IParam.Logic[](1);
        logicBatch = IParam.LogicBatch(logics, feesEmpty, deadline);
        vm.prank(user);
        vm.expectRevert(IRouter.InvalidSignature.selector);
        router.executeWithSignature(logicBatch, signer, sigature, tokensReturnEmpty, SIGNER_REFERRAL);
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
        assertFalse(router.paused());
        vm.expectEmit(true, true, true, true, address(router));
        emit Paused();
        vm.prank(pauser);
        router.pause();
        assertTrue(router.paused());
    }

    function testCannotPauseByNonPauser() external {
        vm.expectRevert(IRouter.InvalidPauser.selector);
        vm.prank(user);
        router.pause();
    }

    function testResume() external {
        vm.prank(pauser);
        router.pause();
        assertTrue(router.paused());

        vm.expectEmit(true, true, true, true, address(router));
        emit Resumed();
        vm.prank(pauser);
        router.resume();
        assertFalse(router.paused());
    }

    function testCannotResumeByNonPauser() external {
        vm.prank(pauser);
        router.pause();
        assertTrue(router.paused());

        vm.expectRevert(IRouter.InvalidPauser.selector);
        vm.prank(user);
        router.resume();
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
}
