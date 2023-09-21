// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {SafeCast} from 'lib/openzeppelin-contracts/contracts/utils/math/SafeCast.sol';
import {Test} from 'forge-std/Test.sol';
import {ERC20, IERC20} from 'lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol';
import {DataType} from 'src/libraries/DataType.sol';
import {FeeLibrary} from 'src/libraries/FeeLibrary.sol';
import {MockFeeLibrary} from './mocks/MockFeeLibrary.sol';

contract FeeLibraryTest is Test {
    using FeeLibrary for DataType.Fee;
    using SafeCast for uint256;

    uint256 public constant BPS_BASE = 10_000;

    IERC20 public mockERC20;
    address public user;
    address public defaultCollector;
    bytes32 public defaultReferral;
    address public referrer;
    address public permit2;
    bytes32 public metadata = bytes32(bytes('metadata'));
    MockFeeLibrary public mock;

    event Charged(address indexed token, uint256 amount, address indexed collector, bytes32 metadata);

    function setUp() public {
        mockERC20 = new ERC20('mockERC20', 'mock');
        user = address(this);
        defaultCollector = makeAddr('defaultCollector');
        defaultReferral = bytes32(bytes20(defaultCollector)) | bytes32(uint256(BPS_BASE));
        referrer = makeAddr('referrer');
        permit2 = makeAddr('permit2');
        mock = new MockFeeLibrary();
        vm.label(address(mockERC20), 'mERC20');
    }

    function testPayNative(uint256 amount) public {
        amount = bound(amount, 1, 5000 ether);
        deal(address(mock), amount);
        DataType.Fee memory fee = DataType.Fee(FeeLibrary.NATIVE, amount, metadata);
        vm.expectEmit(true, true, true, true, address(mock));
        emit Charged(FeeLibrary.NATIVE, amount, defaultCollector, metadata);
        mock.pay(fee, defaultReferral);
        assertEq(defaultCollector.balance, amount);
    }

    function testPayNativeWithReferral(uint256 amount, uint256 shareRate) public {
        amount = bound(amount, 1, 5000 ether);
        shareRate = bound(shareRate, 0, BPS_BASE);
        bytes32 referral = _getReferral(referrer, shareRate);
        uint256 expectedFee = (amount * shareRate) / BPS_BASE;
        deal(address(mock), amount);
        DataType.Fee memory fee = DataType.Fee(FeeLibrary.NATIVE, amount, metadata);
        if (expectedFee > 0) {
            vm.expectEmit(true, true, true, true, address(mock));
            emit Charged(FeeLibrary.NATIVE, expectedFee, referrer, metadata);
        }
        mock.pay(fee, referral);
        assertEq(referrer.balance, expectedFee);
        assertEq(defaultCollector.balance, 0);
    }

    function testPayERC20(uint256 amount) public {
        amount = bound(amount, 1, 5000e18);
        deal(address(mockERC20), address(mock), amount);
        DataType.Fee memory fee = DataType.Fee(address(mockERC20), amount, metadata);
        vm.expectEmit(true, true, true, true, address(mock));
        emit Charged(address(mockERC20), amount, defaultCollector, metadata);
        mock.pay(fee, defaultReferral);
        assertEq(mockERC20.balanceOf(defaultCollector), amount);
    }

    function testPayERC20WithReferral(uint256 amount, uint256 shareRate) public {
        amount = bound(amount, 1, 5000e18);
        shareRate = bound(shareRate, 0, BPS_BASE);
        bytes32 referral = _getReferral(referrer, shareRate);
        uint256 expectedFee = (amount * shareRate) / BPS_BASE;
        deal(address(mockERC20), address(mock), amount);
        DataType.Fee memory fee = DataType.Fee(address(mockERC20), amount, metadata);
        if (expectedFee > 0) {
            vm.expectEmit(true, true, true, true, address(mock));
            emit Charged(address(mockERC20), expectedFee, referrer, metadata);
        }
        mock.pay(fee, referral);
        assertEq(mockERC20.balanceOf(referrer), expectedFee);
        assertEq(mockERC20.balanceOf(defaultCollector), 0);
    }

    function testPayFromERC20(uint256 amount) public {
        amount = bound(amount, 1, 5000e18);
        deal(address(mockERC20), address(mock), amount);
        DataType.Fee memory fee = DataType.Fee(address(mockERC20), amount, metadata);
        // Mock call to permit2
        vm.etch(permit2, 'code');
        vm.mockCall(
            permit2,
            0,
            abi.encodeWithSelector(0x36c78516, user, defaultCollector, amount.toUint160(), address(mockERC20)),
            ''
        );
        vm.expectEmit(true, true, true, true, address(mock));
        emit Charged(address(mockERC20), amount, defaultCollector, metadata);
        mock.payFrom(fee, user, defaultReferral, permit2);
    }

    function testPayFromERC20WithReferral(uint256 amount, uint256 shareRate) public {
        amount = bound(amount, 1, 5000e18);
        shareRate = bound(shareRate, 0, BPS_BASE);
        bytes32 referral = _getReferral(referrer, shareRate);
        uint256 expectedFee = (amount * shareRate) / BPS_BASE;
        deal(address(mockERC20), address(mock), amount);
        DataType.Fee memory fee = DataType.Fee(address(mockERC20), amount, metadata);
        // Mock call to permit2
        vm.etch(permit2, 'code');
        vm.mockCall(
            permit2,
            0,
            abi.encodeWithSelector(0x36c78516, user, referrer, expectedFee.toUint160(), address(mockERC20)),
            ''
        );
        if (expectedFee > 0) {
            vm.expectEmit(true, true, true, true, address(mock));
            emit Charged(address(mockERC20), expectedFee, referrer, metadata);
        }
        mock.payFrom(fee, user, referral, permit2);
    }

    function _getReferral(address collector, uint256 rate) internal pure returns (bytes32) {
        require(rate <= BPS_BASE);
        return bytes32(bytes20(collector)) | bytes32(rate);
    }
}
