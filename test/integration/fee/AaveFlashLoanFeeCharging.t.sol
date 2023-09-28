// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {IERC20} from 'lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol';
import {SafeCast160} from 'lib/permit2/src/libraries/SafeCast160.sol';
import {Router} from 'src/Router.sol';
import {AaveV2FlashLoanCallback, IAaveV2FlashLoanCallback} from 'src/callbacks/AaveV2FlashLoanCallback.sol';
import {AaveV3FlashLoanCallback, IAaveV3FlashLoanCallback} from 'src/callbacks/AaveV3FlashLoanCallback.sol';
import {DataType} from 'src/libraries/DataType.sol';
import {IAgent} from 'src/interfaces/IAgent.sol';
import {IAaveV2Provider} from 'src/interfaces/aaveV2/IAaveV2Provider.sol';
import {IAaveV3Provider} from 'src/interfaces/aaveV3/IAaveV3Provider.sol';
import {FeeLibrary} from 'src/libraries/FeeLibrary.sol';

interface IAaveV3Pool {
    function FLASHLOAN_PREMIUM_TOTAL() external view returns (uint128);
}

contract AaveFlashLoanFeeCalculatorTest is Test {
    using SafeCast160 for uint256;

    enum InterestRateMode {
        NONE,
        STABLE,
        VARIABLE
    }

    event Charged(address indexed token, uint256 amount, address indexed collector, bytes32 metadata);

    address public constant NATIVE = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address public constant AAVE_V2_PROVIDER = 0xB53C1a33016B2DC2fF3653530bfF1848a515c8c5;
    address public constant AAVE_V3_PROVIDER = 0x2f39d218133AFaB8F2B819B1066c7E434Ad94E9e;
    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public constant AUSDC_V2 = 0xBcca60bB61934080951369a648Fb03DF4F96263C;
    address public constant AUSDC_V3 = 0x98C23E9d8f34FEFb1B7BD6a91B7FF122F4e16F5c;
    address public constant PERMIT2_ADDRESS = 0x000000000022D473030F116dDEE9F6B43aC78BA3;
    bytes4 public constant AAVE_FLASHLOAN_SELECTOR =
        bytes4(keccak256(bytes('flashLoan(address,address[],uint256[],uint256[],address,bytes,uint16)')));
    uint256 public constant BPS_NOT_USED = 0;
    uint256 public constant BPS_BASE = 10_000;
    uint256 public constant FEE_RATE = 5;
    bytes32 public constant V2_FLASHLOAN_META_DATA = bytes32(bytes('aave-v2:flash-loan'));
    bytes32 public constant V3_FLASHLOAN_META_DATA = bytes32(bytes('aave-v3:flash-loan'));

    address public v2Pool;
    address public v3Pool;

    address public user;
    address public user2;
    address public defaultCollector;
    Router public router;
    IAgent public userAgent;
    IAaveV2FlashLoanCallback public flashLoanCallbackV2;
    IAaveV3FlashLoanCallback public flashLoanCallbackV3;

    // Empty arrays
    address[] public tokensReturnEmpty;
    DataType.Input[] public inputsEmpty;
    bytes[] public datasEmpty;

    function setUp() external {
        vm.createSelectFork(vm.rpcUrl('ethereum'));

        user = makeAddr('User');
        defaultCollector = makeAddr('FeeCollector');

        // Deploy contracts
        router = new Router(makeAddr('WrappedNative'), PERMIT2_ADDRESS, address(this));
        router.setFeeCollector(defaultCollector);
        vm.prank(user);
        userAgent = IAgent(router.newAgent());
        v2Pool = IAaveV2Provider(AAVE_V2_PROVIDER).getLendingPool();
        v3Pool = IAaveV3Provider(AAVE_V3_PROVIDER).getPool();
        flashLoanCallbackV2 = new AaveV2FlashLoanCallback(address(router), AAVE_V2_PROVIDER, FEE_RATE);
        flashLoanCallbackV3 = new AaveV3FlashLoanCallback(address(router), AAVE_V3_PROVIDER, FEE_RATE);

        vm.label(address(router), 'Router');
        vm.label(address(userAgent), 'UserAgent');
        vm.label(defaultCollector, 'FeeCollector');
        vm.label(v2Pool, 'AaveV2Pool');
        vm.label(v3Pool, 'AaveV3Pool');
        vm.label(AAVE_V2_PROVIDER, 'AaveV2Provider');
        vm.label(AAVE_V3_PROVIDER, 'AaveV3Provider');
        vm.label(PERMIT2_ADDRESS, 'Permit2');
        vm.label(address(flashLoanCallbackV2), 'AaveV2FlashLoanCallback');
        vm.label(address(flashLoanCallbackV3), 'AaveV3FlashLoanCallback');
        vm.label(USDC, 'USDC');
    }

    function testChargeFlashLoanV2Fee(uint256 amount) external {
        bool isAaveV2 = true;
        amount = bound(amount, 100_000, (IERC20(USDC).balanceOf(AUSDC_V2) * (BPS_BASE - FEE_RATE)) / BPS_BASE);

        // Encode flash loan params
        DataType.Logic[] memory flashLoanLogics = new DataType.Logic[](1);
        flashLoanLogics[0] = _logicTransferFlashLoanAmountAndFee(address(flashLoanCallbackV2), USDC, amount, isAaveV2);
        bytes memory params = abi.encode(flashLoanLogics);

        // Encode logic
        address[] memory tokens = new address[](1);
        tokens[0] = USDC;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;

        DataType.Logic[] memory logics = new DataType.Logic[](1);
        logics[0] = _logicAaveFlashLoan(v2Pool, address(flashLoanCallbackV2), tokens, amounts, params);

        _distributeToken(tokens, amounts, isAaveV2);

        // Prepare assert data
        uint256 expectedFee = FeeLibrary.calcFeeFromAmount(amount, FEE_RATE);
        uint256 feeCollectorBalanceBefore = IERC20(USDC).balanceOf(defaultCollector);

        // Execute
        if (expectedFee > 0) {
            vm.expectEmit(true, true, true, true, address(flashLoanCallbackV2));
            emit Charged(USDC, expectedFee, defaultCollector, V2_FLASHLOAN_META_DATA);
        }
        vm.prank(user);
        router.execute(datasEmpty, logics, tokensReturnEmpty);

        assertEq(IERC20(USDC).balanceOf(address(router)), 0);
        assertEq(IERC20(USDC).balanceOf(address(userAgent)), 0);
        assertEq(IERC20(USDC).balanceOf(defaultCollector) - feeCollectorBalanceBefore, expectedFee);
    }

    /// This test will do flash loan + send native token(inside flash loan)
    function testChargeFlashLoanV2FeeWithFeeScenarioInside(uint256 amount, uint256 nativeAmount) external {
        bool isAaveV2 = true;
        amount = bound(amount, 0, (IERC20(USDC).balanceOf(AUSDC_V2) * (BPS_BASE - FEE_RATE)) / BPS_BASE);
        nativeAmount = bound(nativeAmount, 0, 5000 ether);

        // Encode flash loan params
        bytes memory params;
        {
            DataType.Logic[] memory flashLoanLogics = new DataType.Logic[](2);
            flashLoanLogics[0] = _logicTransferFlashLoanAmountAndFee(
                address(flashLoanCallbackV2),
                USDC,
                amount,
                isAaveV2
            );
            flashLoanLogics[1] = _logicSendNativeToken(user2, nativeAmount);
            params = abi.encode(flashLoanLogics);
        }

        DataType.Logic[] memory logics = new DataType.Logic[](1);
        {
            // Encode logic
            address[] memory tokens = new address[](1);
            tokens[0] = USDC;

            uint256[] memory amounts = new uint256[](1);
            amounts[0] = amount;

            logics[0] = _logicAaveFlashLoan(v2Pool, address(flashLoanCallbackV2), tokens, amounts, params);

            // Get new logics and msg.value amount
            deal(user, nativeAmount);
            _distributeToken(tokens, amounts, isAaveV2);
        }

        // Prepare assert data
        uint256 expectedFee = FeeLibrary.calcFeeFromAmount(amount, FEE_RATE);
        uint256 feeCollectorBalanceBefore = IERC20(USDC).balanceOf(defaultCollector);
        uint256 feeCollectorNativeBalanceBefore = defaultCollector.balance;
        uint256 user2NativeBalanceBefore = user2.balance;

        {
            // Execute
            if (expectedFee > 0) {
                vm.expectEmit(true, true, true, true, address(flashLoanCallbackV2));
                emit Charged(USDC, expectedFee, defaultCollector, V2_FLASHLOAN_META_DATA);
            }
            vm.prank(user);
            router.execute{value: nativeAmount}(datasEmpty, logics, tokensReturnEmpty);
        }

        assertEq(IERC20(USDC).balanceOf(address(router)), 0);
        assertEq(IERC20(USDC).balanceOf(address(userAgent)), 0);
        assertEq(IERC20(USDC).balanceOf(defaultCollector) - feeCollectorBalanceBefore, expectedFee);
        assertEq(defaultCollector.balance, feeCollectorNativeBalanceBefore);
        assertEq(user2.balance - user2NativeBalanceBefore, nativeAmount);
    }

    function testChargeFlashLoanV3Fee(uint256 amount) external {
        bool isAaveV2 = false;
        amount = bound(amount, 0, (IERC20(USDC).balanceOf(AUSDC_V3) * (BPS_BASE - FEE_RATE)) / BPS_BASE);

        // Encode flash loan params
        DataType.Logic[] memory flashLoanLogics = new DataType.Logic[](1);
        flashLoanLogics[0] = _logicTransferFlashLoanAmountAndFee(address(flashLoanCallbackV3), USDC, amount, isAaveV2);
        bytes memory params = abi.encode(flashLoanLogics);

        // Encode logic
        address[] memory tokens = new address[](1);
        tokens[0] = USDC;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;

        DataType.Logic[] memory logics = new DataType.Logic[](1);
        logics[0] = _logicAaveFlashLoan(v3Pool, address(flashLoanCallbackV3), tokens, amounts, params);

        _distributeToken(tokens, amounts, isAaveV2);

        // Prepare assert data
        uint256 expectedFee = FeeLibrary.calcFeeFromAmount(amount, FEE_RATE);
        uint256 feeCollectorBalanceBefore = IERC20(USDC).balanceOf(defaultCollector);

        // Execute
        if (expectedFee > 0) {
            vm.expectEmit(true, true, true, true, address(flashLoanCallbackV3));
            emit Charged(USDC, expectedFee, defaultCollector, V3_FLASHLOAN_META_DATA);
        }
        vm.prank(user);
        router.execute(datasEmpty, logics, tokensReturnEmpty);

        assertEq(IERC20(USDC).balanceOf(address(router)), 0);
        assertEq(IERC20(USDC).balanceOf(address(userAgent)), 0);
        assertEq(IERC20(USDC).balanceOf(defaultCollector) - feeCollectorBalanceBefore, expectedFee);
    }

    function _logicAaveFlashLoan(
        address to,
        address callback,
        address[] memory tokens,
        uint256[] memory amounts,
        bytes memory params
    ) internal view returns (DataType.Logic memory) {
        uint256[] memory modes = new uint256[](1);
        modes[0] = uint256(InterestRateMode.NONE);

        return
            DataType.Logic(
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
                DataType.WrapMode.NONE,
                address(0), // approveTo
                callback
            );
    }

    function _logicSendNativeToken(address to, uint256 amount) internal pure returns (DataType.Logic memory) {
        // Encode inputs
        DataType.Input[] memory inputs = new DataType.Input[](1);
        inputs[0].token = NATIVE;
        inputs[0].balanceBps = BPS_NOT_USED;
        inputs[0].amountOrOffset = amount;

        return
            DataType.Logic(
                to,
                new bytes(0),
                inputs,
                DataType.WrapMode.NONE,
                address(0), // approveTo
                address(0) // callback
            );
    }

    function _logicTransferFlashLoanAmountAndFee(
        address to,
        address token,
        uint256 amount,
        bool isAaveV2
    ) internal view returns (DataType.Logic memory) {
        uint256 aaveFee = _getAaveFlashLoanFee(amount, isAaveV2);
        uint256 amountWithFee = FeeLibrary.calcAmountWithFee(amount, FEE_RATE);
        return
            DataType.Logic(
                token,
                abi.encodeWithSelector(IERC20.transfer.selector, to, amountWithFee + aaveFee),
                inputsEmpty,
                DataType.WrapMode.NONE,
                address(0), // approveTo
                address(0) // callback
            );
    }

    function _distributeToken(address[] memory tokens, uint256[] memory amounts, bool isAaveV2) internal {
        for (uint256 i = 0; i < tokens.length; ++i) {
            // Airdrop aave flash loan fee and router flash loan fee to agent
            uint256 aaveFee = _getAaveFlashLoanFee(amounts[i], isAaveV2);
            uint256 routerFee = FeeLibrary.calcFeeFromAmount(amounts[i], FEE_RATE);

            deal(tokens[i], address(userAgent), aaveFee + routerFee);
        }
    }

    function _getAaveFlashLoanFee(uint256 amount, bool isAaveV2) internal view returns (uint256) {
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
