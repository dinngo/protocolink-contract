// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {SafeCast} from 'openzeppelin-contracts/contracts/utils/math/SafeCast.sol';
import {Test} from 'forge-std/Test.sol';
import {ERC20, IERC20} from 'openzeppelin-contracts/contracts/token/ERC20/ERC20.sol';
import {DataType} from 'src/libraries/DataType.sol';
import {FeeLibrary} from 'src/libraries/FeeLibrary.sol';
import {MockFeeLibrary} from './mocks/MockFeeLibrary.sol';
import 'forge-std/console.sol';

contract FeeLibraryTest is Test {
    using FeeLibrary for DataType.Fee;
    using SafeCast for uint256;

    IERC20 public mockERC20;
    address public user;
    address public feeCollector;
    address public permit2;
    bytes32 public metadata = bytes32(bytes('metadata'));
    MockFeeLibrary public mock;

    event Charged(address indexed token, uint256 amount, bytes32 metadata);

    function setUp() public {
        mockERC20 = new ERC20('mockERC20', 'mock');
        user = address(this);
        feeCollector = makeAddr('feeCollector');
        permit2 = makeAddr('permit2');
        mock = new MockFeeLibrary();
        vm.label(address(mockERC20), 'mERC20');
    }

    function testPayNative(uint256 amount) public {
        amount = bound(amount, 1, 5000 ether);
        deal(address(mock), amount);
        DataType.Fee memory fee = DataType.Fee(FeeLibrary.NATIVE, amount, metadata);
        vm.expectEmit(true, true, true, true, address(mock));
        emit Charged(FeeLibrary.NATIVE, amount, metadata);
        mock.pay(fee, feeCollector);
        assertEq(feeCollector.balance, amount);
    }

    function testPayERC20(uint256 amount) public {
        amount = bound(amount, 1, 5000e18);
        deal(address(mockERC20), address(mock), amount);
        DataType.Fee memory fee = DataType.Fee(address(mockERC20), amount, metadata);
        vm.expectEmit(true, true, true, true, address(mock));
        emit Charged(address(mockERC20), amount, metadata);
        mock.pay(fee, feeCollector);
        assertEq(mockERC20.balanceOf(feeCollector), amount);
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
            abi.encodeWithSelector(0x36c78516, user, feeCollector, amount.toUint160(), address(mockERC20)),
            ''
        );
        vm.expectEmit(true, true, true, true, address(mock));
        emit Charged(address(mockERC20), amount, metadata);
        mock.payFrom(fee, user, feeCollector, permit2);
    }
}
