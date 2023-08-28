// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {IERC20} from 'openzeppelin-contracts/contracts/token/ERC20/IERC20.sol';
import {SafeCast160} from 'permit2/libraries/SafeCast160.sol';
import {Router} from 'src/Router.sol';
import {IParam} from 'src/interfaces/IParam.sol';
import {IAgent} from 'src/interfaces/IAgent.sol';
import {FeeLibrary} from 'src/libraries/FeeLibrary.sol';
import {ERC20Permit2Utils} from 'test/utils/ERC20Permit2Utils.sol';
import {TypedDataSignature} from 'test/utils/TypedDataSignature.sol';

contract Permit2FeeCalculatorTest is Test, ERC20Permit2Utils, TypedDataSignature {
    using SafeCast160 for uint256;

    event FeeCharged(address indexed token, uint256 amount, bytes32 metadata);

    bytes4 public constant PERMIT2_TRANSFER_FROM_SELECTOR =
        bytes4(keccak256(bytes('transferFrom(address,address,uint160,address)')));
    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public constant PERMIT2_ADDR = 0x000000000022D473030F116dDEE9F6B43aC78BA3;
    uint256 public constant BPS_BASE = 10_000;
    bytes32 public constant META_DATA = bytes32(bytes('permit2:pull-token'));
    uint256 internal constant _DUST = 10;

    address public user;
    uint256 public userPrivateKey;
    address public signer;
    uint256 public signerPrivateKey;
    address public feeCollector;
    Router public router;
    IAgent public userAgent;
    address public permit2FeeCalculator;
    IParam.Logic[] public logicsEmpty;

    function setUp() external {
        (user, userPrivateKey) = makeAddrAndKey('User');
        (signer, signerPrivateKey) = makeAddrAndKey('Signer');
        feeCollector = makeAddr('FeeCollector');

        // Deploy contracts
        router = new Router(makeAddr('WrappedNative'), PERMIT2_ADDR, address(this), makeAddr('Pauser'), feeCollector);
        vm.prank(user);
        userAgent = IAgent(router.newAgent());
        router.addSigner(signer);

        // Setup permit2
        erc20Permit2UtilsSetUp(user, userPrivateKey, address(userAgent));
        permitToken(IERC20(USDC));

        vm.label(address(router), 'Router');
        vm.label(address(userAgent), 'UserAgent');
        vm.label(feeCollector, 'FeeCollector');
        vm.label(PERMIT2_ADDR, 'Permit2');
    }

    function testChargePermit2TransferFromFeeFromAgent(uint256 amount, uint256 feeRate) external {
        feeRate = bound(feeRate, 0, BPS_BASE - 1);
        amount = bound(amount, 0, (IERC20(USDC).totalSupply() * (BPS_BASE - feeRate)) / BPS_BASE);

        // Set fee rate
        router.setFeeRate(feeRate);

        // Encode permit2Datas
        bytes[] memory datas = new bytes[](1);
        uint256 amountWithFee = FeeLibrary.calculateAmountWithFee(amount, feeRate);
        datas[0] = dataERC20Permit2PullToken(IERC20(USDC), amountWithFee.toUint160());

        // Prepare assert data
        uint256 expectedNewAmount = amountWithFee;
        uint256 expectedFee = amountWithFee - amount;
        uint256 newAmount = this.decodePermit2TransferFromAmount(datas[0]);
        uint256 feeCollectorBalanceBefore = IERC20(USDC).balanceOf(feeCollector);

        deal(USDC, user, newAmount);

        // Execute
        address[] memory tokensReturn = new address[](1);
        tokensReturn[0] = USDC;
        if (expectedFee > 0) {
            vm.expectEmit(true, true, true, true, address(userAgent));
            emit FeeCharged(USDC, expectedFee, META_DATA);
        }
        vm.prank(user);
        router.execute(datas, logicsEmpty, tokensReturn, SIGNER_REFERRAL);

        assertEq(IERC20(USDC).balanceOf(address(router)), 0);
        assertEq(IERC20(USDC).balanceOf(feeCollector) - feeCollectorBalanceBefore, expectedFee);
        if (amount > _DUST) {
            assertEq(IERC20(USDC).balanceOf(address(userAgent)), 0);
            assertEq(IERC20(USDC).balanceOf(user), amount);
        } else {
            assertLe(IERC20(USDC).balanceOf(address(userAgent)), _DUST);
            assertEq(IERC20(USDC).balanceOf(user), 0);
        }
        assertEq(newAmount, expectedNewAmount);
    }

    function testChargePermit2TransferFromFeeFromUser(uint256 amount, uint256 feeRate) external {
        feeRate = bound(feeRate, 0, BPS_BASE - 1);
        amount = bound(amount, 0, (IERC20(USDC).totalSupply() * (BPS_BASE - feeRate)) / BPS_BASE);

        // Set fee rate
        router.setFeeRate(feeRate);

        // Encode permit2Datas
        bytes[] memory datas = new bytes[](1);

        uint256 amountFee = FeeLibrary.calculateFeeFromAmount(amount, feeRate);

        datas[0] = dataERC20Permit2PullToken(IERC20(USDC), amount.toUint160());
        IParam.Fee[] memory fees = new IParam.Fee[](1);
        fees[0] = IParam.Fee(USDC, amountFee, META_DATA);

        // Prepare assert data
        uint256 expectedNewAmount = amount;
        uint256 expectedFee = amountFee;
        uint256 newAmount = this.decodePermit2TransferFromAmount(datas[0]);
        uint256 feeCollectorBalanceBefore = IERC20(USDC).balanceOf(feeCollector);

        deal(USDC, user, newAmount + amountFee);

        // Execute
        address[] memory tokensReturn = new address[](1);
        tokensReturn[0] = USDC;
        if (expectedFee > 0) {
            vm.expectEmit(true, true, true, true, address(userAgent));
            emit FeeCharged(USDC, expectedFee, META_DATA);
        }
        IParam.LogicBatch memory logicBatch = IParam.LogicBatch(logicsEmpty, fees, block.timestamp + 5);
        bytes memory signature = getTypedDataSignature(logicBatch, router.domainSeparator(), signerPrivateKey);
        vm.prank(user);
        router.executeWithSignerFee(datas, logicBatch, signer, signature, tokensReturn, SIGNER_REFERRAL);

        assertEq(IERC20(USDC).balanceOf(address(router)), 0);
        assertEq(IERC20(USDC).balanceOf(feeCollector) - feeCollectorBalanceBefore, expectedFee);
        if (amount > _DUST) {
            assertEq(IERC20(USDC).balanceOf(address(userAgent)), 0);
            assertEq(IERC20(USDC).balanceOf(user), amount);
        } else {
            assertLe(IERC20(USDC).balanceOf(address(userAgent)), _DUST);
            assertEq(IERC20(USDC).balanceOf(user), 0);
        }
        assertEq(newAmount, expectedNewAmount);
    }

    function decodePermit2TransferFromAmount(bytes calldata data) external pure returns (uint256) {
        (, , uint160 amount, ) = abi.decode(data[4:], (address, address, uint160, address));
        return amount;
    }
}
