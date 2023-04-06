// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {IERC20} from 'openzeppelin-contracts/contracts/token/ERC20/IERC20.sol';
import {Router, IRouter} from 'src/Router.sol';
import {AaveFlashLoanFeeCalculator} from 'src/fees/AaveFlashLoanFeeCalculator.sol';
import {AaveBorrowFeeCalculator} from 'src/fees/AaveBorrowFeeCalculator.sol';
import {FlashLoanCallbackAaveV2, IFlashLoanCallbackAaveV2} from 'src/FlashLoanCallbackAaveV2.sol';
import {IParam} from 'src/interfaces/IParam.sol';
import {IAgent} from 'src/interfaces/IAgent.sol';
import {IFeeCalculator} from 'src/interfaces/IFeeCalculator.sol';
import {FeeCalculatorUtils, IFeeBase} from 'test/utils/FeeCalculatorUtils.sol';
import {MockAavePool} from '../mocks/MockAavePool.sol';
import {MockAaveProvider} from '../mocks/MockAaveProvider.sol';
import {MockERC20} from '../mocks/MockERC20.sol';
import 'forge-std/console.sol';

contract AaveFeeCalculatorTest is Test, FeeCalculatorUtils {
    address public constant NATIVE = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    uint256 public constant SKIP = type(uint256).max;
    bytes4 public constant AAVE_FLASHLOAN_SELECTOR =
        bytes4(keccak256(bytes('flashLoan(address,address[],uint256[],uint256[],address,bytes,uint16)')));
    bytes4 public constant AAVE_BORROW_SELECTOR =
        bytes4(keccak256(bytes('borrow(address,uint256,uint256,uint16,address)')));
    uint256 public constant SIGNER_REFERRAL = 1;

    address public user;
    address public feeCollector;
    IRouter public router;
    IAgent public userAgent;
    IFeeCalculator public flashLoanFeeCalculator;
    IFeeCalculator public borrowFeeCalculator;
    MockERC20 public mockERC20;
    MockAavePool public mockAavePool;
    MockAaveProvider public mockAaveProvider;
    IFlashLoanCallbackAaveV2 public flashLoanCallbackV2;

    // Empty arrays
    address[] public tokensReturnEmpty;
    IParam.Input[] public inputsEmpty;

    function setUp() external {
        user = makeAddr('User');
        feeCollector = makeAddr('FeeCollector');
        address pauser = makeAddr('Pauser');

        // Depoly contracts
        router = new Router(makeAddr('WrappedNative'), pauser, feeCollector);
        vm.prank(user);
        userAgent = IAgent(router.newAgent());
        flashLoanFeeCalculator = new AaveFlashLoanFeeCalculator(address(router), ZERO_FEE_RATE);
        borrowFeeCalculator = new AaveBorrowFeeCalculator(address(router), ZERO_FEE_RATE);
        mockERC20 = new MockERC20('mockERC20', 'mock');
        address[] memory tokens = new address[](1);
        tokens[0] = address(mockERC20);
        mockAavePool = new MockAavePool(tokens);
        mockAaveProvider = new MockAaveProvider(address(mockAavePool));
        flashLoanCallbackV2 = new FlashLoanCallbackAaveV2(address(router), address(mockAaveProvider));

        // Setup fee calculator
        bytes4[] memory selectors = new bytes4[](2);
        selectors[0] = AAVE_FLASHLOAN_SELECTOR;
        selectors[1] = AAVE_BORROW_SELECTOR;
        address[] memory tos = new address[](2);
        tos[0] = address(mockAavePool);
        tos[1] = address(mockAavePool);
        address[] memory feeCalculators = new address[](2);
        feeCalculators[0] = address(flashLoanFeeCalculator);
        feeCalculators[1] = address(borrowFeeCalculator);
        router.setFeeCalculators(selectors, tos, feeCalculators);

        vm.label(address(router), 'Router');
        vm.label(address(userAgent), 'UserAgent');
        vm.label(feeCollector, 'FeeCollector');
        vm.label(address(flashLoanFeeCalculator), 'FlashLoanFeeCalculator');
        vm.label(address(borrowFeeCalculator), 'BorrowFeeCalculator');
        vm.label(address(mockERC20), 'MockERC20');
        vm.label(address(mockAavePool), 'MockAavePool');
        vm.label(address(mockAaveProvider), 'MockAaveProvider');
        vm.label(address(flashLoanCallbackV2), 'FlashLoanCallbackAaveV2');
    }

    function testChargeFlashLoanFee(uint256 amount, uint256 feeRate) external {
        amount = bound(amount, 1e6, 1e12 ether);
        feeRate = bound(feeRate, 0, BPS_BASE - 1);

        // Set fee rate
        IFeeBase(address(flashLoanFeeCalculator)).setFeeRate(feeRate);

        // Encode flashloan params
        IParam.Logic[] memory flashLoanLogics = new IParam.Logic[](1);
        flashLoanLogics[0] = _logicTransferFlashLoanAmountAndFee(
            address(flashLoanCallbackV2),
            address(mockERC20),
            _calculateAmountWithFee(amount, feeRate)
        );
        bytes memory params = abi.encode(flashLoanLogics, new IParam.Fee[](0), new address[](0));

        // Encode logic
        address[] memory tokens = new address[](1);
        tokens[0] = address(mockERC20);

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;

        IParam.Logic[] memory logics = new IParam.Logic[](1);
        logics[0] = _logicAaveV2FlashLoan(tokens, amounts, params);

        // Get new logics and fees
        IParam.Fee[] memory fees;
        (logics, fees, ) = router.getLogicsAndFees(logics, 0);

        _distributeToken(tokens, amounts, feeRate);

        // Prepare assert data
        uint256 expectedNewAmount = _calculateAmountWithFee(amount, feeRate);
        uint256 expectedFee = _calculateFee(expectedNewAmount, feeRate);
        uint256 feeCollectorBalanceBefore = IERC20(mockERC20).balanceOf(feeCollector);
        uint256[] memory newAmounts = this.decodeFlashLoanAmounts(logics[0]);

        // Execute
        vm.prank(user);
        router.execute(logics, fees, tokensReturnEmpty, SIGNER_REFERRAL);

        assertEq(IERC20(mockERC20).balanceOf(address(router)), 0);
        assertEq(IERC20(mockERC20).balanceOf(address(userAgent)), 0);
        assertEq(IERC20(mockERC20).balanceOf(feeCollector) - feeCollectorBalanceBefore, expectedFee);
        assertEq(newAmounts[0], expectedNewAmount);
    }

    function testChargeAaveBorrowFee(uint256 amount, uint256 feeRate) external {
        amount = bound(amount, 1e6, 1e12 ether);
        feeRate = bound(feeRate, 0, BPS_BASE - 1);

        // Set fee rate
        IFeeBase(address(borrowFeeCalculator)).setFeeRate(feeRate);

        // Encode logic
        IParam.Logic[] memory logics = new IParam.Logic[](1);
        logics[0] = _logicAaveBorrow(address(mockERC20), amount);

        // Get new logics
        IParam.Fee[] memory fees;
        (logics, fees, ) = router.getLogicsAndFees(logics, 0);

        // Prepare assert data
        uint256 expectedNewAmount = _calculateAmountWithFee(amount, feeRate);
        uint256 expectedFee = _calculateFee(expectedNewAmount, feeRate);
        uint256 feeCollectorBalanceBefore = IERC20(mockERC20).balanceOf(feeCollector);
        uint256 newAmount = this.decodeBorrowAmount(logics[0]);

        // Execute
        address[] memory tokensReturns = new address[](1);
        tokensReturns[0] = address(mockERC20);
        vm.prank(user);
        router.execute(logics, fees, tokensReturns, SIGNER_REFERRAL);

        assertEq(IERC20(mockERC20).balanceOf(address(router)), 0);
        assertEq(IERC20(mockERC20).balanceOf(address(userAgent)), 0);
        assertEq(IERC20(mockERC20).balanceOf(feeCollector) - feeCollectorBalanceBefore, expectedFee);
        assertEq(IERC20(mockERC20).balanceOf(user), amount);
        assertEq(newAmount, expectedNewAmount);
    }

    function testChargeFlashLoanFeeWithFeeScenarioInside(uint256 amount, uint256 feeRate) external {
        amount = bound(amount, 1e6, 1e12 ether);
        feeRate = bound(feeRate, 0, BPS_BASE - 1);

        // Set fee rate
        IFeeBase(address(flashLoanFeeCalculator)).setFeeRate(feeRate);
        IFeeBase(address(borrowFeeCalculator)).setFeeRate(feeRate);

        // Encode flashloan params
        IParam.Logic[] memory flashLoanLogics = new IParam.Logic[](2);
        flashLoanLogics[0] = _logicTransferFlashLoanAmountAndFee(
            address(flashLoanCallbackV2),
            address(mockERC20),
            _calculateAmountWithFee(amount, feeRate)
        );
        flashLoanLogics[1] = _logicAaveBorrow(address(mockERC20), amount);
        bytes memory params = abi.encode(flashLoanLogics, new IParam.Fee[](0), new address[](0));

        // Encode logic
        address[] memory tokens = new address[](1);
        tokens[0] = address(mockERC20);

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;

        IParam.Logic[] memory logics = new IParam.Logic[](1);
        logics[0] = _logicAaveV2FlashLoan(tokens, amounts, params);

        // Get new logics and fees
        IParam.Fee[] memory fees;
        (logics, fees, ) = router.getLogicsAndFees(logics, 0);

        _distributeToken(tokens, amounts, feeRate);

        // Prepare assert data
        uint256 expectedNewAmount = _calculateAmountWithFee(amount, feeRate);
        uint256 expectedFee = _calculateFee(expectedNewAmount, feeRate);
        uint256 feeCollectorBalanceBefore = IERC20(mockERC20).balanceOf(feeCollector);

        // Execute
        address[] memory tokensReturns = new address[](1);
        tokensReturns[0] = address(mockERC20);
        vm.prank(user);
        router.execute(logics, fees, tokensReturns, SIGNER_REFERRAL);

        assertEq(IERC20(mockERC20).balanceOf(address(router)), 0);
        assertEq(IERC20(mockERC20).balanceOf(address(userAgent)), 0);
        assertEq(IERC20(mockERC20).balanceOf(feeCollector) - feeCollectorBalanceBefore, expectedFee * 2);
        assertEq(IERC20(mockERC20).balanceOf(user), amount);
    }

    function decodeFlashLoanAmounts(IParam.Logic calldata logic) external pure returns (uint256[] memory) {
        bytes calldata data = logic.data;
        (, , uint256[] memory amounts, , , , ) = abi.decode(
            data[4:],
            (address, address[], uint256[], uint256[], address, bytes, uint16)
        );
        return amounts;
    }

    function decodeBorrowAmount(IParam.Logic calldata logic) external pure returns (uint256) {
        bytes calldata data = logic.data;
        (, uint256 amount, , , ) = abi.decode(data[4:], (address, uint256, uint256, uint16, address));
        return amount;
    }

    function _logicAaveV2FlashLoan(
        address[] memory tokens,
        uint256[] memory amounts,
        bytes memory params
    ) internal view returns (IParam.Logic memory) {
        return
            IParam.Logic(
                address(mockAavePool), // to
                abi.encodeWithSelector(
                    AAVE_FLASHLOAN_SELECTOR,
                    address(flashLoanCallbackV2), // receiverAddress
                    tokens,
                    amounts,
                    new uint256[](0), // modes
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
                address(mockAavePool), // to
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
                address(token),
                abi.encodeWithSelector(IERC20.transfer.selector, to, amount + fee),
                inputsEmpty,
                IParam.WrapMode.NONE,
                address(0), // approveTo
                address(0) // callback
            );
    }

    function _distributeToken(address[] memory tokens, uint256[] memory amounts, uint256 feeRate) internal {
        for (uint256 i = 0; i < tokens.length; ++i) {
            uint256 amountWithRouterFee = _calculateAmountWithFee(amounts[i], feeRate);

            // Airdrop aave flashloan fee to agent
            uint256 aaveFee = (amountWithRouterFee * 9) / BPS_BASE;
            MockERC20(tokens[i]).mint(address(userAgent), aaveFee);

            // Airdrop router flashloan fee to agent
            uint256 routerFee = _calculateFee(amountWithRouterFee, feeRate);
            MockERC20(tokens[i]).mint(address(userAgent), routerFee);
        }
    }
}
