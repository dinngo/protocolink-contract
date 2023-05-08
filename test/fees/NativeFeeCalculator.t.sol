// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {Router} from 'src/Router.sol';
import {FeeCalculatorBase} from 'src/fees/FeeCalculatorBase.sol';
import {NativeFeeCalculator} from 'src/fees/NativeFeeCalculator.sol';
import {IParam} from 'src/interfaces/IParam.sol';
import {IAgent} from 'src/interfaces/IAgent.sol';

contract NativeFeeCalculatorTest is Test {
    event FeeCharged(address indexed token, uint256 amount, bytes32 metadata);

    address public constant NATIVE = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address public constant DUMMY_TO_ADDRESS = address(0);
    bytes4 public constant NATIVE_FEE_SELECTOR = 0xeeeeeeee;
    bytes public constant EMPTY_LOGIC_DATA = new bytes(0);
    uint256 public constant SKIP = 0x8000000000000000000000000000000000000000000000000000000000000000;
    uint256 public constant SIGNER_REFERRAL = 1;
    uint256 public constant BPS_BASE = 10_000;
    bytes32 public constant META_DATA = bytes32(bytes('native-token'));

    address public user;
    address public receiver;
    address public feeCollector;
    Router public router;
    IAgent public userAgent;
    address public nativeFeeCalculator;

    // Empty arrays
    address[] public tokensReturnEmpty;

    function setUp() external {
        user = makeAddr('User');
        receiver = makeAddr('Receiver');
        feeCollector = makeAddr('FeeCollector');
        address pauser = makeAddr('Pauser');
        router = new Router(makeAddr('WrappedNative'), pauser, feeCollector);
        vm.prank(user);
        userAgent = IAgent(router.newAgent());

        // Deploy native fee calculator
        nativeFeeCalculator = address(new NativeFeeCalculator(address(router), 0));

        // Setup native fee calculator
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = NATIVE_FEE_SELECTOR;
        address[] memory tos = new address[](1);
        tos[0] = address(DUMMY_TO_ADDRESS);
        address[] memory feeCalculators = new address[](1);
        feeCalculators[0] = nativeFeeCalculator;
        router.setFeeCalculators(selectors, tos, feeCalculators);

        vm.label(address(router), 'Router');
        vm.label(address(userAgent), 'UserAgent');
        vm.label(feeCollector, 'FeeCollector');
        vm.label(nativeFeeCalculator, 'NativeFeeCalculator');
    }

    function testChargeNativeFee(uint256 value, uint256 feeRate) external {
        value = bound(value, 1e10, 1e8 ether);
        feeRate = bound(feeRate, 0, BPS_BASE - 1);

        // Set fee rate
        FeeCalculatorBase(nativeFeeCalculator).setFeeRate(feeRate);

        // Encode logic
        IParam.Logic[] memory logics = new IParam.Logic[](1);
        logics[0] = _logicSendNative(value);

        // Get new logics and msgValue
        uint256 newValue;
        (logics, newValue) = router.getUpdatedLogicsAndMsgValue(logics, value);
        deal(user, newValue);

        // Prepare assert data
        uint256 receiverBalanceBefore = receiver.balance;
        uint256 feeCollectorBalanceBefore = feeCollector.balance;
        uint256 expectedFee = FeeCalculatorBase(nativeFeeCalculator).calculateFee(newValue);

        // Execute
        vm.expectEmit(true, true, true, true, address(userAgent));
        emit FeeCharged(NATIVE, expectedFee, META_DATA);
        vm.prank(user);
        router.execute{value: newValue}(logics, tokensReturnEmpty, SIGNER_REFERRAL);

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
                IParam.WrapMode.NONE,
                address(0), // approveTo
                address(0) // callback
            );
    }
}
