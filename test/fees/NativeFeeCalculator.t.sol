// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {Router, IRouter} from '../../src/Router.sol';
import {IParam} from '../../src/interfaces/IParam.sol';
import {IAgent} from '../../src/interfaces/IAgent.sol';
import {NativeFeeCalculator} from '../../src/fees/NativeFeeCalculator.sol';
import {IFeeCalculator} from '../../src/interfaces/IFeeCalculator.sol';

interface IFeeBase {
    function setFeeRate(uint256 feeRate_) external;
}

contract NativeFeeCalculatorTest is Test {
    address public constant NATIVE = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    bytes4 public constant NATIVE_FEE_SELECTOR = 0xeeeeeeee;
    bytes public constant EMPTY_LOGIC_DATA = new bytes(0);
    uint256 public constant ZERO_FEE_RATE = 0;
    uint256 public constant SKIP = type(uint256).max;
    uint256 public constant BPS_BASE = 10_000;

    address public user;
    address public receiver;
    address public feeCollector;
    IRouter public router;
    IAgent public userAgent;
    IFeeCalculator public feeCalculator;

    // Empty arrays
    address[] tokensReturnEmpty;

    function setUp() external {
        user = makeAddr('User');
        receiver = makeAddr('Receiver');
        feeCollector = makeAddr('FeeCollector');
        address pauser = makeAddr('Pauser');
        router = new Router(pauser, feeCollector);
        userAgent = IAgent(router.newAgent());

        // Deploy native fee calculator
        feeCalculator = new NativeFeeCalculator(address(router), ZERO_FEE_RATE);

        // Setup native fee calculator
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = NATIVE_FEE_SELECTOR;
        address[] memory feeCalculators = new address[](1);
        feeCalculators[0] = address(feeCalculator);
        router.setFeeCalculators(selectors, feeCalculators);

        vm.label(address(router), 'Router');
        vm.label(address(userAgent), 'UserAgent');
        vm.label(feeCollector, 'FeeCollector');
        vm.label(address(feeCalculator), 'FeeCalculator');
    }

    function testZeroNativeFee(uint256 value) external {
        value = bound(value, 1e3, 1e8 ether);

        // Encode logic
        IParam.Logic[] memory logics = new IParam.Logic[](1);
        logics[0] = _logicSendNative(value);

        // Get new logics and msg.value
        uint256 newValue;
        (logics, newValue) = router.getLogicsWithFee(logics, value);
        deal(user, newValue);

        uint256 receiverBalanceBefore = receiver.balance;
        uint256 feeCollectorBalanceBefore = feeCollector.balance;

        // Execute
        vm.prank(user);
        router.execute{value: newValue}(logics, tokensReturnEmpty);

        assertEq(address(router).balance, 0);
        assertEq(address(userAgent).balance, 0);
        assertEq(newValue, value);
        assertEq(receiver.balance - receiverBalanceBefore, value);
        assertEq(feeCollectorBalanceBefore, feeCollector.balance);
    }

    function testDynamicNativeFee(uint256 value, uint256 feeRate) external {
        value = bound(value, 1e10, 1e8 ether);
        feeRate = bound(feeRate, 1, BPS_BASE - 1);

        // Set fee
        IFeeBase(address(feeCalculator)).setFeeRate(feeRate);

        // Encode logic
        IParam.Logic[] memory logics = new IParam.Logic[](1);
        logics[0] = _logicSendNative(value);

        // Get new logics and msg.value
        uint256 newValue;
        (logics, newValue) = router.getLogicsWithFee(logics, value);
        deal(user, newValue);

        // Prepare assert data
        uint256 receiverBalanceBefore = receiver.balance;
        uint256 feeCollectorBalanceBefore = feeCollector.balance;
        uint256 expectedFee = _calculateFee(newValue, feeRate);

        // Execute
        vm.prank(user);
        router.execute{value: newValue}(logics, tokensReturnEmpty);

        assertEq(address(router).balance, 0);
        assertEq(address(userAgent).balance, 0);
        assertEq(newValue - expectedFee, value);
        assertEq(receiver.balance - receiverBalanceBefore, value);
        assertEq(feeCollector.balance - feeCollectorBalanceBefore, expectedFee);
    }

    function _logicSendNative(uint256 amount) internal view returns (IParam.Logic memory) {
        // Encode inputs
        IParam.Input[] memory inputs = new IParam.Input[](1);
        inputs[0].token = NATIVE;
        inputs[0].amountBps = SKIP;
        inputs[0].amountOrOffset = amount;

        return
            IParam.Logic(
                receiver,
                EMPTY_LOGIC_DATA,
                inputs,
                address(0), // approveTo
                address(0) // callback
            );
    }

    function _calculateFee(uint256 amount, uint256 feeRate) internal pure returns (uint256) {
        return (amount * feeRate) / (BPS_BASE + feeRate);
    }
}
