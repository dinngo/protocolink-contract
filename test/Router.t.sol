// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {SafeERC20, IERC20} from 'openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol';
import {Router, IRouter} from '../src/Router.sol';
import {SpenderERC20Approval, ISpenderERC20Approval} from '../src/SpenderERC20Approval.sol';
import {MockERC20} from './mocks/MockERC20.sol';
import {ICallback, MockCallback} from './mocks/MockCallback.sol';

contract RouterTest is Test {
    using SafeERC20 for IERC20;

    uint256 public constant BPS_BASE = 10_000;

    address public user;
    IRouter public router;
    ISpenderERC20Approval public spender;
    IERC20 public mockERC20;
    ICallback public mockCallback;

    // Empty arrays
    address[] tokensReturnEmpty;
    IRouter.Input[] inputsEmpty;
    IRouter.Output[] outputsEmpty;

    function setUp() external {
        user = makeAddr('User');

        router = new Router();
        spender = new SpenderERC20Approval(address(router));
        mockERC20 = new MockERC20('Mock ERC20', 'mERC20');
        mockCallback = new MockCallback();

        // User approved spender
        vm.startPrank(user);
        mockERC20.safeApprove(address(spender), type(uint256).max);
        vm.stopPrank();

        vm.label(address(router), 'Router');
        vm.label(address(spender), 'SpenderERC20Approval');
        vm.label(address(mockERC20), 'mERC20');
        vm.label(address(mockCallback), 'mCallback');
    }

    function testCannotExecuteByInvalidCallback() external {
        IRouter.Logic[] memory callbacks = new IRouter.Logic[](1);
        callbacks[0] = IRouter.Logic(
            address(mockERC20), // to
            abi.encodeWithSelector(IERC20.totalSupply.selector),
            inputsEmpty,
            outputsEmpty,
            address(0) // callback
        );
        bytes memory data = abi.encodeWithSelector(IRouter.execute.selector, callbacks, tokensReturnEmpty);
        IRouter.Logic[] memory logics = new IRouter.Logic[](1);
        logics[0] = IRouter.Logic(
            address(mockCallback),
            abi.encodeWithSelector(ICallback.callback.selector, data),
            inputsEmpty,
            outputsEmpty,
            address(router)
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
            0,
            false
        );
        logics[0] = IRouter.Logic(
            address(0), // to
            '',
            inputs,
            outputsEmpty,
            address(0) // callback
        );
        vm.expectRevert(IRouter.InvalidBps.selector);
        router.execute(logics, tokensReturnEmpty);

        // Revert if amountBps = BPS_BASE + 1
        inputs[0] = IRouter.Input(
            address(0),
            BPS_BASE + 1, // amountBps
            0,
            false
        );
        logics[0] = IRouter.Logic(
            address(0), // to
            '',
            inputs,
            outputsEmpty,
            address(0) // callback
        );
        vm.expectRevert(IRouter.InvalidBps.selector);
        router.execute(logics, tokensReturnEmpty);
    }

    function testCannotUnresetCallback() external {
        IRouter.Logic[] memory logics = new IRouter.Logic[](1);
        logics[0] = IRouter.Logic(
            address(mockERC20), // to
            abi.encodeWithSelector(IERC20.totalSupply.selector),
            inputsEmpty,
            outputsEmpty,
            address(router) // callback
        );
        vm.expectRevert(IRouter.UnresetCallback.selector);
        router.execute(logics, tokensReturnEmpty);
    }
}
