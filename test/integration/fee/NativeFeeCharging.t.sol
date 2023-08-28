// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {Router} from 'src/Router.sol';
import {IParam} from 'src/interfaces/IParam.sol';
import {IAgent} from 'src/interfaces/IAgent.sol';
import {FeeLibrary} from 'src/libraries/FeeLibrary.sol';

contract NativeFeeCalculatorTest is Test {
    event FeeCharged(address indexed token, uint256 amount, bytes32 metadata);

    address public constant NATIVE = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address public constant ANY_TO_ADDRESS = address(0);
    bytes4 public constant NATIVE_FEE_SELECTOR = 0xeeeeeeee;
    bytes public constant EMPTY_LOGIC_DATA = new bytes(0);
    uint256 public constant BPS_NOT_USED = 0;
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
    bytes[] public datasEmpty;

    function setUp() external {
        user = makeAddr('User');
        receiver = makeAddr('Receiver');
        feeCollector = makeAddr('FeeCollector');
        address pauser = makeAddr('Pauser');

        router = new Router(makeAddr('WrappedNative'), makeAddr('Permit2'), address(this), pauser, feeCollector);
        vm.prank(user);
        userAgent = IAgent(router.newAgent());

        vm.label(address(router), 'Router');
        vm.label(address(userAgent), 'UserAgent');
        vm.label(feeCollector, 'FeeCollector');
    }

    function testChargeNativeFee(uint256 value, uint256 feeRate) external {
        value = bound(value, 0, 1e8 ether);
        feeRate = bound(feeRate, 0, BPS_BASE - 1);

        // Set fee rate
        router.setFeeRate(feeRate);

        // Encode logic
        uint256 newValue = FeeLibrary.calculateAmountWithFee(value, feeRate);
        IParam.Logic[] memory logics = new IParam.Logic[](1);
        logics[0] = _logicSendNative(value);

        // Get new logics and msgValue
        deal(user, newValue);

        // Prepare assert data
        uint256 receiverBalanceBefore = receiver.balance;
        uint256 feeCollectorBalanceBefore = feeCollector.balance;
        uint256 expectedFee = FeeLibrary.calculateFeeFromAmount(value, feeRate);

        // Execute
        if (expectedFee > 0) {
            vm.expectEmit(true, true, true, true, address(userAgent));
            emit FeeCharged(NATIVE, expectedFee, META_DATA);
        }
        vm.prank(user);
        router.execute{value: newValue}(datasEmpty, logics, tokensReturnEmpty, SIGNER_REFERRAL);

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
        inputs[0].balanceBps = BPS_NOT_USED;
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
