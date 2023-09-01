// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {ERC20, IERC20} from 'openzeppelin-contracts/contracts/token/ERC20/ERC20.sol';
import {IAllowanceTransfer} from 'permit2/interfaces/IAllowanceTransfer.sol';
import {Agent} from 'src/Agent.sol';
import {AgentImplementation, IAgent} from 'src/AgentImplementation.sol';
import {Router, IRouter} from 'src/Router.sol';
import {IParam} from 'src/interfaces/IParam.sol';
import {ICallback, MockCallback} from './mocks/MockCallback.sol';
import {MockFallback} from './mocks/MockFallback.sol';
import {MockWrappedNative, IWrappedNative} from './mocks/MockWrappedNative.sol';

contract AgentTest is Test {
    address public constant NATIVE = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    uint256 public constant BPS_BASE = 10_000;
    uint256 public constant BPS_NOT_USED = 0;
    uint256 public constant OFFSET_NOT_USED = 0x8000000000000000000000000000000000000000000000000000000000000000;

    address public user;
    address public recipient;
    address public router;
    address public permit2;
    IAgent public agent;
    address public mockWrappedNative;
    IERC20 public mockERC20;
    ICallback public mockCallback;
    address public mockFallback;

    // Empty arrays
    address[] public tokensReturnEmpty;
    IParam.Fee[] public feesEmpty;
    IParam.Input[] public inputsEmpty;
    IParam.Logic[] public logicsEmpty;
    bytes[] public permit2DatasEmpty;

    event Approval(address indexed owner, address indexed spender, uint256 value);

    function setUp() external {
        user = makeAddr('User');
        recipient = makeAddr('Recipient');
        router = makeAddr('Router');
        permit2 = makeAddr('Permit2');

        mockWrappedNative = address(new MockWrappedNative());
        vm.prank(router);
        agent = IAgent(address(new Agent(address(new AgentImplementation(mockWrappedNative, permit2)))));
        mockERC20 = new ERC20('mockERC20', 'mock');
        mockCallback = new MockCallback();
        mockFallback = address(new MockFallback());

        // Mock fee charging related
        vm.etch(router, 'code');
        vm.mockCall(router, 0, abi.encodeCall(IRouter.feeRate, ()), abi.encode(0));
        vm.mockCall(router, 0, abi.encodeCall(IRouter.feeCollector, ()), abi.encode(makeAddr('collector')));

        vm.label(address(agent), 'Agent');
        vm.label(address(mockWrappedNative), 'mWrappedNative');
        vm.label(address(mockERC20), 'mERC20');
        vm.label(address(mockCallback), 'mCallback');
        vm.label(address(mockFallback), 'mFallback');
    }

    function testRouter() external {
        assertEq(agent.router(), router);
    }

    function testWrappedNative() external {
        assertEq(agent.wrappedNative(), mockWrappedNative);
    }

    function testCannotInitializeAgain() external {
        vm.expectRevert(IAgent.Initialized.selector);
        agent.initialize();
    }

    function testCannotExecuteByNotRouter() external {
        vm.startPrank(user);
        vm.expectRevert(IAgent.NotRouter.selector);
        agent.execute(permit2DatasEmpty, logicsEmpty, tokensReturnEmpty);
        vm.expectRevert(IAgent.NotRouter.selector);
        agent.executeWithSignerFee(permit2DatasEmpty, logicsEmpty, feesEmpty, tokensReturnEmpty);
        vm.stopPrank();
    }

    function testCannotDoInvalidFunctionInPermit2() external {
        bytes[] memory datas = new bytes[](1);
        datas[0] = abi.encodeCall(IAllowanceTransfer.invalidateNonces, (address(0), address(0), 1));
        vm.startPrank(router);
        vm.expectRevert(
            abi.encodeWithSelector(IAgent.InvalidPermit2Data.selector, IAllowanceTransfer.invalidateNonces.selector)
        );
        agent.execute(datas, logicsEmpty, tokensReturnEmpty);
        vm.expectRevert(
            abi.encodeWithSelector(IAgent.InvalidPermit2Data.selector, IAllowanceTransfer.invalidateNonces.selector)
        );
        agent.executeWithSignerFee(datas, logicsEmpty, feesEmpty, tokensReturnEmpty);
        vm.stopPrank();
    }

    function testCannotExecutePermit2InLogic() external {
        IParam.Logic[] memory logics = new IParam.Logic[](1);
        logics[0] = IParam.Logic(permit2, '', inputsEmpty, IParam.WrapMode.NONE, address(0), address(0));
        vm.startPrank(router);
        vm.expectRevert(IAgent.InvalidPermitCall.selector);
        agent.execute(permit2DatasEmpty, logics, tokensReturnEmpty);
        vm.expectRevert(IAgent.InvalidPermitCall.selector);
        agent.executeWithSignerFee(permit2DatasEmpty, logics, feesEmpty, tokensReturnEmpty);
        vm.stopPrank();
    }

    function testDoPermit2TransferFrom() external {
        bytes[] memory datas = new bytes[](1);
        datas[0] = abi.encodeWithSelector(0x36c78516, address(0), address(1), 1, address(mockERC20));
        vm.startPrank(router);
        // Mock the call to permit2
        vm.etch(permit2, 'code');
        vm.mockCall(permit2, 0, datas[0], '');
        agent.execute(datas, logicsEmpty, tokensReturnEmpty);
        agent.executeWithSignerFee(datas, logicsEmpty, feesEmpty, tokensReturnEmpty);
        vm.stopPrank();
    }

    function testDoPermit2TransferFromBatch() external {
        bytes[] memory datas = new bytes[](1);
        IAllowanceTransfer.AllowanceTransferDetails[]
            memory details = new IAllowanceTransfer.AllowanceTransferDetails[](1);
        details[0] = IAllowanceTransfer.AllowanceTransferDetails(address(0), address(1), 1, address(mockERC20));
        datas[0] = abi.encodeWithSelector(0x0d58b1db, details);
        vm.startPrank(router);
        // Mock the call to permit2
        vm.etch(permit2, 'code');
        vm.mockCall(permit2, 0, datas[0], '');
        agent.execute(datas, logicsEmpty, tokensReturnEmpty);
        agent.executeWithSignerFee(datas, logicsEmpty, feesEmpty, tokensReturnEmpty);
        vm.stopPrank();
    }

    function testDoPermit2Permit() external {
        bytes[] memory datas = new bytes[](2);
        datas[0] = abi.encodeWithSelector(0x2b67b570);
        datas[1] = abi.encodeWithSelector(0x2a2d80d1);
        vm.startPrank(router);
        // Mock the call to permit2
        vm.etch(permit2, 'code');
        vm.mockCall(permit2, 0, datas[0], '');
        vm.mockCall(permit2, 0, datas[1], '');
        // Mock the call to router getting fee rate and fee collector
        vm.etch(router, 'code');
        agent.execute(datas, logicsEmpty, tokensReturnEmpty);
        agent.executeWithSignerFee(datas, logicsEmpty, feesEmpty, tokensReturnEmpty);
        vm.stopPrank();
    }

    function testCannotExecuteByNotCallback() external {
        vm.expectRevert(IAgent.NotCallback.selector);
        vm.prank(router);
        agent.executeByCallback(logicsEmpty);
    }

    function testCannotBeInvalidBps() external {
        IParam.Logic[] memory logics = new IParam.Logic[](1);
        IParam.Input[] memory inputs = new IParam.Input[](1);
        // Revert if balanceBps = BPS_BASE + 1
        inputs[0] = IParam.Input(
            address(0),
            BPS_BASE + 1, // balanceBps
            0 // amountOrOffset
        );
        logics[0] = IParam.Logic(
            address(0), // to
            '',
            inputs,
            IParam.WrapMode.NONE,
            address(0), // approveTo
            address(0) // callback
        );
        vm.expectRevert(IAgent.InvalidBps.selector);
        vm.prank(router);
        agent.execute(permit2DatasEmpty, logics, tokensReturnEmpty);
    }

    function testCannotUnresetCallbackWithCharge() external {
        IParam.Logic[] memory logics = new IParam.Logic[](1);
        logics[0] = IParam.Logic(
            address(mockFallback), // to
            '',
            inputsEmpty,
            IParam.WrapMode.NONE,
            address(0), // approveTo
            address(mockCallback) // callback
        );
        vm.expectRevert(IAgent.UnresetCallbackWithCharge.selector);
        vm.prank(router);
        agent.execute(permit2DatasEmpty, logics, tokensReturnEmpty);
    }

    function testWrapBeforeFixedAmounts(uint128 amount1, uint128 amount2) external {
        uint256 amount = uint256(amount1) + uint256(amount2);
        deal(router, amount);
        IParam.Logic[] memory logics = new IParam.Logic[](1);
        IParam.Input[] memory inputs = new IParam.Input[](2);

        // Fixed amounts
        inputs[0] = IParam.Input(
            mockWrappedNative, // token
            BPS_NOT_USED, // balanceBps
            amount1 // amountOrOffset
        );
        inputs[1] = IParam.Input(
            mockWrappedNative, // token
            BPS_NOT_USED, // balanceBps
            amount2 // amountOrOffset
        );
        logics[0] = IParam.Logic(
            address(mockFallback), // to
            '',
            inputs,
            IParam.WrapMode.WRAP_BEFORE,
            address(0), // approveTo
            address(0) // callback
        );
        if (amount > 0) {
            vm.expectEmit(true, true, true, true, mockWrappedNative);
            emit Approval(address(agent), address(mockFallback), type(uint256).max);
        }
        vm.prank(router);
        agent.execute{value: amount}(permit2DatasEmpty, logics, tokensReturnEmpty);
        assertEq(IERC20(mockWrappedNative).balanceOf(address(agent)), amount);
    }

    function testWrapBeforeReplacedAmounts(uint256 amount, uint256 bps) external {
        amount = bound(amount, 0, type(uint256).max / BPS_BASE); // Prevent overflow when calculates the replaced amount
        bps = bound(bps, 1, BPS_BASE - 1);
        deal(router, amount);
        IParam.Logic[] memory logics = new IParam.Logic[](1);
        IParam.Input[] memory inputs = new IParam.Input[](2);

        // Replaced amounts
        inputs[0] = IParam.Input(
            mockWrappedNative, // token
            bps, // balanceBps
            OFFSET_NOT_USED // amountOrOffset
        );
        inputs[1] = IParam.Input(
            mockWrappedNative, // token
            BPS_BASE - bps, // balanceBps
            OFFSET_NOT_USED // amountOrOffset
        );
        logics[0] = IParam.Logic(
            address(mockFallback), // to
            '',
            inputs,
            IParam.WrapMode.WRAP_BEFORE,
            address(0), // approveTo
            address(0) // callback
        );

        // Both replaced amounts are 0 when amount is 1
        if (amount > 1) {
            vm.expectEmit(true, true, true, true, mockWrappedNative);
            emit Approval(address(agent), address(mockFallback), type(uint256).max);
        }
        vm.prank(router);
        agent.execute{value: amount}(permit2DatasEmpty, logics, tokensReturnEmpty);
        assertApproxEqAbs(IERC20(mockWrappedNative).balanceOf(address(agent)), amount, 1); // 1 unit due to BPS_BASE / 2
    }

    function testWrapBeforeWithToken(uint256 amount1, uint256 amount2) external {
        deal(router, amount1);
        deal(address(mockERC20), address(agent), amount2);
        IParam.Logic[] memory logics = new IParam.Logic[](1);
        IParam.Input[] memory inputs = new IParam.Input[](2);

        // The inputs contain native and ERC-20
        inputs[0] = IParam.Input(
            mockWrappedNative, // token
            BPS_NOT_USED, // balanceBps
            amount1 // amountOrOffset
        );
        inputs[1] = IParam.Input(
            address(mockERC20), // token
            BPS_NOT_USED, // balanceBps
            amount2 // amountOrOffset
        );
        logics[0] = IParam.Logic(
            address(mockFallback), // to
            '',
            inputs,
            IParam.WrapMode.WRAP_BEFORE,
            address(0), // approveTo
            address(0) // callback
        );
        vm.prank(router);
        agent.execute{value: amount1}(permit2DatasEmpty, logics, tokensReturnEmpty);
        assertEq(IERC20(mockWrappedNative).balanceOf(address(agent)), amount1);
        assertEq(IERC20(mockERC20).balanceOf(address(agent)), amount2);
    }

    function testUnwrapAfter(uint128 amount, uint128 amountBefore) external {
        deal(router, amount);
        deal(mockWrappedNative, address(agent), amountBefore); // Ensure agent handles differences
        IParam.Logic[] memory logics = new IParam.Logic[](1);
        IParam.Input[] memory inputs = new IParam.Input[](1);

        // Wrap native and immediately unwrap after
        inputs[0] = IParam.Input(
            NATIVE, // token
            BPS_NOT_USED, // balanceBps
            amount // amountOrOffset
        );
        logics[0] = IParam.Logic(
            address(mockWrappedNative), // to
            abi.encodeWithSelector(IWrappedNative.deposit.selector),
            inputs,
            IParam.WrapMode.UNWRAP_AFTER,
            address(0), // approveTo
            address(0) // callback
        );

        vm.prank(router);
        agent.execute{value: amount}(permit2DatasEmpty, logics, tokensReturnEmpty);
        assertEq((address(agent).balance), amount);
        assertEq(IERC20(mockWrappedNative).balanceOf(address(agent)), amountBefore);
    }

    function testSendNative(uint256 amountIn, uint256 balanceBps) external {
        amountIn = bound(amountIn, 0, type(uint128).max);
        balanceBps = bound(balanceBps, 0, BPS_BASE);
        if (balanceBps == 0) balanceBps = BPS_NOT_USED;
        deal(router, amountIn);

        // Encode logics
        IParam.Logic[] memory logics = new IParam.Logic[](1);
        logics[0] = _logicSendNative(amountIn, balanceBps);

        // Execute
        vm.prank(router);
        agent.execute{value: amountIn}(permit2DatasEmpty, logics, tokensReturnEmpty);

        uint256 recipientAmount = amountIn;
        if (balanceBps != BPS_NOT_USED) recipientAmount = (amountIn * balanceBps) / BPS_BASE;
        assertEq(address(router).balance, 0);
        assertEq(recipient.balance, recipientAmount);
        assertEq(address(agent).balance, amountIn - recipientAmount);
    }

    function _logicSendNative(uint256 amountIn, uint256 balanceBps) internal view returns (IParam.Logic memory) {
        // Encode inputs
        IParam.Input[] memory inputs = new IParam.Input[](1);
        inputs[0].token = NATIVE;
        inputs[0].balanceBps = balanceBps;
        if (inputs[0].balanceBps == BPS_NOT_USED) inputs[0].amountOrOffset = amountIn;
        else inputs[0].amountOrOffset = OFFSET_NOT_USED; // data is not provided

        return
            IParam.Logic(
                address(recipient), // to
                '',
                inputs,
                IParam.WrapMode.NONE,
                address(0), // approveTo
                address(0) // callback
            );
    }

    function testApproveToIsDefault(uint256 amountIn) external {
        vm.assume(amountIn > 0);

        IParam.Logic[] memory logics = new IParam.Logic[](1);
        IParam.Input[] memory inputs = new IParam.Input[](1);

        inputs[0] = IParam.Input(
            address(mockERC20),
            BPS_NOT_USED, // balanceBps
            amountIn // amountOrOffset
        );
        logics[0] = IParam.Logic(
            address(mockFallback), // to
            '',
            inputs,
            IParam.WrapMode.NONE,
            address(0), // approveTo
            address(0) // callback
        );

        // Execute
        vm.expectEmit(true, true, true, true, address(mockERC20));
        emit Approval(address(agent), address(mockFallback), type(uint256).max);
        vm.prank(router);
        agent.execute(permit2DatasEmpty, logics, tokensReturnEmpty);

        // Execute again, mock approve to guarantee that approval is not called
        vm.mockCall(
            address(mockERC20),
            0,
            abi.encodeCall(IERC20.approve, (address(mockFallback), type(uint256).max)),
            abi.encode(false)
        );
        vm.prank(router);
        agent.execute(permit2DatasEmpty, logics, tokensReturnEmpty);
    }

    function testApproveToIsSet(uint256 amountIn, address approveTo) external {
        vm.assume(amountIn > 0);
        vm.assume(approveTo != address(0) && approveTo != mockFallback && approveTo != address(mockERC20));

        IParam.Logic[] memory logics = new IParam.Logic[](1);
        IParam.Input[] memory inputs = new IParam.Input[](1);

        inputs[0] = IParam.Input(
            address(mockERC20),
            BPS_NOT_USED, // balanceBps
            amountIn // amountOrOffset
        );
        logics[0] = IParam.Logic(
            address(mockFallback), // to
            '',
            inputs,
            IParam.WrapMode.NONE,
            approveTo, // approveTo
            address(0) // callback
        );

        // Execute
        vm.expectEmit(true, true, true, true, address(mockERC20));
        emit Approval(address(agent), approveTo, type(uint256).max);
        vm.prank(router);
        agent.execute(permit2DatasEmpty, logics, tokensReturnEmpty);

        // Execute again, mock approve to guarantee that approval is not called
        vm.mockCall(
            address(mockERC20),
            0,
            abi.encodeCall(IERC20.approve, (address(mockERC20), type(uint256).max)),
            abi.encode(false)
        );
        vm.prank(router);
        agent.execute(permit2DatasEmpty, logics, tokensReturnEmpty);
    }
}
