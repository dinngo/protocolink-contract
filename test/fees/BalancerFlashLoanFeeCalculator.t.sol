// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {IERC20} from 'openzeppelin-contracts/contracts/token/ERC20/IERC20.sol';
import {SafeCast160} from 'permit2/libraries/SafeCast160.sol';
import {Router} from 'src/Router.sol';
import {IParam} from 'src/interfaces/IParam.sol';
import {IAgent} from 'src/interfaces/IAgent.sol';
import {FeeCalculatorBase} from 'src/fees/FeeCalculatorBase.sol';
import {BalancerFlashLoanFeeCalculator} from 'src/fees/BalancerFlashLoanFeeCalculator.sol';
import {NativeFeeCalculator} from 'src/fees/NativeFeeCalculator.sol';
import {Permit2FeeCalculator} from 'src/fees/Permit2FeeCalculator.sol';
import {BalancerV2FlashLoanCallback, IBalancerV2FlashLoanCallback} from 'src/callbacks/BalancerV2FlashLoanCallback.sol';
import {ERC20Permit2Utils} from 'test/utils/ERC20Permit2Utils.sol';

contract BalancerFlashLoanFeeCalculatorTest is Test, ERC20Permit2Utils {
    using SafeCast160 for uint256;

    event FeeCharged(address indexed token, uint256 amount, bytes32 metadata);

    address public constant NATIVE = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address public constant BALANCER_V2_VAULT = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;
    address public constant PERMIT2_ADDRESS = 0x000000000022D473030F116dDEE9F6B43aC78BA3;
    address public constant DUMMY_TO_ADDRESS = address(0);
    bytes4 public constant BALANCER_FLASHLOAN_SELECTOR =
        bytes4(keccak256(bytes('flashLoan(address,address[],uint256[],bytes)')));
    bytes4 public constant PERMIT2_TRANSFER_FROM_SELECTOR =
        bytes4(keccak256(bytes('transferFrom(address,address,uint160,address)')));
    bytes4 public constant NATIVE_FEE_SELECTOR = 0xeeeeeeee;
    uint256 public constant SKIP = 0x8000000000000000000000000000000000000000000000000000000000000000;
    uint256 public constant BPS_BASE = 10_000;
    bytes32 public constant BALANCER_META_DATA = bytes32(bytes('balancer-v2:flash-loan'));
    bytes32 public constant NATIVE_TOKEN_META_DATA = bytes32(bytes('native-token'));
    bytes32 public constant PERMIT2_META_DATA = bytes32(bytes('permit2:pull-token'));

    address public user;
    uint256 public userPrivateKey;
    address public user2;
    IAgent public userAgent;
    address public feeCollector;
    address public flashLoanFeeCalculator;
    address public nativeFeeCalculator;
    address public permit2FeeCalculator;
    Router public router;
    IBalancerV2FlashLoanCallback public flashLoanCallback;

    // Empty arrays
    address[] public tokensReturnEmpty;
    IParam.Fee[] public feesEmpty;
    IParam.Input[] public inputsEmpty;

    function setUp() external {
        (user, userPrivateKey) = makeAddrAndKey('User');
        user2 = makeAddr('User2');
        feeCollector = makeAddr('FeeCollector');
        address pauser = makeAddr('Pauser');

        // Depoly contracts
        router = new Router(makeAddr('WrappedNative'), address(this), pauser, feeCollector);
        vm.prank(user);
        userAgent = IAgent(router.newAgent());
        flashLoanCallback = new BalancerV2FlashLoanCallback(address(router), BALANCER_V2_VAULT);
        flashLoanFeeCalculator = address(new BalancerFlashLoanFeeCalculator(address(router), 0));
        nativeFeeCalculator = address(new NativeFeeCalculator(address(router), 0));
        permit2FeeCalculator = address(new Permit2FeeCalculator(address(router), 0));

        // Setup fee calculator
        bytes4[] memory selectors = new bytes4[](3);
        selectors[0] = BALANCER_FLASHLOAN_SELECTOR;
        selectors[1] = NATIVE_FEE_SELECTOR;
        selectors[2] = PERMIT2_TRANSFER_FROM_SELECTOR;
        address[] memory tos = new address[](3);
        tos[0] = BALANCER_V2_VAULT;
        tos[1] = DUMMY_TO_ADDRESS;
        tos[2] = PERMIT2_ADDRESS;
        address[] memory feeCalculators = new address[](3);
        feeCalculators[0] = address(flashLoanFeeCalculator);
        feeCalculators[1] = address(nativeFeeCalculator);
        feeCalculators[2] = address(permit2FeeCalculator);
        router.setFeeCalculators(selectors, tos, feeCalculators);

        // Setup permit2
        erc20Permit2UtilsSetUp(user, userPrivateKey, address(userAgent));
        permitToken(IERC20(USDT));

        vm.label(address(router), 'Router');
        vm.label(address(userAgent), 'UserAgent');
        vm.label(feeCollector, 'FeeCollector');
        vm.label(flashLoanFeeCalculator, 'BalancerFlashLoanFeeCalculator');
        vm.label(nativeFeeCalculator, 'NativeFeeCalculator');
        vm.label(permit2FeeCalculator, 'Permit2FeeCalculator');
        vm.label(PERMIT2_ADDRESS, 'Permit2');
        vm.label(address(flashLoanCallback), 'BalancerV2FlashLoanCallback');
        vm.label(BALANCER_V2_VAULT, 'BalancerV2Vault');
        vm.label(USDC, 'USDC');
        vm.label(USDT, 'USDT');
    }

    function testChargeFlashLoanFee(uint256 amount, uint256 feeRate) external {
        feeRate = bound(feeRate, 0, BPS_BASE - 1);
        amount = bound(amount, 1, (IERC20(USDC).balanceOf(BALANCER_V2_VAULT) * (BPS_BASE - feeRate)) / BPS_BASE);

        // Set fee rate
        FeeCalculatorBase(flashLoanFeeCalculator).setFeeRate(feeRate);

        // Encode flash loan userData
        IParam.Logic[] memory flashLoanLogics = new IParam.Logic[](1);
        flashLoanLogics[0] = _logicTransferFlashLoanAmount(
            address(flashLoanCallback),
            USDC,
            FeeCalculatorBase(flashLoanFeeCalculator).calculateAmountWithFee(amount)
        );
        bytes memory userData = abi.encode(flashLoanLogics, feesEmpty, tokensReturnEmpty);

        // Encode logic
        address[] memory tokens = new address[](1);
        tokens[0] = USDC;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;

        IParam.Logic[] memory logics = new IParam.Logic[](1);
        logics[0] = _logicBalancerV2FlashLoan(tokens, amounts, userData);

        // Get new logics
        (logics, ) = router.getUpdatedLogicsAndMsgValue(logics, 0);

        _distributeToken(tokens, amounts);

        // Prepare assert data
        uint256 expectedNewAmount = FeeCalculatorBase(flashLoanFeeCalculator).calculateAmountWithFee(amount);
        uint256 expectedFee = FeeCalculatorBase(flashLoanFeeCalculator).calculateFee(expectedNewAmount);
        uint256 feeCollectorBalanceBefore = IERC20(USDC).balanceOf(feeCollector);
        uint256[] memory newAmounts = this.decodeFlashLoanAmounts(logics[0]);

        // Execute
        vm.expectEmit(true, true, true, true, address(userAgent));
        emit FeeCharged(USDC, expectedFee, BALANCER_META_DATA);
        vm.prank(user);
        router.execute(logics, tokensReturnEmpty, SIGNER_REFERRAL);

        assertEq(IERC20(USDC).balanceOf(address(router)), 0);
        assertEq(IERC20(USDC).balanceOf(address(userAgent)), 0);
        assertEq(IERC20(USDC).balanceOf(feeCollector) - feeCollectorBalanceBefore, expectedFee);
        assertEq(newAmounts[0], expectedNewAmount);
    }

    /// This test will do flash loan + send native token(inside flash loan)
    function testChargeFlashLoanFeeWithFeeScenarioInside(
        uint256 amount,
        uint256 nativeAmount,
        uint256 feeRate
    ) external {
        feeRate = bound(feeRate, 0, BPS_BASE - 1);
        amount = bound(amount, 1, (IERC20(USDC).balanceOf(BALANCER_V2_VAULT) * (BPS_BASE - feeRate)) / BPS_BASE);
        nativeAmount = bound(nativeAmount, 0, 5000 ether);

        // Set fee rate
        FeeCalculatorBase(flashLoanFeeCalculator).setFeeRate(feeRate);
        FeeCalculatorBase(nativeFeeCalculator).setFeeRate(feeRate);

        // Encode flash loan userData
        IParam.Logic[] memory flashLoanLogics = new IParam.Logic[](2);
        flashLoanLogics[0] = _logicTransferFlashLoanAmount(
            address(flashLoanCallback),
            USDC,
            FeeCalculatorBase(flashLoanFeeCalculator).calculateAmountWithFee(amount)
        );
        flashLoanLogics[1] = _logicSendNativeToken(user2, nativeAmount);
        bytes memory userData = abi.encode(flashLoanLogics, feesEmpty, tokensReturnEmpty);

        // Get new logics and msg.value amount
        IParam.Logic[] memory logics = new IParam.Logic[](1);
        uint256 nativeNewAmount;
        {
            // Encode logic
            address[] memory tokens = new address[](1);
            tokens[0] = USDC;

            uint256[] memory amounts = new uint256[](1);
            amounts[0] = amount;

            logics[0] = _logicBalancerV2FlashLoan(tokens, amounts, userData);

            (logics, nativeNewAmount) = router.getUpdatedLogicsAndMsgValue(logics, nativeAmount);
            deal(user, nativeNewAmount);
            _distributeToken(tokens, amounts);
        }

        // Prepare assert data
        uint256 expectedNewAmount = FeeCalculatorBase(flashLoanFeeCalculator).calculateAmountWithFee(amount);
        uint256 expectedFee = FeeCalculatorBase(flashLoanFeeCalculator).calculateFee(expectedNewAmount);
        uint256 expectedNativeNewAmount = FeeCalculatorBase(nativeFeeCalculator).calculateAmountWithFee(nativeAmount);
        uint256 expectedNativeFee = FeeCalculatorBase(nativeFeeCalculator).calculateFee(expectedNativeNewAmount);
        uint256 feeCollectorBalanceBefore = IERC20(USDC).balanceOf(feeCollector);
        uint256 feeCollectorNativeBalanceBefore = feeCollector.balance;
        uint256 user2NativeBalanceBefore = user2.balance;

        {
            // Execute
            vm.expectEmit(true, true, true, true, address(userAgent));
            emit FeeCharged(USDC, expectedFee, BALANCER_META_DATA);
            emit FeeCharged(NATIVE, expectedNativeFee, NATIVE_TOKEN_META_DATA);
            vm.prank(user);
            router.execute{value: nativeNewAmount}(logics, tokensReturnEmpty, SIGNER_REFERRAL);
        }

        assertEq(IERC20(USDC).balanceOf(address(router)), 0);
        assertEq(IERC20(USDC).balanceOf(address(userAgent)), 0);
        assertEq(IERC20(USDC).balanceOf(feeCollector) - feeCollectorBalanceBefore, expectedFee);
        assertEq(feeCollector.balance - feeCollectorNativeBalanceBefore, expectedNativeFee);
        assertEq(user2.balance - user2NativeBalanceBefore, nativeAmount);
    }

    /// This test will do flash loan + send native token(inside flash loan) + permit2 pull token(inside flash loan)
    function testChargeFlashLoanFeeWithTwoFeeScenarioInside(
        uint256 amount,
        uint256 nativeAmount,
        uint256 feeRate,
        uint256 permit2FeeRate
    ) external {
        feeRate = bound(feeRate, 0, BPS_BASE - 1);
        permit2FeeRate = bound(permit2FeeRate, 0, BPS_BASE - 1);
        amount = bound(amount, 1, (IERC20(USDC).balanceOf(BALANCER_V2_VAULT) * (BPS_BASE - feeRate)) / BPS_BASE);
        nativeAmount = bound(nativeAmount, 0, 5000 ether);

        // Set fee rate
        FeeCalculatorBase(flashLoanFeeCalculator).setFeeRate(feeRate);
        FeeCalculatorBase(nativeFeeCalculator).setFeeRate(feeRate);
        FeeCalculatorBase(permit2FeeCalculator).setFeeRate(permit2FeeRate);

        // Encode flash loan userData
        bytes memory userData;
        {
            IParam.Logic[] memory flashLoanLogics = new IParam.Logic[](3);
            flashLoanLogics[0] = _logicTransferFlashLoanAmount(
                address(flashLoanCallback),
                USDC,
                FeeCalculatorBase(flashLoanFeeCalculator).calculateAmountWithFee(amount)
            );
            flashLoanLogics[1] = _logicSendNativeToken(user2, nativeAmount);
            flashLoanLogics[2] = logicERC20Permit2PullToken(IERC20(USDT), amount.toUint160());
            userData = abi.encode(flashLoanLogics, feesEmpty, tokensReturnEmpty);
        }

        // Get new logics and msg.value amount
        IParam.Logic[] memory logics = new IParam.Logic[](1);
        uint256 nativeNewAmount;
        {
            // Encode logic
            address[] memory tokens = new address[](1);
            tokens[0] = USDC;

            uint256[] memory amounts = new uint256[](1);
            amounts[0] = amount;

            logics[0] = _logicBalancerV2FlashLoan(tokens, amounts, userData);

            (logics, nativeNewAmount) = router.getUpdatedLogicsAndMsgValue(logics, nativeAmount);

            // Distribute token
            deal(user, nativeNewAmount);
            deal(USDT, user, FeeCalculatorBase(permit2FeeCalculator).calculateAmountWithFee(amount));
            _distributeToken(tokens, amounts);
        }

        // Prepare assert data
        uint256 expectedUSDCFee;
        uint256 expectedUSDTFee;
        uint256 expectedNativeFee;
        {
            uint256 expectedUSDCNewAmount = FeeCalculatorBase(flashLoanFeeCalculator).calculateAmountWithFee(amount);
            expectedUSDCFee = FeeCalculatorBase(flashLoanFeeCalculator).calculateFee(expectedUSDCNewAmount);
            uint256 expectedUSDTNewAmount = FeeCalculatorBase(permit2FeeCalculator).calculateAmountWithFee(amount);
            expectedUSDTFee = FeeCalculatorBase(permit2FeeCalculator).calculateFee(expectedUSDTNewAmount);
            uint256 expectedNativeNewAmount = FeeCalculatorBase(nativeFeeCalculator).calculateAmountWithFee(
                nativeAmount
            );
            expectedNativeFee = FeeCalculatorBase(nativeFeeCalculator).calculateFee(expectedNativeNewAmount);
        }

        uint256 feeCollectorUSDCBalanceBefore = IERC20(USDC).balanceOf(feeCollector);
        uint256 feeCollectorUSDTBalanceBefore = IERC20(USDT).balanceOf(feeCollector);
        uint256 feeCollectorNativeBalanceBefore = feeCollector.balance;
        uint256 user2NativeBalanceBefore = user2.balance;

        {
            // Execute
            address[] memory tokensReturns = new address[](1);
            tokensReturns[0] = USDT;
            vm.expectEmit(true, true, true, true, address(userAgent));
            emit FeeCharged(USDC, expectedUSDCFee, BALANCER_META_DATA);
            emit FeeCharged(NATIVE, expectedNativeFee, NATIVE_TOKEN_META_DATA);
            emit FeeCharged(USDT, expectedUSDTFee, PERMIT2_META_DATA);
            vm.prank(user);
            router.execute{value: nativeNewAmount}(logics, tokensReturns, SIGNER_REFERRAL);
        }

        assertEq(IERC20(USDC).balanceOf(address(router)), 0);
        assertEq(IERC20(USDC).balanceOf(address(userAgent)), 0);
        assertEq(IERC20(USDT).balanceOf(address(router)), 0);
        assertEq(IERC20(USDT).balanceOf(address(userAgent)), 0);
        assertEq(IERC20(USDC).balanceOf(feeCollector) - feeCollectorUSDCBalanceBefore, expectedUSDCFee);
        assertEq(IERC20(USDT).balanceOf(feeCollector) - feeCollectorUSDTBalanceBefore, expectedUSDTFee);
        assertEq(feeCollector.balance - feeCollectorNativeBalanceBefore, expectedNativeFee);
        assertEq(user2.balance - user2NativeBalanceBefore, nativeAmount);
    }

    function decodeFlashLoanAmounts(IParam.Logic calldata logic) external pure returns (uint256[] memory) {
        bytes calldata data = logic.data;
        (, , uint256[] memory amounts, ) = abi.decode(data[4:], (address, address[], uint256[], bytes));
        return amounts;
    }

    function _logicBalancerV2FlashLoan(
        address[] memory tokens,
        uint256[] memory amounts,
        bytes memory userData
    ) public view returns (IParam.Logic memory) {
        return
            IParam.Logic(
                BALANCER_V2_VAULT, // to
                abi.encodeWithSelector(
                    BALANCER_FLASHLOAN_SELECTOR,
                    address(flashLoanCallback),
                    tokens,
                    amounts,
                    userData
                ),
                inputsEmpty,
                IParam.WrapMode.NONE,
                address(0), // approveTo
                address(flashLoanCallback) // callback
            );
    }

    function _logicSendNativeToken(address to, uint256 amount) internal pure returns (IParam.Logic memory) {
        // Encode inputs
        IParam.Input[] memory inputs = new IParam.Input[](1);
        inputs[0].token = NATIVE;
        inputs[0].amountBps = SKIP;
        inputs[0].amountOrOffset = amount;

        return
            IParam.Logic(
                to,
                new bytes(0),
                inputs,
                IParam.WrapMode.NONE,
                address(0), // approveTo
                address(0) // callback
            );
    }

    function _logicTransferFlashLoanAmount(
        address to,
        address token,
        uint256 amount
    ) internal view returns (IParam.Logic memory) {
        return
            IParam.Logic(
                token,
                abi.encodeWithSelector(IERC20.transfer.selector, to, amount),
                inputsEmpty,
                IParam.WrapMode.NONE,
                address(0), // approveTo
                address(0) // callback
            );
    }

    function _distributeToken(address[] memory tokens, uint256[] memory amounts) internal {
        for (uint256 i = 0; i < tokens.length; ++i) {
            uint256 amountWithRouterFee = FeeCalculatorBase(flashLoanFeeCalculator).calculateAmountWithFee(amounts[i]);

            // Airdrop router flash loan fee to agent
            uint256 routerFee = FeeCalculatorBase(flashLoanFeeCalculator).calculateFee(amountWithRouterFee);

            deal(tokens[i], address(userAgent), routerFee);
        }
    }
}
