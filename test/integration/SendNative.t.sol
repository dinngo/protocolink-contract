// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {Router, IRouter} from '../../src/Router.sol';
import {UtilityNativeRelay, IUtilityNativeRelay} from '../../src/utility/UtilityNativeRelay.sol';
import {AddressBuilder} from '../utils/AddressBuilder.sol';
import {AmountBuilder} from '../utils/AmountBuilder.sol';

contract SendNativeTest is Test {
    using AddressBuilder for address[];
    using AmountBuilder for uint256[];

    address private constant NATIVE = address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);
    uint256 public constant SKIP = type(uint256).max;

    address public user;
    address public address0;
    address public address1;
    IRouter public router;
    IUtilityNativeRelay public relay;

    // Empty arrays
    address[] tokensReturnEmpty;
    IRouter.Output[] outputsEmpty;

    function setUp() external {
        user = makeAddr('User');
        address0 = makeAddr('address0');
        address1 = makeAddr('address1');
        router = new Router();
        relay = new UtilityNativeRelay();

        vm.label(address(router), 'Router');
        vm.label(address(relay), 'UtilityNativeRelay');
    }

    function testSendNative(uint256 amount) external {
        amount = bound(amount, 1e1, 1e12);
        deal(user, amount);

        // Encode logics
        IRouter.Logic[] memory logics = new IRouter.Logic[](1);
        logics[0] = _logicSendNative(address0, amount);

        // Execute
        vm.prank(user);
        router.execute{value: amount}(logics, tokensReturnEmpty);

        assertEq(address(router).balance, 0);
        assertEq(address0.balance, amount);
        assertEq(user.balance, 0);
    }

    function testMultiSendFixedAmount(uint256 amount) external {
        amount = bound(amount, 1e1, 1e12);
        uint256 count = 2;
        uint256 totalAmount = amount * count;
        deal(user, totalAmount);

        // Encode logics
        address payable[] memory recipents = AddressBuilder.fill(1, address0).push(address1).toPayable();
        IRouter.Logic[] memory logics = new IRouter.Logic[](1);
        logics[0] = _logicMultiSendFixedAmount(recipents, amount, totalAmount);

        // Execute
        vm.prank(user);
        router.execute{value: totalAmount}(logics, tokensReturnEmpty);

        assertEq(address(router).balance, 0);
        assertEq(address0.balance, amount);
        assertEq(address1.balance, amount);
        assertEq(user.balance, 0);
    }

    function testMultiSendDiffAmount(uint256 amount1, uint256 amount2) external {
        amount1 = bound(amount1, 1e1, 1e12);
        amount2 = bound(amount2, 1e1, 1e12);
        uint256 totalAmount = amount1 + amount2;
        deal(user, totalAmount);

        // Encode logics
        address payable[] memory recipents = AddressBuilder.fill(1, address0).push(address1).toPayable();
        uint256[] memory amounts = AmountBuilder.fill(1, amount1).push(amount2);
        IRouter.Logic[] memory logics = new IRouter.Logic[](1);
        logics[0] = _logicMultiSendDiffAmount(recipents, amounts, totalAmount);

        // Execute
        vm.prank(user);
        router.execute{value: totalAmount}(logics, tokensReturnEmpty);

        assertEq(address(router).balance, 0);
        assertEq(address0.balance, amount1);
        assertEq(address1.balance, amount2);
        assertEq(user.balance, 0);
    }

    function _logicSendNative(address recipient, uint256 amount) public view returns (IRouter.Logic memory) {
        return _logicBuilderNativeRelay(abi.encodeWithSelector(relay.send.selector, recipient, amount), amount);
    }

    function _logicMultiSendFixedAmount(
        address payable[] memory recipients,
        uint256 amount,
        uint256 inputAmount
    ) public view returns (IRouter.Logic memory) {
        return
            _logicBuilderNativeRelay(
                abi.encodeWithSelector(relay.multiSendFixedAmount.selector, recipients, amount),
                inputAmount
            );
    }

    function _logicMultiSendDiffAmount(
        address payable[] memory recipients,
        uint256[] memory amounts,
        uint256 inputAmount
    ) public view returns (IRouter.Logic memory) {
        return
            _logicBuilderNativeRelay(
                abi.encodeWithSelector(relay.multiSendDiffAmount.selector, recipients, amounts),
                inputAmount
            );
    }

    function _logicBuilderNativeRelay(
        bytes memory data,
        uint256 inputAmount
    ) public view returns (IRouter.Logic memory) {
        IRouter.Input[] memory inputs = new IRouter.Input[](1);
        inputs[0] = IRouter.Input(NATIVE, SKIP, inputAmount);
        return
            IRouter.Logic(
                address(relay), // to
                data,
                inputs,
                outputsEmpty,
                address(0), // approveTo
                address(0) // callback
            );
    }
}
