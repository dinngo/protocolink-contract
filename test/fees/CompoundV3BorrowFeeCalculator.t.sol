// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {IERC20} from 'forge-std/interfaces/IERC20.sol';
import {Router} from 'src/Router.sol';
import {FeeCalculatorBase} from 'src/fees/FeeCalculatorBase.sol';
import {CompoundV3BorrowFeeCalculator} from 'src/fees/CompoundV3BorrowFeeCalculator.sol';
import {IParam} from 'src/interfaces/IParam.sol';
import {IAgent} from 'src/interfaces/IAgent.sol';

interface IComet {
    struct AssetInfo {
        uint8 offset;
        address asset;
        address priceFeed;
        uint64 scale;
        uint64 borrowCollateralFactor;
        uint64 liquidateCollateralFactor;
        uint64 liquidationFactor;
        uint128 supplyCap;
    }

    function getAssetInfoByAddress(address asset) external view returns (AssetInfo memory);

    function baseToken() external view returns (address);

    function baseBorrowMin() external view returns (uint);

    function supply(address asset, uint amount) external;

    function allow(address manager, bool isAllowed) external;
}

contract CompoundV3BorrowFeeCalculatorTest is Test {
    event FeeCharged(address indexed token, uint256 amount, bytes32 metadata);

    address public constant NATIVE = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant C_USDCV3 = 0xc3d688B66703497DAA19211EEdff47f25384cdc3;
    address public constant DUMMY_TO_ADDRESS = address(0);
    bytes32 public constant META_DATA = bytes32(bytes('compound-v3:borrow'));
    bytes4 public constant COMPOUND_BORROW_SELECTOR =
        bytes4(keccak256(bytes('withdrawFrom(address,address,address,uint256)')));
    uint256 public constant BPS_BASE = 10_000;
    uint256 public constant SIGNER_REFERRAL = 1;

    address public comet = C_USDCV3;
    address public collateral = WETH;
    uint256 public collateralAmount = 3000 ether;
    address public baseToken = IComet(comet).baseToken();

    address public user;
    address public feeCollector;
    Router public router;
    IAgent public userAgent;
    address public borrowFeeCalculator;

    // Empty arrays
    IParam.Input[] public inputsEmpty;

    function setUp() external {
        user = makeAddr('User');
        feeCollector = makeAddr('FeeCollector');
        address pauser = makeAddr('Pauser');

        // Depoly contracts
        router = new Router(makeAddr('WrappedNative'), address(this), pauser, feeCollector);
        vm.prank(user);
        userAgent = IAgent(router.newAgent());
        borrowFeeCalculator = address(new CompoundV3BorrowFeeCalculator(address(router), 0));

        // Setup collateral
        vm.startPrank(user);
        deal(collateral, user, collateralAmount);
        IERC20(collateral).approve(comet, collateralAmount);
        IComet(comet).supply(collateral, collateralAmount);
        IComet(comet).allow(address(userAgent), true);
        vm.stopPrank();

        // Setup fee calculator
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = COMPOUND_BORROW_SELECTOR;
        address[] memory tos = new address[](1);
        tos[0] = DUMMY_TO_ADDRESS;
        address[] memory feeCalculators = new address[](1);
        feeCalculators[0] = borrowFeeCalculator;
        router.setFeeCalculators(selectors, tos, feeCalculators);

        vm.label(address(router), 'Router');
        vm.label(address(userAgent), 'UserAgent');
        vm.label(feeCollector, 'FeeCollector');
        vm.label(address(borrowFeeCalculator), 'BorrowFeeCalculator');
        vm.label(C_USDCV3, 'cUSDCv3');
    }

    function testChargeBorrowFee(uint256 amount, uint256 feeRate) external {
        feeRate = bound(feeRate, 0, BPS_BASE - 1);

        // Calculate borrow limit, assume ETH price is 1000
        IComet.AssetInfo memory assetInfo = IComet(comet).getAssetInfoByAddress(collateral);
        uint256 collateralRatio = assetInfo.borrowCollateralFactor;
        uint256 baseTokenDecimal = IERC20(baseToken).decimals();
        uint256 borrowMax = (((((collateralAmount / 1 ether) * 1000) * collateralRatio) / 1 ether) *
            10 ** (baseTokenDecimal));
        uint256 borrowMin = IComet(comet).baseBorrowMin();
        amount = bound(amount, borrowMin, (borrowMax * (BPS_BASE - feeRate)) / BPS_BASE);

        // Set fee rate
        FeeCalculatorBase(borrowFeeCalculator).setFeeRate(feeRate);

        // Encode logic
        IParam.Logic[] memory logics = new IParam.Logic[](1);
        logics[0] = _logicCompoundV3Borrow(amount);

        // Get new logics
        (logics, ) = router.getUpdatedLogicsAndMsgValue(logics, 0);

        // Prepare assert data
        uint256 expectedNewAmount = FeeCalculatorBase(borrowFeeCalculator).calculateAmountWithFee(amount);
        uint256 expectedFee = FeeCalculatorBase(borrowFeeCalculator).calculateFee(expectedNewAmount);
        uint256 feeCollectorBalanceBefore = IERC20(baseToken).balanceOf(feeCollector);
        uint256 newAmount = this.decodeBorrowAmount(logics[0]);

        // Execute
        address[] memory tokensReturns = new address[](1);
        tokensReturns[0] = baseToken;
        vm.expectEmit(true, true, true, true, address(userAgent));
        emit FeeCharged(baseToken, expectedFee, META_DATA);
        vm.prank(user);
        router.execute(logics, tokensReturns, SIGNER_REFERRAL);

        assertEq(IERC20(baseToken).balanceOf(address(router)), 0);
        assertEq(IERC20(baseToken).balanceOf(address(userAgent)), 0);
        assertEq(IERC20(baseToken).balanceOf(feeCollector) - feeCollectorBalanceBefore, expectedFee);
        assertEq(IERC20(baseToken).balanceOf(user), amount);
        assertEq(newAmount, expectedNewAmount);
    }

    function decodeBorrowAmount(IParam.Logic calldata logic) external pure returns (uint256) {
        bytes calldata data = logic.data;
        (, , , uint256 amount) = abi.decode(data[4:], (address, address, address, uint256));
        return amount;
    }

    function _logicCompoundV3Borrow(uint256 amount) internal view returns (IParam.Logic memory) {
        return
            IParam.Logic(
                comet,
                abi.encodeWithSelector(COMPOUND_BORROW_SELECTOR, user, address(userAgent), baseToken, amount),
                inputsEmpty,
                IParam.WrapMode.NONE,
                address(0), // approveTo
                address(0) // callback
            );
    }
}
