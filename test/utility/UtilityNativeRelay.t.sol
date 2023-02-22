// SPDX-License-Identify: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {UtilityNativeRelay, IUtilityNativeRelay} from '../../src/utility/UtilityNativeRelay.sol';
import {AddressBuilder} from '../utils/AddressBuilder.sol';
import {AmountBuilder} from '../utils/AmountBuilder.sol';

contract UtilityNativeRelayTest is Test {
    using AddressBuilder for address[];
    using AmountBuilder for uint256[];

    event Transfer(address indexed sender, uint256 receipientCount, uint256 totalValue);

    address public user;
    address public address0;
    address public address1;
    IUtilityNativeRelay public relay;

    function setUp() external {
        user = makeAddr('User');
        address0 = makeAddr('address0');
        address1 = makeAddr('address1');
        relay = new UtilityNativeRelay();
    }

    function testWithdraw(uint256 amount) external {
        amount = bound(amount, 1e1, 1e12);
        deal(address(relay), amount);
        uint256 initBalance = address(this).balance;
        relay.withdraw();

        assertEq(address(this).balance - initBalance, amount);
    }

    function testWithdtawNotOwner() external {
        vm.prank(user);
        vm.expectRevert('Ownable: caller is not the owner');
        relay.withdraw();
    }

    function testSend(uint256 amount) external {
        amount = bound(amount, 1e1, 1e12);
        deal(user, amount);

        vm.prank(user);
        vm.expectEmit(true, true, true, true);
        emit Transfer(user, 1, amount);
        relay.send{value: amount}(payable(address0), amount);

        assertEq(address0.balance, amount);
    }

    function testSendInvalidAmount() external {
        uint256 amount = 0;

        vm.prank(user);
        vm.expectRevert(IUtilityNativeRelay.InvalidAmount.selector);
        relay.send{value: amount}(payable(address0), amount);
    }

    function testSendInsufficientBalance() external {
        uint256 amount = 1;
        uint256 msgValue = 0;

        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(IUtilityNativeRelay.InsufficientBalance.selector, msgValue));
        relay.send{value: msgValue}(payable(address0), amount);
    }

    function testMultiSendFixedAmount(uint256 amount) external {
        amount = bound(amount, 1e1, 1e12);
        uint256 count = 2;
        uint256 totalAmount = amount * count;
        deal(user, totalAmount);
        address payable[] memory recipients = AddressBuilder.fill(1, address0).push(address1).toPayable();

        vm.prank(user);
        vm.expectEmit(true, true, true, true);
        emit Transfer(user, count, totalAmount);
        relay.multiSendFixedAmount{value: totalAmount}(recipients, amount);

        assertEq(address0.balance, amount);
        assertEq(address1.balance, amount);
    }

    function testMultiSendFixedAmountInvalidLength() external {
        uint256 amount = 0;
        address payable[] memory recipients = new address payable[](0);

        vm.prank(user);
        vm.expectRevert(IUtilityNativeRelay.InvalidLength.selector);
        relay.multiSendFixedAmount{value: amount}(recipients, amount);
    }

    function testMultiSendFixedAmountInvalidAmount() external {
        uint256 amount = 0;
        address payable[] memory recipients = AddressBuilder.fill(2, address0).toPayable();

        vm.prank(user);
        vm.expectRevert(IUtilityNativeRelay.InvalidAmount.selector);
        relay.multiSendFixedAmount{value: amount}(recipients, amount);
    }

    function testMultiSendFixedAmountInsufficientBalance() external {
        uint256 amount = 1;
        uint256 count = 5;
        uint256 totalAmount = amount * count - 1;
        deal(user, totalAmount);
        address payable[] memory recipients = AddressBuilder.fill(count, address0).toPayable();

        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(IUtilityNativeRelay.InsufficientBalance.selector, totalAmount));
        relay.multiSendFixedAmount{value: totalAmount}(recipients, amount);
    }

    function testMultiSendDiffAmount(uint256 amount) external {
        amount = bound(amount, 1e1, 1e12);
        uint256 count = 2;
        uint256 totalAmount = amount * count;
        deal(user, totalAmount);
        address payable[] memory recipients = AddressBuilder.fill(1, address0).push(address1).toPayable();
        uint256[] memory amounts = AmountBuilder.fill(count, amount);

        vm.prank(user);
        vm.expectEmit(true, true, true, true);
        emit Transfer(user, count, totalAmount);
        relay.multiSendDiffAmount{value: totalAmount}(recipients, amounts);

        assertEq(address0.balance, amount);
        assertEq(address1.balance, amount);
    }

    function testMultiSendDiffAmountInvalidLength() external {
        uint256 amount = 0;
        address payable[] memory recipients = new address payable[](0);
        uint256[] memory amounts = new uint256[](0);

        vm.prank(user);
        vm.expectRevert(IUtilityNativeRelay.InvalidLength.selector);
        relay.multiSendDiffAmount{value: amount}(recipients, amounts);
    }

    function testMultiSendDiffAmountLengthMismatch() external {
        uint256 amount = 0;
        address payable[] memory recipients = AddressBuilder.fill(1, address0).toPayable();
        uint256[] memory amounts = new uint256[](0);

        vm.prank(user);
        vm.expectRevert(IUtilityNativeRelay.LengthMismatch.selector);
        relay.multiSendDiffAmount{value: amount}(recipients, amounts);
    }

    function testMultiSendDiffAmountInvalidAmount() external {
        uint256 amount = 0;
        address payable[] memory recipients = AddressBuilder.fill(1, address0).toPayable();
        uint256[] memory amounts = AmountBuilder.fill(1, amount);

        vm.prank(user);
        vm.expectRevert(IUtilityNativeRelay.InvalidAmount.selector);
        relay.multiSendDiffAmount{value: amount}(recipients, amounts);
    }

    function testMultiSendDiffAmountInsufficientBalance() external {
        uint256 amount = 1;
        uint256 count = 5;
        uint256 totalAmount = amount * count - 1;
        deal(user, totalAmount);
        address payable[] memory recipients = AddressBuilder.fill(count, address0).toPayable();
        uint256[] memory amounts = AmountBuilder.fill(count, amount);

        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(IUtilityNativeRelay.InsufficientBalance.selector, totalAmount));
        relay.multiSendDiffAmount{value: totalAmount}(recipients, amounts);
    }

    receive() external payable {}
}
