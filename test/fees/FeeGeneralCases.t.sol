// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {IERC20} from 'openzeppelin-contracts/contracts/token/ERC20/IERC20.sol';
import {Router, IRouter} from 'src/Router.sol';
import {FeeGenerator} from 'src/fees/FeeGenerator.sol';
import {FeeCalculatorBase} from 'src/fees/FeeCalculatorBase.sol';
import {AaveFlashLoanFeeCalculator} from 'src/fees/AaveFlashLoanFeeCalculator.sol';
import {NativeFeeCalculator} from 'src/fees/NativeFeeCalculator.sol';
import {AaveV2FlashLoanCallback, IAaveV2FlashLoanCallback} from 'src/callbacks/AaveV2FlashLoanCallback.sol';
import {IParam} from 'src/interfaces/IParam.sol';
import {IAgent} from 'src/interfaces/IAgent.sol';
import {IAaveV2Provider} from 'src/interfaces/aaveV2/IAaveV2Provider.sol';

contract FeeGeneralCasesTest is Test {
    enum InterestRateMode {
        NONE,
        STABLE,
        VARIABLE
    }

    event FeeCalculatorSet(bytes4 indexed selector, address indexed to, address indexed feeCalculator);

    address public constant NATIVE = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address public constant AAVE_V2_PROVIDER = 0xB53C1a33016B2DC2fF3653530bfF1848a515c8c5;
    address public constant AAVE_V3_PROVIDER = 0x2f39d218133AFaB8F2B819B1066c7E434Ad94E9e;
    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public constant ANY_TO_ADDRESS = address(0);
    bytes4 public constant AAVE_FLASHLOAN_SELECTOR =
        bytes4(keccak256(bytes('flashLoan(address,address[],uint256[],uint256[],address,bytes,uint16)')));
    bytes4 public constant NATIVE_FEE_SELECTOR = 0xeeeeeeee;
    uint256 public constant SKIP = 0x8000000000000000000000000000000000000000000000000000000000000000;
    uint256 public constant BPS_BASE = 10_000;
    uint256 public constant SIGNER_REFERRAL = 1;
    uint256 public constant FEE_RATE = 20;

    address v2Pool = IAaveV2Provider(AAVE_V2_PROVIDER).getLendingPool();

    address public user;
    address public feeCollector;
    Router public router;
    IAgent public userAgent;
    address public flashLoanFeeCalculator;
    address public nativeFeeCalculator;
    IAaveV2FlashLoanCallback public flashLoanCallbackV2;

    // Empty arrays
    address[] public tokensReturnEmpty;
    IParam.Fee[] public feesEmpty;
    IParam.Input[] public inputsEmpty;

    function setUp() external {
        user = makeAddr('User');
        feeCollector = makeAddr('FeeCollector');
        address pauser = makeAddr('Pauser');

        // Depoly contracts
        router = new Router(makeAddr('WrappedNative'), address(this), pauser, feeCollector);
        vm.prank(user);
        userAgent = IAgent(router.newAgent());
        flashLoanFeeCalculator = address(new AaveFlashLoanFeeCalculator(address(router), FEE_RATE, AAVE_V3_PROVIDER));
        nativeFeeCalculator = address(new NativeFeeCalculator(address(router), FEE_RATE));
        flashLoanCallbackV2 = new AaveV2FlashLoanCallback(address(router), AAVE_V2_PROVIDER);

        // Setup fee calculator
        bytes4[] memory selectors = new bytes4[](2);
        selectors[0] = AAVE_FLASHLOAN_SELECTOR;
        selectors[1] = NATIVE_FEE_SELECTOR;
        address[] memory tos = new address[](2);
        tos[0] = v2Pool;
        tos[1] = ANY_TO_ADDRESS;
        address[] memory feeCalculators = new address[](2);
        feeCalculators[0] = address(flashLoanFeeCalculator);
        feeCalculators[1] = address(nativeFeeCalculator);
        router.setFeeCalculators(selectors, tos, feeCalculators);

        vm.label(address(router), 'Router');
        vm.label(address(userAgent), 'UserAgent');
        vm.label(feeCollector, 'FeeCollector');
        vm.label(flashLoanFeeCalculator, 'FlashLoanFeeCalculator');
        vm.label(nativeFeeCalculator, 'NativeFeeCalculator');
        vm.label(v2Pool, 'AaveV2Pool');
        vm.label(AAVE_V2_PROVIDER, 'AaveV2Provider');
        vm.label(address(flashLoanCallbackV2), 'AaveV2FlashLoanCallback');
        vm.label(USDC, 'USDC');
    }

    function testInvalidFeeRateSender() external {
        vm.expectRevert(FeeCalculatorBase.InvalidSender.selector);
        vm.prank(user);
        FeeCalculatorBase(nativeFeeCalculator).setFeeRate(99);
    }

    function testInvalidFeeRate() external {
        vm.expectRevert(FeeCalculatorBase.InvalidRate.selector);
        FeeCalculatorBase(nativeFeeCalculator).setFeeRate(BPS_BASE);
    }

    function testFeesNotIncludedInLogics() external {
        IParam.Logic[] memory logics = _buildFlashLoanLogics();

        // Execute
        vm.expectRevert();
        vm.prank(user);
        router.execute(logics, tokensReturnEmpty, SIGNER_REFERRAL);
    }

    function testMsgValueNotEnoughForFees() external {
        uint256 nativeAmount = 1 ether;
        IParam.Logic[] memory logics = new IParam.Logic[](1);
        logics[0] = _logicSendNativeToken(feeCollector, nativeAmount);

        // Execute
        deal(user, nativeAmount);
        vm.expectRevert('Address: insufficient balance');
        vm.prank(user);
        router.execute{value: nativeAmount}(logics, tokensReturnEmpty, SIGNER_REFERRAL);
    }

    function testSetFeeCalculator(bytes4 selector, address to, address feeCalculator) external {
        vm.expectEmit(true, true, true, true, address(router));
        emit FeeCalculatorSet(selector, to, feeCalculator);
        router.setFeeCalculator(selector, to, feeCalculator);
    }

    function testSetFeeCalculators() external {
        bytes4[] memory selectors = new bytes4[](2);
        selectors[0] = AAVE_FLASHLOAN_SELECTOR;
        selectors[1] = NATIVE_FEE_SELECTOR;

        address[] memory tos = new address[](2);
        tos[0] = v2Pool;
        tos[1] = ANY_TO_ADDRESS;

        address[] memory feeCalculators = new address[](2);
        feeCalculators[0] = address(flashLoanFeeCalculator);
        feeCalculators[1] = address(nativeFeeCalculator);

        vm.expectEmit(true, true, true, true, address(router));
        emit FeeCalculatorSet(AAVE_FLASHLOAN_SELECTOR, v2Pool, address(flashLoanFeeCalculator));
        emit FeeCalculatorSet(NATIVE_FEE_SELECTOR, ANY_TO_ADDRESS, address(nativeFeeCalculator));
        router.setFeeCalculators(selectors, tos, feeCalculators);
    }

    function testSetFeeCalculatorsLengthMismatch() external {
        bytes4[] memory selectors = new bytes4[](2);
        address[] memory tos = new address[](1);
        address[] memory feeCalculators = new address[](3);

        // selectors.length != tos.length
        vm.expectRevert(FeeGenerator.LengthMismatch.selector);
        router.setFeeCalculators(selectors, tos, feeCalculators);

        // selectors.length != feeCalculators.length
        tos = new address[](2);
        vm.expectRevert(FeeGenerator.LengthMismatch.selector);
        router.setFeeCalculators(selectors, tos, feeCalculators);
    }

    function _buildFlashLoanLogics() internal view returns (IParam.Logic[] memory) {
        uint256 amount = 100e6;

        // Encode flash loan params
        IParam.Logic[] memory flashLoanLogics = new IParam.Logic[](1);
        flashLoanLogics[0] = _logicTransferFlashLoanAmountAndFee(
            address(flashLoanCallbackV2),
            USDC,
            FeeCalculatorBase(flashLoanFeeCalculator).calculateAmountWithFee(amount)
        );
        bytes memory params = abi.encode(flashLoanLogics, feesEmpty, tokensReturnEmpty);

        // Encode logic
        address[] memory tokens = new address[](1);
        tokens[0] = USDC;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;

        IParam.Logic[] memory logics = new IParam.Logic[](1);
        logics[0] = _logicAaveFlashLoan(v2Pool, address(flashLoanCallbackV2), tokens, amounts, params);

        return logics;
    }

    function _logicTransferFlashLoanAmountAndFee(
        address to,
        address token,
        uint256 amount
    ) internal view returns (IParam.Logic memory) {
        uint256 fee = (amount * 9) / BPS_BASE;
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
}
