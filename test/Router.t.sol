// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {SafeERC20, IERC20} from 'openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol';
import {ERC20} from 'openzeppelin-contracts/contracts/token/ERC20/ERC20.sol';
import {Router, IRouter} from '../src/Router.sol';
import {MockBlank} from './mocks/MockBlank.sol';
import {ICallback, MockCallback} from './mocks/MockCallback.sol';

contract RouterTest is Test {
    using SafeERC20 for IERC20;

    uint256 public constant BPS_BASE = 10_000;
    uint256 public constant SKIP = type(uint256).max;

    address public user;
    IRouter public router;
    IERC20 public mockERC20;
    ICallback public mockCallback;
    address public mockTo;

    // Empty arrays
    address[] tokensReturnEmpty;
    IRouter.Input[] inputsEmpty;
    IRouter.Output[] outputsEmpty;

    event Approval(address indexed owner, address indexed spender, uint256 value);

    function setUp() external {
        user = makeAddr('User');

        router = new Router();
        mockERC20 = new ERC20('mockERC20', 'mock');
        mockCallback = new MockCallback();
        mockTo = address(new MockBlank());

        // Mock `Logic.to`
        vm.mockCall(mockTo, 0, abi.encodeWithSignature('dummy()'), new bytes(0));

        vm.label(address(router), 'Router');
    }

    function testCannotExecuteByInvalidCallback() external {
        IRouter.Logic[] memory callbacks = new IRouter.Logic[](1);
        callbacks[0] = IRouter.Logic(
            address(mockTo), // to
            abi.encodeWithSignature('dummy()'),
            inputsEmpty,
            outputsEmpty,
            address(0), // approveTo
            address(0) // callback
        );
        bytes memory data = abi.encodeWithSelector(IRouter.execute.selector, callbacks, tokensReturnEmpty);
        IRouter.Logic[] memory logics = new IRouter.Logic[](1);
        logics[0] = IRouter.Logic(
            address(mockCallback),
            abi.encodeWithSelector(ICallback.callback.selector, data),
            inputsEmpty,
            outputsEmpty,
            address(0), // approveTo
            address(router) // callback
        );
        vm.expectRevert(IRouter.InvalidCallback.selector);
        router.execute(logics, tokensReturnEmpty);
    }

    function testCannotEncodeApproveSig() external {
        IRouter.Logic[] memory logics = new IRouter.Logic[](1);
        logics[0] = IRouter.Logic(
            address(mockERC20), // to
            abi.encodeWithSelector(IERC20.approve.selector, user, 0),
            inputsEmpty,
            outputsEmpty,
            address(0), // approveTo
            address(0) // callback
        );

        vm.expectRevert(IRouter.InvalidERC20Sig.selector);
        router.execute(logics, tokensReturnEmpty);
    }

    function testCannotEncodeTransferFromSig() external {
        IRouter.Logic[] memory logics = new IRouter.Logic[](1);
        logics[0] = IRouter.Logic(
            address(mockERC20), // to
            abi.encodeWithSelector(IERC20.transferFrom.selector, user, 0),
            inputsEmpty,
            outputsEmpty,
            address(0), // approveTo
            address(0) // callback
        );

        vm.expectRevert(IRouter.InvalidERC20Sig.selector);
        router.execute(logics, tokensReturnEmpty);
    }

    function testCannotBeInvalidBps() external {
        IRouter.Logic[] memory logics = new IRouter.Logic[](1);
        IRouter.Input[] memory inputs = new IRouter.Input[](1);

        // Revert if amountBps = 0
        inputs[0] = IRouter.Input(
            address(0),
            0, // amountBps
            0 // amountOrOffset
        );
        logics[0] = IRouter.Logic(
            address(0), // to
            '',
            inputs,
            outputsEmpty,
            address(0), // approveTo
            address(0) // callback
        );
        vm.expectRevert(IRouter.InvalidBps.selector);
        router.execute(logics, tokensReturnEmpty);

        // Revert if amountBps = BPS_BASE + 1
        inputs[0] = IRouter.Input(
            address(0),
            BPS_BASE + 1, // amountBps
            0 // amountOrOffset
        );
        logics[0] = IRouter.Logic(
            address(0), // to
            '',
            inputs,
            outputsEmpty,
            address(0), // approveTo
            address(0) // callback
        );
        vm.expectRevert(IRouter.InvalidBps.selector);
        router.execute(logics, tokensReturnEmpty);
    }

    function testCannotUnresetCallback() external {
        IRouter.Logic[] memory logics = new IRouter.Logic[](1);
        logics[0] = IRouter.Logic(
            address(mockTo), // to
            abi.encodeWithSignature('dummy()'),
            inputsEmpty,
            outputsEmpty,
            address(0), // approveTo
            address(router) // callback
        );
        vm.expectRevert(IRouter.UnresetCallback.selector);
        router.execute(logics, tokensReturnEmpty);
    }

    function testCannotReceiveLessOutputToken() external {
        IERC20 tokenOut = mockERC20;
        uint256 amountMin = 1 ether;
        IRouter.Logic[] memory logics = new IRouter.Logic[](1);
        IRouter.Output[] memory outputs = new IRouter.Output[](1);

        // Output token already exists in router
        deal(address(tokenOut), address(router), 10 ether);

        outputs[0] = IRouter.Output(address(tokenOut), amountMin);

        // Receive 0 output token
        logics[0] = IRouter.Logic(
            address(mockTo), // to
            abi.encodeWithSignature('dummy()'),
            inputsEmpty,
            outputs,
            address(0), // approveTo
            address(0) // callback
        );

        // Execute
        address[] memory tokensReturn = new address[](1);
        tokensReturn[0] = address(tokenOut);
        vm.expectRevert(abi.encodeWithSelector(IRouter.InsufficientBalance.selector, address(tokenOut), amountMin, 0));
        router.execute(logics, tokensReturn);
    }

    function testApproveToIsDefault(uint256 amountIn) external {
        vm.assume(amountIn > 0);

        IRouter.Logic[] memory logics = new IRouter.Logic[](1);
        IRouter.Input[] memory inputs = new IRouter.Input[](1);

        inputs[0] = IRouter.Input(
            address(mockERC20),
            SKIP, // amountBps
            amountIn // amountOrOffset
        );
        logics[0] = IRouter.Logic(
            address(mockTo), // to
            abi.encodeWithSignature('dummy()'),
            inputs,
            outputsEmpty,
            address(0), // approveTo
            address(0) // callback
        );

        // Execute
        vm.expectEmit(true, true, true, true, address(mockERC20));
        emit Approval(address(router), address(mockTo), amountIn);
        vm.expectEmit(true, true, true, true, address(mockERC20));
        emit Approval(address(router), address(mockTo), 0);
        vm.prank(user);
        router.execute(logics, tokensReturnEmpty);
    }

    function testApproveToIsSet(uint256 amountIn, address approveTo) external {
        vm.assume(amountIn > 0);
        vm.assume(approveTo != address(0) && approveTo != mockTo && approveTo != address(mockERC20));

        IRouter.Logic[] memory logics = new IRouter.Logic[](1);
        IRouter.Input[] memory inputs = new IRouter.Input[](1);

        inputs[0] = IRouter.Input(
            address(mockERC20),
            SKIP, // amountBps
            amountIn // amountOrOffset
        );
        logics[0] = IRouter.Logic(
            address(mockTo), // to
            abi.encodeWithSignature('dummy()'),
            inputs,
            outputsEmpty,
            approveTo, // approveTo
            address(0) // callback
        );

        // Execute
        vm.expectEmit(true, true, true, true, address(mockERC20));
        emit Approval(address(router), approveTo, amountIn);
        vm.expectEmit(true, true, true, true, address(mockERC20));
        emit Approval(address(router), approveTo, 0);
        vm.prank(user);
        router.execute(logics, tokensReturnEmpty);
    }
}
