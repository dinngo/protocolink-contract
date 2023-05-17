// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {IERC20} from 'openzeppelin-contracts/contracts/token/ERC20/IERC20.sol';
import {SafeCast160} from 'permit2/libraries/SafeCast160.sol';
import {Router} from 'src/Router.sol';
import {FeeCalculatorBase} from 'src/fees/FeeCalculatorBase.sol';
import {AaveFlashLoanFeeCalculator} from 'src/fees/AaveFlashLoanFeeCalculator.sol';
import {NativeFeeCalculator} from 'src/fees/NativeFeeCalculator.sol';
import {Permit2FeeCalculator} from 'src/fees/Permit2FeeCalculator.sol';
import {AaveV2FlashLoanCallback, IAaveV2FlashLoanCallback} from 'src/callbacks/AaveV2FlashLoanCallback.sol';
import {AaveV3FlashLoanCallback, IAaveV3FlashLoanCallback} from 'src/callbacks/AaveV3FlashLoanCallback.sol';
import {IParam} from 'src/interfaces/IParam.sol';
import {IAgent} from 'src/interfaces/IAgent.sol';
import {IAaveV2Provider} from 'src/interfaces/aaveV2/IAaveV2Provider.sol';
import {IAaveV3Provider} from 'src/interfaces/aaveV3/IAaveV3Provider.sol';
import {ERC20Permit2Utils} from 'test/utils/ERC20Permit2Utils.sol';

interface IAaveV3Pool {
    function FLASHLOAN_PREMIUM_TOTAL() external view returns (uint128);
}

contract AaveFlashLoanFeeCalculatorTest is Test, ERC20Permit2Utils {
    using SafeCast160 for uint256;

    enum InterestRateMode {
        NONE,
        STABLE,
        VARIABLE
    }

    event FeeCharged(address indexed token, uint256 amount, bytes32 metadata);

    address public constant NATIVE = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address public constant AAVE_V2_PROVIDER = 0xB53C1a33016B2DC2fF3653530bfF1848a515c8c5;
    address public constant AAVE_V3_PROVIDER = 0x2f39d218133AFaB8F2B819B1066c7E434Ad94E9e;
    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address public constant AUSDC_V2 = 0xBcca60bB61934080951369a648Fb03DF4F96263C;
    address public constant AUSDC_V3 = 0x98C23E9d8f34FEFb1B7BD6a91B7FF122F4e16F5c;
    address public constant PERMIT2_ADDRESS = 0x000000000022D473030F116dDEE9F6B43aC78BA3;
    address public constant ANY_TO_ADDRESS = address(0);
    bytes4 public constant AAVE_FLASHLOAN_SELECTOR =
        bytes4(keccak256(bytes('flashLoan(address,address[],uint256[],uint256[],address,bytes,uint16)')));
    bytes4 public constant PERMIT2_TRANSFER_FROM_SELECTOR =
        bytes4(keccak256(bytes('transferFrom(address,address,uint160,address)')));
    bytes4 public constant NATIVE_FEE_SELECTOR = 0xeeeeeeee;
    uint256 public constant SKIP = 0x8000000000000000000000000000000000000000000000000000000000000000;
    uint256 public constant BPS_BASE = 10_000;
    bytes32 public constant V2_FLASHLOAN_META_DATA = bytes32(bytes('aave-v2:flash-loan'));
    bytes32 public constant V3_FLASHLOAN_META_DATA = bytes32(bytes('aave-v3:flash-loan'));
    bytes32 public constant NATIVE_TOKEN_META_DATA = bytes32(bytes('native-token'));
    bytes32 public constant PERMIT2_META_DATA = bytes32(bytes('permit2:pull-token'));

    address v2Pool = IAaveV2Provider(AAVE_V2_PROVIDER).getLendingPool();
    address v3Pool = IAaveV3Provider(AAVE_V3_PROVIDER).getPool();

    address public user;
    uint256 public userPrivateKey;
    address public user2;
    address public feeCollector;
    Router public router;
    IAgent public userAgent;
    address public flashLoanFeeCalculator;
    address public nativeFeeCalculator;
    address public permit2FeeCalculator;
    IAaveV2FlashLoanCallback public flashLoanCallbackV2;
    IAaveV3FlashLoanCallback public flashLoanCallbackV3;

    // Empty arrays
    address[] public tokensReturnEmpty;
    IParam.Fee[] public feesEmpty;
    IParam.Input[] public inputsEmpty;

    function setUp() external {
        (user, userPrivateKey) = makeAddrAndKey('User');
        feeCollector = makeAddr('FeeCollector');
        address pauser = makeAddr('Pauser');

        // Depoly contracts
        router = new Router(makeAddr('WrappedNative'), address(this), pauser, feeCollector);
        vm.prank(user);
        userAgent = IAgent(router.newAgent());
        flashLoanFeeCalculator = address(new AaveFlashLoanFeeCalculator(address(router), 0, AAVE_V3_PROVIDER));
        permit2FeeCalculator = address(new Permit2FeeCalculator(address(router), 0));
        nativeFeeCalculator = address(new NativeFeeCalculator(address(router), 0));
        flashLoanCallbackV2 = new AaveV2FlashLoanCallback(address(router), AAVE_V2_PROVIDER);
        flashLoanCallbackV3 = new AaveV3FlashLoanCallback(address(router), AAVE_V3_PROVIDER);

        // Setup fee calculator
        bytes4[] memory selectors = new bytes4[](4);
        selectors[0] = AAVE_FLASHLOAN_SELECTOR;
        selectors[1] = AAVE_FLASHLOAN_SELECTOR;
        selectors[2] = NATIVE_FEE_SELECTOR;
        selectors[3] = PERMIT2_TRANSFER_FROM_SELECTOR;
        address[] memory tos = new address[](4);
        tos[0] = v2Pool;
        tos[1] = v3Pool;
        tos[2] = ANY_TO_ADDRESS;
        tos[3] = PERMIT2_ADDRESS;
        address[] memory feeCalculators = new address[](4);
        feeCalculators[0] = address(flashLoanFeeCalculator);
        feeCalculators[1] = address(flashLoanFeeCalculator);
        feeCalculators[2] = address(nativeFeeCalculator);
        feeCalculators[3] = address(permit2FeeCalculator);
        router.setFeeCalculators(selectors, tos, feeCalculators);

        // Setup permit2
        erc20Permit2UtilsSetUp(user, userPrivateKey, address(userAgent));
        permitToken(IERC20(USDT));

        vm.label(address(router), 'Router');
        vm.label(address(userAgent), 'UserAgent');
        vm.label(feeCollector, 'FeeCollector');
        vm.label(flashLoanFeeCalculator, 'FlashLoanFeeCalculator');
        vm.label(nativeFeeCalculator, 'NativeFeeCalculator');
        vm.label(permit2FeeCalculator, 'Permit2FeeCalculator');
        vm.label(v2Pool, 'AaveV2Pool');
        vm.label(v3Pool, 'AaveV3Pool');
        vm.label(AAVE_V2_PROVIDER, 'AaveV2Provider');
        vm.label(AAVE_V3_PROVIDER, 'AaveV3Provider');
        vm.label(PERMIT2_ADDRESS, 'Permit2');
        vm.label(address(flashLoanCallbackV2), 'AaveV2FlashLoanCallback');
        vm.label(address(flashLoanCallbackV3), 'AaveV3FlashLoanCallback');
        vm.label(USDC, 'USDC');
        vm.label(USDT, 'USDT');
    }

    function testChargeFlashLoanV2Fee(uint256 amount, uint256 feeRate) external {
        bool isAaveV2 = true;
        feeRate = bound(feeRate, 0, BPS_BASE - 1);
        amount = bound(amount, 0, (IERC20(USDC).balanceOf(AUSDC_V2) * (BPS_BASE - feeRate)) / BPS_BASE);

        // Set fee rate
        FeeCalculatorBase(flashLoanFeeCalculator).setFeeRate(feeRate);

        // Encode flash loan params
        IParam.Logic[] memory flashLoanLogics = new IParam.Logic[](1);
        flashLoanLogics[0] = _logicTransferFlashLoanAmountAndFee(
            address(flashLoanCallbackV2),
            USDC,
            FeeCalculatorBase(flashLoanFeeCalculator).calculateAmountWithFee(amount),
            isAaveV2
        );
        bytes memory params = abi.encode(flashLoanLogics, feesEmpty, tokensReturnEmpty);

        // Encode logic
        address[] memory tokens = new address[](1);
        tokens[0] = USDC;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;

        IParam.Logic[] memory logics = new IParam.Logic[](1);
        logics[0] = _logicAaveFlashLoan(v2Pool, address(flashLoanCallbackV2), tokens, amounts, params);

        // Get new logics
        (logics, ) = router.getUpdatedLogicsAndMsgValue(logics, 0);

        _distributeToken(tokens, amounts, isAaveV2);

        // Prepare assert data
        uint256 expectedNewAmount = FeeCalculatorBase(flashLoanFeeCalculator).calculateAmountWithFee(amount);
        uint256 expectedFee = FeeCalculatorBase(flashLoanFeeCalculator).calculateFee(expectedNewAmount);
        uint256 feeCollectorBalanceBefore = IERC20(USDC).balanceOf(feeCollector);
        uint256[] memory newAmounts = this.decodeFlashLoanAmounts(logics[0]);

        // Execute
        if (expectedFee > 0) {
            vm.expectEmit(true, true, true, true, address(userAgent));
            emit FeeCharged(USDC, expectedFee, V2_FLASHLOAN_META_DATA);
        }
        vm.prank(user);
        router.execute(logics, tokensReturnEmpty, SIGNER_REFERRAL);

        assertEq(IERC20(USDC).balanceOf(address(router)), 0);
        assertEq(IERC20(USDC).balanceOf(address(userAgent)), 0);
        assertEq(IERC20(USDC).balanceOf(feeCollector) - feeCollectorBalanceBefore, expectedFee);
        assertEq(newAmounts[0], expectedNewAmount);
    }

    /// This test will do flash loan + send native token(inside flash loan)
    function testChargeFlashLoanV2FeeWithFeeScenarioInside(
        uint256 amount,
        uint256 nativeAmount,
        uint256 feeRate
    ) external {
        bool isAaveV2 = true;
        feeRate = bound(feeRate, 0, BPS_BASE - 1);
        amount = bound(amount, 0, (IERC20(USDC).balanceOf(AUSDC_V2) * (BPS_BASE - feeRate)) / BPS_BASE);
        nativeAmount = bound(nativeAmount, 0, 5000 ether);

        // Set fee rate
        FeeCalculatorBase(flashLoanFeeCalculator).setFeeRate(feeRate);
        FeeCalculatorBase(nativeFeeCalculator).setFeeRate(feeRate);

        // Encode flash loan params
        bytes memory params;
        {
            IParam.Logic[] memory flashLoanLogics = new IParam.Logic[](2);
            flashLoanLogics[0] = _logicTransferFlashLoanAmountAndFee(
                address(flashLoanCallbackV2),
                USDC,
                FeeCalculatorBase(flashLoanFeeCalculator).calculateAmountWithFee(amount),
                isAaveV2
            );
            flashLoanLogics[1] = _logicSendNativeToken(user2, nativeAmount);
            params = abi.encode(flashLoanLogics, feesEmpty, tokensReturnEmpty);
        }

        IParam.Logic[] memory logics = new IParam.Logic[](1);
        uint256 nativeNewAmount;
        {
            // Encode logic
            address[] memory tokens = new address[](1);
            tokens[0] = USDC;

            uint256[] memory amounts = new uint256[](1);
            amounts[0] = amount;

            logics[0] = _logicAaveFlashLoan(v2Pool, address(flashLoanCallbackV2), tokens, amounts, params);

            // Get new logics and msg.value amount
            (logics, nativeNewAmount) = router.getUpdatedLogicsAndMsgValue(logics, nativeAmount);
            deal(user, nativeNewAmount);
            _distributeToken(tokens, amounts, isAaveV2);
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
            if (expectedNativeFee > 0) {
                vm.expectEmit(true, true, true, true, address(userAgent));
                emit FeeCharged(NATIVE, expectedNativeFee, NATIVE_TOKEN_META_DATA);
            }
            if (expectedFee > 0) {
                vm.expectEmit(true, true, true, true, address(userAgent));
                emit FeeCharged(USDC, expectedFee, V2_FLASHLOAN_META_DATA);
            }
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
    function testChargeFlashLoanV2FeeWithTwoFeeScenarioInside(
        uint256 amount,
        uint256 nativeAmount,
        uint256 feeRate,
        uint256 permit2FeeRate
    ) external {
        feeRate = bound(feeRate, 0, BPS_BASE - 1);
        permit2FeeRate = bound(permit2FeeRate, 0, BPS_BASE - 1);
        amount = bound(amount, 0, (IERC20(USDC).balanceOf(AUSDC_V2) * (BPS_BASE - feeRate)) / BPS_BASE);
        nativeAmount = bound(nativeAmount, 0, 5000 ether);

        // Set fee rate
        FeeCalculatorBase(flashLoanFeeCalculator).setFeeRate(feeRate);
        FeeCalculatorBase(nativeFeeCalculator).setFeeRate(feeRate);
        FeeCalculatorBase(permit2FeeCalculator).setFeeRate(permit2FeeRate);

        // Encode flash loan params
        bytes memory params;
        {
            IParam.Logic[] memory flashLoanLogics = new IParam.Logic[](3);
            flashLoanLogics[0] = _logicTransferFlashLoanAmountAndFee(
                address(flashLoanCallbackV2),
                USDC,
                FeeCalculatorBase(flashLoanFeeCalculator).calculateAmountWithFee(amount),
                true
            );
            flashLoanLogics[1] = _logicSendNativeToken(user2, nativeAmount);
            flashLoanLogics[2] = logicERC20Permit2PullToken(IERC20(USDT), amount.toUint160());
            params = abi.encode(flashLoanLogics, feesEmpty, tokensReturnEmpty);
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

            logics[0] = _logicAaveFlashLoan(v2Pool, address(flashLoanCallbackV2), tokens, amounts, params);
            (logics, nativeNewAmount) = router.getUpdatedLogicsAndMsgValue(logics, nativeAmount);

            // Distribute token
            deal(user, nativeNewAmount);
            deal(USDT, user, FeeCalculatorBase(permit2FeeCalculator).calculateAmountWithFee(amount));
            _distributeToken(tokens, amounts, true);
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
            if (expectedNativeFee > 0) {
                vm.expectEmit(true, true, true, true, address(userAgent));
                emit FeeCharged(NATIVE, expectedNativeFee, NATIVE_TOKEN_META_DATA);
            }
            if (expectedUSDTFee > 0) {
                vm.expectEmit(true, true, true, true, address(userAgent));
                emit FeeCharged(USDT, expectedUSDTFee, PERMIT2_META_DATA);
            }
            if (expectedUSDCFee > 0) {
                vm.expectEmit(true, true, true, true, address(userAgent));
                emit FeeCharged(USDC, expectedUSDCFee, V2_FLASHLOAN_META_DATA);
            }
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

    function testChargeFlashLoanV3Fee(uint256 amount, uint256 feeRate) external {
        bool isAaveV2 = false;
        feeRate = bound(feeRate, 0, BPS_BASE - 1);
        amount = bound(amount, 0, (IERC20(USDC).balanceOf(AUSDC_V3) * (BPS_BASE - feeRate)) / BPS_BASE);

        // Set fee rate
        FeeCalculatorBase(flashLoanFeeCalculator).setFeeRate(feeRate);

        // Encode flash loan params
        IParam.Logic[] memory flashLoanLogics = new IParam.Logic[](1);
        flashLoanLogics[0] = _logicTransferFlashLoanAmountAndFee(
            address(flashLoanCallbackV3),
            USDC,
            FeeCalculatorBase(flashLoanFeeCalculator).calculateAmountWithFee(amount),
            isAaveV2
        );
        bytes memory params = abi.encode(flashLoanLogics, feesEmpty, tokensReturnEmpty);

        // Encode logic
        address[] memory tokens = new address[](1);
        tokens[0] = USDC;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;

        IParam.Logic[] memory logics = new IParam.Logic[](1);
        logics[0] = _logicAaveFlashLoan(v3Pool, address(flashLoanCallbackV3), tokens, amounts, params);

        // Get new logics
        (logics, ) = router.getUpdatedLogicsAndMsgValue(logics, 0);

        _distributeToken(tokens, amounts, isAaveV2);

        // Prepare assert data
        uint256 expectedNewAmount = FeeCalculatorBase(flashLoanFeeCalculator).calculateAmountWithFee(amount);
        uint256 expectedFee = FeeCalculatorBase(flashLoanFeeCalculator).calculateFee(expectedNewAmount);
        uint256 feeCollectorBalanceBefore = IERC20(USDC).balanceOf(feeCollector);
        uint256[] memory newAmounts = this.decodeFlashLoanAmounts(logics[0]);

        // Execute
        if (expectedFee > 0) {
            vm.expectEmit(true, true, true, true, address(userAgent));
            emit FeeCharged(USDC, expectedFee, V3_FLASHLOAN_META_DATA);
        }
        vm.prank(user);
        router.execute(logics, tokensReturnEmpty, SIGNER_REFERRAL);

        assertEq(IERC20(USDC).balanceOf(address(router)), 0);
        assertEq(IERC20(USDC).balanceOf(address(userAgent)), 0);
        assertEq(IERC20(USDC).balanceOf(feeCollector) - feeCollectorBalanceBefore, expectedFee);
        assertEq(newAmounts[0], expectedNewAmount);
    }

    function decodeFlashLoanAmounts(IParam.Logic calldata logic) external pure returns (uint256[] memory) {
        bytes calldata data = logic.data;
        (, , uint256[] memory amounts, , , , ) = abi.decode(
            data[4:],
            (address, address[], uint256[], uint256[], address, bytes, uint16)
        );
        return amounts;
    }

    function _logicAaveFlashLoan(
        address to,
        address callback,
        address[] memory tokens,
        uint256[] memory amounts,
        bytes memory params
    ) internal view returns (IParam.Logic memory) {
        uint256[] memory modes = new uint256[](1);
        modes[0] = uint256(InterestRateMode.NONE);

        return
            IParam.Logic(
                to,
                abi.encodeWithSelector(
                    AAVE_FLASHLOAN_SELECTOR,
                    callback, // receiverAddress
                    tokens,
                    amounts,
                    modes,
                    address(0), // onBehalfOf
                    params,
                    0 // referralCode
                ),
                inputsEmpty,
                IParam.WrapMode.NONE,
                address(0), // approveTo
                callback
            );
    }

    function _logicSendNativeToken(address to, uint256 amount) internal pure returns (IParam.Logic memory) {
        // Encode inputs
        IParam.Input[] memory inputs = new IParam.Input[](1);
        inputs[0].token = NATIVE;
        inputs[0].balanceBps = SKIP;
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

    function _logicTransferFlashLoanAmountAndFee(
        address to,
        address token,
        uint256 amount,
        bool isAaveV2
    ) internal view returns (IParam.Logic memory) {
        uint256 fee = getAaveFlashLoanFee(amount, isAaveV2);
        return
            IParam.Logic(
                token,
                abi.encodeWithSelector(IERC20.transfer.selector, to, amount + fee),
                inputsEmpty,
                IParam.WrapMode.NONE,
                address(0), // approveTo
                address(0) // callback
            );
    }

    function _distributeToken(address[] memory tokens, uint256[] memory amounts, bool isAaveV2) internal {
        for (uint256 i = 0; i < tokens.length; ++i) {
            uint256 amountWithRouterFee = FeeCalculatorBase(flashLoanFeeCalculator).calculateAmountWithFee(amounts[i]);

            // Airdrop aave flash loan fee and router flash loan fee to agent
            uint256 aaveFee = getAaveFlashLoanFee(amountWithRouterFee, isAaveV2);
            uint256 routerFee = FeeCalculatorBase(flashLoanFeeCalculator).calculateFee(amountWithRouterFee);

            deal(tokens[i], address(userAgent), aaveFee + routerFee);
        }
    }

    function getAaveFlashLoanFee(uint256 amount, bool isAaveV2) internal view returns (uint256) {
        uint256 fee;
        if (isAaveV2) {
            fee = (amount * 9) / BPS_BASE;
        } else {
            uint256 percentage = IAaveV3Pool(v3Pool).FLASHLOAN_PREMIUM_TOTAL();
            fee = _percentMul(amount, percentage);
        }
        return fee;
    }

    function _percentMul(uint256 value, uint256 percentage) internal pure returns (uint256 result) {
        // Fork PercentageMath of AAVEV3.
        // From https://github.com/aave/aave-v3-core/blob/master/contracts/protocol/libraries/math/PercentageMath.sol#L48

        // to avoid overflow, value <= (type(uint256).max - HALF_PERCENTAGE_FACTOR) / percentage
        uint256 PERCENTAGE_FACTOR = 1e4;
        uint256 HALF_PERCENTAGE_FACTOR = 0.5e4;
        assembly {
            if iszero(or(iszero(percentage), iszero(gt(value, div(sub(not(0), HALF_PERCENTAGE_FACTOR), percentage))))) {
                revert(0, 0)
            }

            result := div(add(mul(value, percentage), HALF_PERCENTAGE_FACTOR), PERCENTAGE_FACTOR)
        }
    }
}
