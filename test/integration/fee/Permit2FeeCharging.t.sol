// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {IERC20} from 'lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol';
import {SafeCast160} from 'lib/permit2/src/libraries/SafeCast160.sol';
import {Router} from 'src/Router.sol';
import {DataType} from 'src/libraries/DataType.sol';
import {IAgent} from 'src/interfaces/IAgent.sol';
import {FeeLibrary} from 'src/libraries/FeeLibrary.sol';
import {ERC20Permit2Utils} from 'test/utils/ERC20Permit2Utils.sol';
import {TypedDataSignature} from 'test/utils/TypedDataSignature.sol';

contract Permit2FeeCalculatorTest is Test, ERC20Permit2Utils, TypedDataSignature {
    using SafeCast160 for uint256;

    event Charged(address indexed token, uint256 amount, address indexed collector, bytes32 metadata);

    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public constant PERMIT2_ADDR = 0x000000000022D473030F116dDEE9F6B43aC78BA3;
    uint256 public constant BPS_BASE = 10_000;
    bytes32 public constant META_DATA = bytes32(bytes('permit2:pull-token'));
    uint256 internal constant _DUST = 10;

    address public user;
    uint256 public userPrivateKey;
    address public signer;
    uint256 public signerPrivateKey;
    address public defaultCollector;
    address public referrer;
    Router public router;
    IAgent public userAgent;
    address public permit2FeeCalculator;
    DataType.Logic[] public logicsEmpty;
    bytes32[] public referralsEmpty;

    function setUp() external {
        vm.createSelectFork(vm.rpcUrl('ethereum'));
        TypedDataSignature.initialize();

        (user, userPrivateKey) = makeAddrAndKey('User');
        (signer, signerPrivateKey) = makeAddrAndKey('Signer');
        defaultCollector = makeAddr('FeeCollector');
        referrer = makeAddr('Referrer');

        // Deploy contracts
        router = new Router(makeAddr('WrappedNative'), PERMIT2_ADDR, address(this));
        router.setFeeCollector(defaultCollector);
        vm.prank(user);
        userAgent = IAgent(router.newAgent());
        router.addSigner(signer);

        // Setup permit2
        erc20Permit2UtilsSetUp(user, userPrivateKey, address(userAgent));
        permitToken(IERC20(USDC));

        vm.label(address(router), 'Router');
        vm.label(address(userAgent), 'UserAgent');
        vm.label(defaultCollector, 'FeeCollector');
        vm.label(referrer, 'Referrer');
        vm.label(PERMIT2_ADDR, 'Permit2');
    }

    function testChargePermit2TransferFromFeeFromAgent(uint256 amount, uint256 feeRate) external {
        feeRate = bound(feeRate, 0, BPS_BASE - 1);
        amount = bound(amount, 0, (IERC20(USDC).totalSupply() * (BPS_BASE - feeRate)) / BPS_BASE);

        // Set fee rate
        router.setFeeRate(feeRate);

        // Encode permit2Datas
        bytes[] memory datas = new bytes[](1);
        uint256 amountWithFee = FeeLibrary.calcAmountWithFee(amount, feeRate);
        datas[0] = dataERC20Permit2PullToken(IERC20(USDC), amountWithFee.toUint160());

        // Prepare assert data
        uint256 expectedNewAmount = amountWithFee;
        uint256 expectedFee = amountWithFee - amount;
        uint256 newAmount = this.decodePermit2TransferFromAmount(datas[0]);
        uint256 feeCollectorBalanceBefore = IERC20(USDC).balanceOf(defaultCollector);

        deal(USDC, user, newAmount);

        // Execute
        address[] memory tokensReturn = new address[](1);
        tokensReturn[0] = USDC;
        if (expectedFee > 0) {
            vm.expectEmit(true, true, true, true, address(userAgent));
            emit Charged(USDC, expectedFee, defaultCollector, META_DATA);
        }
        vm.prank(user);
        router.execute(datas, logicsEmpty, tokensReturn);

        assertEq(IERC20(USDC).balanceOf(address(router)), 0);
        assertEq(IERC20(USDC).balanceOf(defaultCollector) - feeCollectorBalanceBefore, expectedFee);
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

        uint256 amountFee = FeeLibrary.calcFeeFromAmount(amount, feeRate);

        datas[0] = dataERC20Permit2PullToken(IERC20(USDC), amount.toUint160());
        DataType.Fee[] memory fees = new DataType.Fee[](1);
        fees[0] = DataType.Fee(USDC, amountFee, META_DATA);

        // Prepare assert data
        uint256 expectedFee = amountFee;
        uint256 feeCollectorBalanceBefore = IERC20(USDC).balanceOf(defaultCollector);

        deal(USDC, user, amount + amountFee);

        // Execute
        address[] memory tokensReturn = new address[](1);
        tokensReturn[0] = USDC;
        if (amountFee > 0) {
            vm.expectEmit(true, true, true, true, address(userAgent));
            emit Charged(USDC, amountFee, defaultCollector, META_DATA);
        }
        bytes32[] memory referrals = new bytes32[](1);
        referrals[0] = _getReferral(defaultCollector, BPS_BASE);
        DataType.LogicBatch memory logicBatch = DataType.LogicBatch(logicsEmpty, fees, referrals, block.timestamp + 5);
        bytes memory signature = getTypedDataSignature(logicBatch, router.domainSeparator(), signerPrivateKey);
        vm.prank(user);
        router.executeWithSignerFee(datas, logicBatch, signer, signature, tokensReturn);

        assertEq(IERC20(USDC).balanceOf(address(router)), 0);
        assertEq(IERC20(USDC).balanceOf(defaultCollector) - feeCollectorBalanceBefore, expectedFee);
        if (amount > _DUST) {
            assertEq(IERC20(USDC).balanceOf(address(userAgent)), 0);
            assertEq(IERC20(USDC).balanceOf(user), amount);
        } else {
            assertLe(IERC20(USDC).balanceOf(address(userAgent)), _DUST);
            assertEq(IERC20(USDC).balanceOf(user), 0);
        }
    }

    function testChargePermit2TransferFromFeeFromUserToMultiReferrer(
        uint256 amount,
        uint256 feeRate,
        uint256 shareRate
    ) external {
        feeRate = bound(feeRate, 0, BPS_BASE - 1);
        amount = bound(amount, 0, (IERC20(USDC).totalSupply() * (BPS_BASE - feeRate)) / BPS_BASE);
        shareRate = bound(shareRate, 0, BPS_BASE);

        // Set fee rate
        router.setFeeRate(feeRate);

        // Encode permit2Datas
        bytes[] memory datas = new bytes[](1);

        uint256 amountFee = FeeLibrary.calcFeeFromAmount(amount, feeRate);

        datas[0] = dataERC20Permit2PullToken(IERC20(USDC), amount.toUint160());
        DataType.Fee[] memory fees = new DataType.Fee[](1);
        fees[0] = DataType.Fee(USDC, amountFee, META_DATA);

        // Prepare assert data
        uint256 expectedFeeCollectorFee = (amountFee * shareRate) / BPS_BASE;
        uint256 expectedReferrerFee = (amountFee * (BPS_BASE - shareRate)) / BPS_BASE;
        deal(USDC, user, amount + amountFee);

        // Execute
        address[] memory tokensReturn = new address[](1);
        tokensReturn[0] = USDC;
        if (expectedReferrerFee > 0 || expectedFeeCollectorFee > 0) {
            vm.expectEmit(true, true, true, true, address(userAgent));
            if (expectedReferrerFee > 0) emit Charged(USDC, expectedReferrerFee, referrer, META_DATA);
            if (expectedFeeCollectorFee > 0) emit Charged(USDC, expectedFeeCollectorFee, defaultCollector, META_DATA);
        }
        bytes32[] memory referrals = new bytes32[](2);
        referrals[0] = _getReferral(defaultCollector, shareRate);
        referrals[1] = _getReferral(referrer, BPS_BASE - shareRate);
        DataType.LogicBatch memory logicBatch = DataType.LogicBatch(logicsEmpty, fees, referrals, block.timestamp + 5);
        bytes memory signature = getTypedDataSignature(logicBatch, router.domainSeparator(), signerPrivateKey);
        {
            uint256 feeCollectorBalanceBefore = IERC20(USDC).balanceOf(defaultCollector);
            uint256 referrerBalanceBefore = IERC20(USDC).balanceOf(referrer);
            vm.prank(user);
            router.executeWithSignerFee(datas, logicBatch, signer, signature, tokensReturn);

            assertEq(IERC20(USDC).balanceOf(address(router)), 0);
            assertEq(IERC20(USDC).balanceOf(defaultCollector) - feeCollectorBalanceBefore, expectedFeeCollectorFee);
            assertEq(IERC20(USDC).balanceOf(referrer) - referrerBalanceBefore, expectedReferrerFee);
        }
        uint256 feeDust = amountFee - expectedFeeCollectorFee - expectedReferrerFee;
        if (amount > _DUST) {
            assertEq(IERC20(USDC).balanceOf(address(userAgent)), 0);
            assertEq(IERC20(USDC).balanceOf(user), amount + feeDust);
        } else {
            assertLe(IERC20(USDC).balanceOf(address(userAgent)), _DUST);
            assertEq(IERC20(USDC).balanceOf(user), feeDust);
        }
    }

    function decodePermit2TransferFromAmount(bytes calldata data) external pure returns (uint256) {
        (, , uint160 amount, ) = abi.decode(data[4:], (address, address, uint160, address));
        return amount;
    }

    function _getReferral(address collector, uint256 rate) internal pure returns (bytes32) {
        require(rate <= BPS_BASE);
        return bytes32(bytes20(collector)) | bytes32(rate);
    }
}
