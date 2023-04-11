// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {IERC20} from 'openzeppelin-contracts/contracts/token/ERC20/IERC20.sol';
import {Router, IRouter} from 'src/Router.sol';
import {FeeCalculatorBase} from 'src/fees/FeeCalculatorBase.sol';
import {AaveFlashLoanFeeCalculator} from 'src/fees/AaveFlashLoanFeeCalculator.sol';
import {AaveBorrowFeeCalculator} from 'src/fees/AaveBorrowFeeCalculator.sol';
import {NativeFeeCalculator} from 'src/fees/NativeFeeCalculator.sol';
import {FlashLoanCallbackAaveV2, IFlashLoanCallbackAaveV2} from 'src/FlashLoanCallbackAaveV2.sol';
import {IParam} from 'src/interfaces/IParam.sol';
import {IAgent} from 'src/interfaces/IAgent.sol';
import {IAaveV2Provider} from 'src/interfaces/aaveV2/IAaveV2Provider.sol';
import {MockAavePool} from '../mocks/MockAavePool.sol';
import {MockAaveProvider} from '../mocks/MockAaveProvider.sol';
import {MockERC20} from '../mocks/MockERC20.sol';

interface IAaveV2Pool {
    function flashLoan(
        address receiverAddress,
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata modes,
        address onBehalfOf,
        bytes calldata params,
        uint16 referralCode
    ) external;
}

contract AaveFlashLoanFeeCalculatorTest is Test {
    enum InterestRateMode {
        NONE,
        STABLE,
        VARIABLE
    }

    event FeeCharged(address indexed token, uint256 amount, bytes32 metadata);

    address public constant NATIVE = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address public constant AAVE_V3_PROVIDER = 0x2f39d218133AFaB8F2B819B1066c7E434Ad94E9e;
    address public constant AAVE_V2_PROVIDER = 0xB53C1a33016B2DC2fF3653530bfF1848a515c8c5;
    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public constant AUSDC_V2 = 0xBcca60bB61934080951369a648Fb03DF4F96263C;
    address public constant DUMMY_TO_ADDRESS = address(0);
    bytes4 public constant AAVE_FLASHLOAN_SELECTOR =
        bytes4(keccak256(bytes('flashLoan(address,address[],uint256[],uint256[],address,bytes,uint16)')));
    bytes4 public constant AAVE_BORROW_SELECTOR =
        bytes4(keccak256(bytes('borrow(address,uint256,uint256,uint16,address)')));
    bytes4 public constant NATIVE_FEE_SELECTOR = 0xeeeeeeee;
    uint256 public constant SIGNER_REFERRAL = 1;
    uint256 public constant SKIP = type(uint256).max;
    uint256 public constant BPS_BASE = 10_000;
    bytes32 public constant V2_FLASHLOAN_META_DATA = bytes32(bytes('aave-v2:flashloan'));
    bytes32 public constant V3_FLASHLOAN_META_DATA = bytes32(bytes('aave-v3:flashloan'));
    bytes32 public constant NATIVE_TOKEN_META_DATA = bytes32(bytes('native-token'));

    IAaveV2Pool v2Pool = IAaveV2Pool(IAaveV2Provider(AAVE_V2_PROVIDER).getLendingPool());

    address public user;
    address public user2;
    address public feeCollector;
    Router public router;
    IAgent public userAgent;
    address public flashLoanFeeCalculator;
    address public borrowFeeCalculator;
    address public nativeFeeCalculator;
    IFlashLoanCallbackAaveV2 public flashLoanCallbackV2;

    // Empty arrays
    address[] public tokensReturnEmpty;
    IParam.Fee[] public feesEmpty;
    IParam.Input[] public inputsEmpty;

    function setUp() external {
        user = makeAddr('User');
        feeCollector = makeAddr('FeeCollector');
        address pauser = makeAddr('Pauser');

        // Depoly contracts
        router = new Router(makeAddr('WrappedNative'), pauser, feeCollector);
        vm.prank(user);
        userAgent = IAgent(router.newAgent());
        flashLoanFeeCalculator = address(new AaveFlashLoanFeeCalculator(address(router), 0, AAVE_V3_PROVIDER));
        borrowFeeCalculator = address(new AaveBorrowFeeCalculator(address(router), 0, AAVE_V3_PROVIDER));
        nativeFeeCalculator = address(new NativeFeeCalculator(address(router), 0));
        flashLoanCallbackV2 = new FlashLoanCallbackAaveV2(address(router), AAVE_V2_PROVIDER);

        // Setup fee calculator
        bytes4[] memory selectors = new bytes4[](2);
        selectors[0] = AAVE_FLASHLOAN_SELECTOR;
        selectors[1] = NATIVE_FEE_SELECTOR;
        address[] memory tos = new address[](2);
        tos[0] = address(v2Pool);
        tos[1] = address(DUMMY_TO_ADDRESS);
        address[] memory feeCalculators = new address[](2);
        feeCalculators[0] = address(flashLoanFeeCalculator);
        feeCalculators[1] = address(nativeFeeCalculator);
        router.setFeeCalculators(selectors, tos, feeCalculators);

        vm.label(address(router), 'Router');
        vm.label(address(userAgent), 'UserAgent');
        vm.label(feeCollector, 'FeeCollector');
        vm.label(address(flashLoanFeeCalculator), 'FlashLoanFeeCalculator');
        vm.label(address(nativeFeeCalculator), 'NativeFeeCalculator');
        vm.label(address(v2Pool), 'AaveV2Pool');
        vm.label(AAVE_V2_PROVIDER, 'AaveV2Provider');
        vm.label(address(flashLoanCallbackV2), 'FlashLoanCallbackAaveV2');
        vm.label(USDC, 'USDC');
    }

    function testFeeVerificationFailed() external {
        uint256 feeRate = 20;
        uint256 amount = 100e6;

        // Set fee rate
        FeeCalculatorBase(flashLoanFeeCalculator).setFeeRate(feeRate);

        // Encode flashloan params
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
        logics[0] = _logicAaveV2FlashLoan(tokens, amounts, params);

        // Get new logics and fees
        IParam.Fee[] memory fees;
        (logics, , fees) = router.getLogicsAndFees(logics, 0);

        // Modify fees
        fees[0].amount -= 1;

        _distributeToken(tokens, amounts);

        // Execute
        vm.expectRevert(IRouter.FeeVerificationFailed.selector);
        vm.prank(user);
        router.execute(logics, fees, tokensReturnEmpty, SIGNER_REFERRAL);
    }

    function testEmptyFees() external {
        uint256 feeRate = 20;
        uint256 amount = 100e6;

        // Set fee rate
        FeeCalculatorBase(flashLoanFeeCalculator).setFeeRate(feeRate);

        // Encode flashloan params
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
        logics[0] = _logicAaveV2FlashLoan(tokens, amounts, params);

        _distributeToken(tokens, amounts);

        // Execute
        vm.expectRevert(IRouter.FeeVerificationFailed.selector);
        vm.prank(user);
        router.execute(logics, new IParam.Fee[](0), tokensReturnEmpty, SIGNER_REFERRAL);
    }

    function testChargeFlashLoanFee(uint256 amount, uint256 feeRate) external {
        feeRate = bound(feeRate, 0, BPS_BASE - 1);
        amount = bound(amount, 1, (IERC20(USDC).balanceOf(AUSDC_V2) * (BPS_BASE - feeRate)) / BPS_BASE);

        // Set fee rate
        FeeCalculatorBase(flashLoanFeeCalculator).setFeeRate(feeRate);

        // Encode flashloan params
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
        logics[0] = _logicAaveV2FlashLoan(tokens, amounts, params);

        // Get new logics and fees
        IParam.Fee[] memory fees;
        (logics, , fees) = router.getLogicsAndFees(logics, 0);

        _distributeToken(tokens, amounts);

        // Prepare assert data
        uint256 expectedNewAmount = FeeCalculatorBase(flashLoanFeeCalculator).calculateAmountWithFee(amount);
        uint256 expectedFee = FeeCalculatorBase(flashLoanFeeCalculator).calculateFee(expectedNewAmount);
        uint256 feeCollectorBalanceBefore = IERC20(USDC).balanceOf(feeCollector);
        uint256[] memory newAmounts = this.decodeFlashLoanAmounts(logics[0]);

        // Execute
        vm.expectEmit(true, true, true, true, address(userAgent));
        emit FeeCharged(USDC, expectedFee, V2_FLASHLOAN_META_DATA);
        vm.prank(user);
        router.execute(logics, fees, tokensReturnEmpty, SIGNER_REFERRAL);

        assertEq(IERC20(USDC).balanceOf(address(router)), 0);
        assertEq(IERC20(USDC).balanceOf(address(userAgent)), 0);
        assertEq(IERC20(USDC).balanceOf(feeCollector) - feeCollectorBalanceBefore, expectedFee);
        assertEq(newAmounts[0], expectedNewAmount);
    }

    function testFeeVerificationFailedWithFeeScenarioInside() external {
        uint256 feeRate = 20;
        uint256 amount = 100e6;
        uint256 nativeAmount = 1 ether;

        // Set fee rate
        FeeCalculatorBase(flashLoanFeeCalculator).setFeeRate(feeRate);
        FeeCalculatorBase(nativeFeeCalculator).setFeeRate(feeRate);

        // Encode flashloan params
        IParam.Logic[] memory flashLoanLogics = new IParam.Logic[](2);
        flashLoanLogics[0] = _logicTransferFlashLoanAmountAndFee(
            address(flashLoanCallbackV2),
            USDC,
            FeeCalculatorBase(flashLoanFeeCalculator).calculateAmountWithFee(amount)
        );
        flashLoanLogics[1] = _logicSendNativeToken(user2, nativeAmount);
        bytes memory params = abi.encode(flashLoanLogics, feesEmpty, tokensReturnEmpty);

        IParam.Logic[] memory logics = new IParam.Logic[](1);
        IParam.Fee[] memory fees;
        uint256 nativeNewAmount;
        {
            // Encode logic
            address[] memory tokens = new address[](1);
            tokens[0] = USDC;

            uint256[] memory amounts = new uint256[](1);
            amounts[0] = amount;

            logics[0] = _logicAaveV2FlashLoan(tokens, amounts, params);

            // Get new logics and fees
            (logics, nativeNewAmount, fees) = router.getLogicsAndFees(logics, nativeAmount);
            deal(user, nativeNewAmount);
            _distributeToken(tokens, amounts);

            // Modify fees
            fees[1].amount -= 1;
        }

        {
            // Execute
            address[] memory tokensReturns = new address[](1);
            tokensReturns[0] = USDC;
            vm.expectRevert(IRouter.FeeVerificationFailed.selector);
            vm.prank(user);
            router.execute{value: nativeNewAmount}(logics, fees, tokensReturns, SIGNER_REFERRAL);
        }
    }

    function testChargeFlashLoanFeeWithFeeScenarioInside(
        uint256 amount,
        uint256 nativeAmount,
        uint256 feeRate
    ) external {
        feeRate = bound(feeRate, 0, BPS_BASE - 1);
        amount = bound(amount, 1, (IERC20(USDC).balanceOf(AUSDC_V2) * (BPS_BASE - feeRate)) / BPS_BASE);
        nativeAmount = bound(nativeAmount, 0, 5000 ether);

        // Set fee rate
        FeeCalculatorBase(flashLoanFeeCalculator).setFeeRate(feeRate);
        FeeCalculatorBase(nativeFeeCalculator).setFeeRate(feeRate);

        // Encode flashloan params
        IParam.Logic[] memory flashLoanLogics = new IParam.Logic[](2);
        flashLoanLogics[0] = _logicTransferFlashLoanAmountAndFee(
            address(flashLoanCallbackV2),
            USDC,
            FeeCalculatorBase(flashLoanFeeCalculator).calculateAmountWithFee(amount)
        );
        flashLoanLogics[1] = _logicSendNativeToken(user2, nativeAmount);
        bytes memory params = abi.encode(flashLoanLogics, feesEmpty, tokensReturnEmpty);

        IParam.Logic[] memory logics = new IParam.Logic[](1);
        IParam.Fee[] memory fees;
        uint256 nativeNewAmount;
        {
            // Encode logic
            address[] memory tokens = new address[](1);
            tokens[0] = USDC;

            uint256[] memory amounts = new uint256[](1);
            amounts[0] = amount;

            logics[0] = _logicAaveV2FlashLoan(tokens, amounts, params);

            // Get new logics and fees
            (logics, nativeNewAmount, fees) = router.getLogicsAndFees(logics, nativeAmount);
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
            address[] memory tokensReturns = new address[](1);
            tokensReturns[0] = USDC;
            vm.expectEmit(true, true, true, true, address(userAgent));
            emit FeeCharged(USDC, expectedFee, V2_FLASHLOAN_META_DATA);
            emit FeeCharged(NATIVE, expectedNativeFee, NATIVE_TOKEN_META_DATA);
            vm.prank(user);
            router.execute{value: nativeNewAmount}(logics, fees, tokensReturns, SIGNER_REFERRAL);
        }

        assertEq(IERC20(USDC).balanceOf(address(router)), 0);
        assertEq(IERC20(USDC).balanceOf(address(userAgent)), 0);
        assertEq(IERC20(USDC).balanceOf(feeCollector) - feeCollectorBalanceBefore, expectedFee);
        assertEq(feeCollector.balance - feeCollectorNativeBalanceBefore, expectedNativeFee);
        assertEq(user2.balance - user2NativeBalanceBefore, nativeAmount);
    }

    function testChargeFlashLoanFeeWithTwoFeeScenarioInside(
        uint256 amount,
        uint256 nativeAmount,
        uint256 feeRate
    ) external {
        // TODO
    }

    function testChargeFlashLoanFeeV3(uint256 amount, uint256 feeRate) external {
        // TODO
    }

    function decodeFlashLoanAmounts(IParam.Logic calldata logic) external pure returns (uint256[] memory) {
        bytes calldata data = logic.data;
        (, , uint256[] memory amounts, , , , ) = abi.decode(
            data[4:],
            (address, address[], uint256[], uint256[], address, bytes, uint16)
        );
        return amounts;
    }

    function _logicAaveV2FlashLoan(
        address[] memory tokens,
        uint256[] memory amounts,
        bytes memory params
    ) internal view returns (IParam.Logic memory) {
        uint256[] memory modes = new uint256[](1);
        modes[0] = uint256(InterestRateMode.NONE);

        return
            IParam.Logic(
                address(v2Pool), // to
                abi.encodeWithSelector(
                    AAVE_FLASHLOAN_SELECTOR,
                    address(flashLoanCallbackV2), // receiverAddress
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
                address(flashLoanCallbackV2)
            );
    }

    function _logicAaveBorrow(address token, uint256 amount) internal view returns (IParam.Logic memory) {
        return
            IParam.Logic(
                address(v2Pool), // to
                abi.encodeWithSelector(
                    AAVE_BORROW_SELECTOR,
                    token,
                    amount,
                    0, // interestRateMode
                    0, // referralCode
                    address(0) // onBehalfOf
                ),
                inputsEmpty,
                IParam.WrapMode.NONE,
                address(0), // approveTo
                address(0) // callback
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

    function _distributeToken(address[] memory tokens, uint256[] memory amounts) internal {
        for (uint256 i = 0; i < tokens.length; ++i) {
            uint256 amountWithRouterFee = FeeCalculatorBase(flashLoanFeeCalculator).calculateAmountWithFee(amounts[i]);

            // Airdrop aave flashloan fee and router flashloan fee to agent
            uint256 aaveFee = (amountWithRouterFee * 9) / BPS_BASE;
            uint256 routerFee = FeeCalculatorBase(flashLoanFeeCalculator).calculateFee(amountWithRouterFee);

            deal(tokens[i], address(userAgent), aaveFee + routerFee);
        }
    }
}
