// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {SafeERC20, IERC20} from 'openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol';
import {Router} from 'src/Router.sol';
import {FeeCalculatorBase} from 'src/fees/FeeCalculatorBase.sol';
import {AaveFlashLoanFeeCalculator} from 'src/fees/AaveFlashLoanFeeCalculator.sol';
import {AaveBorrowFeeCalculator} from 'src/fees/AaveBorrowFeeCalculator.sol';
import {AaveV3FlashLoanCallback, IAaveV3FlashLoanCallback} from 'src/callbacks/AaveV3FlashLoanCallback.sol';
import {IAaveV2Provider} from 'src/interfaces/aaveV2/IAaveV2Provider.sol';
import {IAaveV3Provider} from 'src/interfaces/aaveV3/IAaveV3Provider.sol';
import {IParam} from 'src/interfaces/IParam.sol';
import {IAgent} from 'src/interfaces/IAgent.sol';

interface IDebtToken {
    function UNDERLYING_ASSET_ADDRESS() external view returns (address);

    function approveDelegation(address delegatee, uint256 amount) external;

    function totalSupply() external view returns (uint256);
}

interface IAavePool {
    function deposit(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external;

    function supply(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external;

    function borrow(
        address asset,
        uint256 amount,
        uint256 interestRateMode,
        uint16 referralCode,
        address onBehalfOf
    ) external;
}

contract AaveBorrowFeeCalculatorTest is Test {
    using SafeERC20 for IERC20;

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
    address public constant AUSDC_V2 = 0xBcca60bB61934080951369a648Fb03DF4F96263C;
    address public constant AUSDC_V3 = 0x98C23E9d8f34FEFb1B7BD6a91B7FF122F4e16F5c;
    bytes4 public constant AAVE_BORROW_SELECTOR =
        bytes4(keccak256(bytes('borrow(address,uint256,uint256,uint16,address)')));
    uint256 public constant SIGNER_REFERRAL = 1;
    uint256 public constant BPS_BASE = 10_000;
    IDebtToken public constant AUSDC_V2_DEBT_VARIABLE = IDebtToken(0x619beb58998eD2278e08620f97007e1116D5D25b);
    IDebtToken public constant AUSDC_V3_DEBT_VARIABLE = IDebtToken(0x72E95b8931767C79bA4EeE721354d6E99a61D004);
    bytes32 public constant V2_BORROW_META_DATA = bytes32(bytes('aave-v2:borrow'));
    bytes32 public constant V3_BORROW_META_DATA = bytes32(bytes('aave-v3:borrow'));

    address v2Pool = IAaveV2Provider(AAVE_V2_PROVIDER).getLendingPool();
    address v3Pool = IAaveV3Provider(AAVE_V3_PROVIDER).getPool();

    address public user;
    address public feeCollector;
    Router public router;
    IAgent public userAgent;
    address public borrowFeeCalculator;

    // Empty arrays
    address[] public tokensReturnEmpty;
    IParam.Input[] public inputsEmpty;

    function setUp() external {
        user = makeAddr('User');
        feeCollector = makeAddr('FeeCollector');
        address pauser = makeAddr('Pauser');

        // Depoly contracts
        router = new Router(makeAddr('WrappedNative'), address(this), pauser, feeCollector);
        vm.prank(user);
        userAgent = IAgent(router.newAgent());
        borrowFeeCalculator = address(new AaveBorrowFeeCalculator(address(router), 0, AAVE_V3_PROVIDER));

        // User approved agent aave v3 delegation
        vm.startPrank(user);
        AUSDC_V2_DEBT_VARIABLE.approveDelegation(address(userAgent), type(uint256).max);
        AUSDC_V3_DEBT_VARIABLE.approveDelegation(address(userAgent), type(uint256).max);
        vm.stopPrank();

        // Setup fee calculator
        bytes4[] memory selectors = new bytes4[](2);
        selectors[0] = AAVE_BORROW_SELECTOR;
        selectors[1] = AAVE_BORROW_SELECTOR;
        address[] memory tos = new address[](2);
        tos[0] = v2Pool;
        tos[1] = v3Pool;
        address[] memory feeCalculators = new address[](2);
        feeCalculators[0] = borrowFeeCalculator;
        feeCalculators[1] = borrowFeeCalculator;
        router.setFeeCalculators(selectors, tos, feeCalculators);

        vm.label(address(router), 'Router');
        vm.label(address(userAgent), 'UserAgent');
        vm.label(feeCollector, 'FeeCollector');
        vm.label(address(borrowFeeCalculator), 'BorrowFeeCalculator');
        vm.label(v2Pool, 'AaveV2Pool');
        vm.label(v3Pool, 'AaveV3Pool');
        vm.label(AUSDC_V2, 'aUSDCV2');
        vm.label(AUSDC_V3, 'aUSDCV3');
        vm.label(address(AUSDC_V2_DEBT_VARIABLE), 'variableDebtUSDCV2');
        vm.label(address(AUSDC_V3_DEBT_VARIABLE), 'variableDebtUSDCV3');
    }

    function testChargeAaveV2BorrowFee(uint256 amount, uint256 feeRate) external {
        feeRate = bound(feeRate, 0, BPS_BASE - 1);
        amount = bound(amount, 1, (AUSDC_V2_DEBT_VARIABLE.totalSupply() * (BPS_BASE - feeRate)) / BPS_BASE);

        // Set fee rate
        FeeCalculatorBase(borrowFeeCalculator).setFeeRate(feeRate);

        address collateral = AUSDC_V2_DEBT_VARIABLE.UNDERLYING_ASSET_ADDRESS();
        vm.label(collateral, 'Collateral');

        _setupCollateral(v2Pool, collateral, amount);

        // Encode logic
        IParam.Logic[] memory logics = new IParam.Logic[](1);
        logics[0] = _logicAaveBorrow(v2Pool, collateral, amount, uint256(InterestRateMode.VARIABLE));

        // Get new logics
        (logics, ) = router.getUpdatedLogicsAndMsgValue(logics, 0);

        // Prepare assert data
        uint256 expectedNewAmount = FeeCalculatorBase(borrowFeeCalculator).calculateAmountWithFee(amount);
        uint256 expectedFee = FeeCalculatorBase(borrowFeeCalculator).calculateFee(expectedNewAmount);
        uint256 feeCollectorBalanceBefore = IERC20(collateral).balanceOf(feeCollector);
        uint256 newAmount = this.decodeBorrowAmount(logics[0]);

        // Execute
        address[] memory tokensReturns = new address[](1);
        tokensReturns[0] = collateral;
        if (expectedFee > 0) {
            vm.expectEmit(true, true, true, true, address(userAgent));
            emit FeeCharged(collateral, expectedFee, V2_BORROW_META_DATA);
        }
        vm.prank(user);
        router.execute(logics, tokensReturns, SIGNER_REFERRAL);

        assertEq(IERC20(collateral).balanceOf(address(router)), 0);
        assertEq(IERC20(collateral).balanceOf(address(userAgent)), 0);
        assertEq(IERC20(collateral).balanceOf(feeCollector) - feeCollectorBalanceBefore, expectedFee);
        assertEq(IERC20(collateral).balanceOf(user), amount);
        assertEq(newAmount, expectedNewAmount);
    }

    function testChargeAaveV3BorrowFee(uint256 amount, uint256 feeRate) external {
        feeRate = bound(feeRate, 0, BPS_BASE - 1);
        amount = bound(amount, 1, (AUSDC_V3_DEBT_VARIABLE.totalSupply() * (BPS_BASE - feeRate)) / BPS_BASE);

        // Set fee rate
        FeeCalculatorBase(borrowFeeCalculator).setFeeRate(feeRate);

        address collateral = AUSDC_V3_DEBT_VARIABLE.UNDERLYING_ASSET_ADDRESS();
        vm.label(collateral, 'Collateral');

        _setupCollateral(v3Pool, collateral, amount);

        // Encode logic
        IParam.Logic[] memory logics = new IParam.Logic[](1);
        logics[0] = _logicAaveBorrow(v3Pool, collateral, amount, uint256(InterestRateMode.VARIABLE));

        // Get new logics
        (logics, ) = router.getUpdatedLogicsAndMsgValue(logics, 0);

        // Prepare assert data
        uint256 expectedNewAmount = FeeCalculatorBase(borrowFeeCalculator).calculateAmountWithFee(amount);
        uint256 expectedFee = FeeCalculatorBase(borrowFeeCalculator).calculateFee(expectedNewAmount);
        uint256 feeCollectorBalanceBefore = IERC20(collateral).balanceOf(feeCollector);
        uint256 newAmount = this.decodeBorrowAmount(logics[0]);

        // Execute
        address[] memory tokensReturns = new address[](1);
        tokensReturns[0] = collateral;
        if (expectedFee > 0) {
            vm.expectEmit(true, true, true, true, address(userAgent));
            emit FeeCharged(collateral, expectedFee, V3_BORROW_META_DATA);
        }
        vm.prank(user);
        router.execute(logics, tokensReturns, SIGNER_REFERRAL);

        assertEq(IERC20(collateral).balanceOf(address(router)), 0);
        assertEq(IERC20(collateral).balanceOf(address(userAgent)), 0);
        assertEq(IERC20(collateral).balanceOf(feeCollector) - feeCollectorBalanceBefore, expectedFee);
        assertEq(IERC20(collateral).balanceOf(user), amount);
        assertEq(newAmount, expectedNewAmount);
    }

    function decodeBorrowAmount(IParam.Logic calldata logic) external pure returns (uint256) {
        bytes calldata data = logic.data;
        (, uint256 amount, , , ) = abi.decode(data[4:], (address, uint256, uint256, uint16, address));
        return amount;
    }

    function _setupCollateral(address aavePool, address collateral, uint256 borrowAmount) internal {
        vm.startPrank(user);
        uint256 collateralAmount = borrowAmount * 3;
        deal(collateral, user, collateralAmount);
        IERC20(collateral).safeApprove(aavePool, collateralAmount);
        if (aavePool == v2Pool) IAavePool(aavePool).deposit(collateral, collateralAmount, user, 0);
        else IAavePool(aavePool).supply(collateral, collateralAmount, user, 0);
        vm.stopPrank();
    }

    function _logicAaveBorrow(
        address to,
        address token,
        uint256 amount,
        uint256 interestRateMode
    ) internal view returns (IParam.Logic memory) {
        return
            IParam.Logic(
                to,
                abi.encodeWithSelector(
                    AAVE_BORROW_SELECTOR,
                    token,
                    amount,
                    interestRateMode,
                    0, // referralCode
                    user
                ),
                inputsEmpty,
                IParam.WrapMode.NONE,
                address(0), // approveTo
                address(0) // callback
            );
    }
}
