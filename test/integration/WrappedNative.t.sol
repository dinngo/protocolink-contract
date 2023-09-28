// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {IERC20} from 'lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol';
import {Router, IRouter} from 'src/Router.sol';
import {DataType} from 'src/libraries/DataType.sol';
import {IWrappedNative} from 'src/interfaces/IWrappedNative.sol';

// Test wrapped native
contract WrappedNativeTest is Test {
    address public constant NATIVE = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    IERC20 public constant WRAPPED_NATIVE = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    address public constant PERMIT2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;
    uint256 public constant BPS_BASE = 10_000;
    uint256 public constant BPS_NOT_USED = 0;
    uint256 public constant OFFSET_NOT_USED = 0x8000000000000000000000000000000000000000000000000000000000000000;

    address public user;
    IRouter public router;
    bytes[] public permit2DatasEmpty;

    function setUp() external {
        vm.createSelectFork(vm.rpcUrl('ethereum'));

        user = makeAddr('User');
        router = new Router(address(WRAPPED_NATIVE), address(PERMIT2), address(this));

        // Empty router the balance
        vm.prank(address(router));
        (bool success, ) = payable(address(0)).call{value: address(router).balance}('');
        assertTrue(success);

        vm.label(address(router), 'Router');
        vm.label(address(WRAPPED_NATIVE), 'WrappedNative');
    }

    function testExecuteWrappedNativeDeposit(uint256 amountIn) external {
        amountIn = bound(amountIn, BPS_BASE, WRAPPED_NATIVE.totalSupply());
        address tokenIn = NATIVE;
        IERC20 tokenOut = WRAPPED_NATIVE;
        deal(user, amountIn + 1 ether);

        // Encode logics
        DataType.Logic[] memory logics = new DataType.Logic[](1);
        logics[0] = _logicWrappedNativeDeposit(amountIn, BPS_BASE / 2); // 50% amount

        // Execute
        address[] memory tokensReturn = new address[](2);
        tokensReturn[0] = tokenIn;
        tokensReturn[1] = address(tokenOut);
        vm.prank(user);
        router.execute{value: amountIn}(permit2DatasEmpty, logics, tokensReturn);

        address agent = router.getAgent(user);
        assertEq(address(router).balance, 0);
        assertEq(address(agent).balance, 0);
        assertEq(tokenOut.balanceOf(address(router)), 0);
        assertEq(tokenOut.balanceOf(address(agent)), 0);
        assertGt(user.balance, 0);
        assertGt(tokenOut.balanceOf(user), 0);
    }

    function _logicWrappedNativeDeposit(
        uint256 amountIn,
        uint256 balanceBps
    ) public pure returns (DataType.Logic memory) {
        // Encode inputs
        DataType.Input[] memory inputs = new DataType.Input[](1);
        inputs[0].token = NATIVE;
        inputs[0].balanceBps = balanceBps;
        if (inputs[0].balanceBps == BPS_NOT_USED) inputs[0].amountOrOffset = amountIn;
        else inputs[0].amountOrOffset = OFFSET_NOT_USED; // data don't have amount parameter

        return
            DataType.Logic(
                address(WRAPPED_NATIVE), // to
                abi.encodeWithSelector(IWrappedNative.deposit.selector),
                inputs,
                DataType.WrapMode.NONE,
                address(0), // approveTo
                address(0) // callback
            );
    }
}
