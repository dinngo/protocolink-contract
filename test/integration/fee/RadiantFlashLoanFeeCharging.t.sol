// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {IERC20} from 'lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol';
import {SafeCast160} from 'lib/permit2/src/libraries/SafeCast160.sol';
import {Router} from 'src/Router.sol';
import {IAaveV2FlashLoanCallback} from 'src/callbacks/AaveV2FlashLoanCallback.sol';
import {RadiantV2FlashLoanCallback} from 'src/callbacks/RadiantV2FlashLoanCallback.sol';
import {DataType} from 'src/libraries/DataType.sol';
import {IAgent} from 'src/interfaces/IAgent.sol';
import {IAaveV2Provider} from 'src/interfaces/aaveV2/IAaveV2Provider.sol';
import {FeeLibrary} from 'src/libraries/FeeLibrary.sol';

contract RadiantFlashLoanFeeCalculatorTest is Test {
    using SafeCast160 for uint256;

    enum InterestRateMode {
        NONE,
        STABLE,
        VARIABLE
    }

    event Charged(address indexed token, uint256 amount, address indexed collector, bytes32 metadata);

    address public constant NATIVE = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address public constant RADIANT_V2_PROVIDER = 0x091d52CacE1edc5527C99cDCFA6937C1635330E4;
    address public constant USDC = 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8;
    address public constant RUSDC_V2 = 0x48a29E756CC1C097388f3B2f3b570ED270423b3d;
    address public constant PERMIT2_ADDRESS = 0x000000000022D473030F116dDEE9F6B43aC78BA3;
    bytes4 public constant RADIANT_FLASHLOAN_SELECTOR =
        bytes4(keccak256(bytes('flashLoan(address,address[],uint256[],uint256[],address,bytes,uint16)')));
    uint256 public constant BPS_NOT_USED = 0;
    uint256 public constant BPS_BASE = 10_000;
    uint256 public constant FEE_RATE = 5;
    bytes32 public constant V2_FLASHLOAN_META_DATA = bytes32(bytes('radiant-v2:flash-loan'));

    address public v2Pool;

    address public user;
    address public user2;
    address public defaultCollector;
    Router public router;
    IAgent public userAgent;
    IAaveV2FlashLoanCallback public flashLoanCallback;

    // Empty arrays
    address[] public tokensReturnEmpty;
    DataType.Input[] public inputsEmpty;
    bytes[] public datasEmpty;

    function setUp() external {
        vm.createSelectFork(vm.rpcUrl('arbitrum'));

        user = makeAddr('User');
        defaultCollector = makeAddr('FeeCollector');

        // Deploy contracts
        router = new Router(makeAddr('WrappedNative'), PERMIT2_ADDRESS, address(this));
        router.setFeeCollector(defaultCollector);
        vm.prank(user);
        userAgent = IAgent(router.newAgent());
        v2Pool = IAaveV2Provider(RADIANT_V2_PROVIDER).getLendingPool();
        flashLoanCallback = new RadiantV2FlashLoanCallback(address(router), RADIANT_V2_PROVIDER, FEE_RATE);

        vm.label(address(router), 'Router');
        vm.label(address(userAgent), 'UserAgent');
        vm.label(defaultCollector, 'FeeCollector');
        vm.label(v2Pool, 'RadiantV2Pool');
        vm.label(RADIANT_V2_PROVIDER, 'RadiantV2Provider');
        vm.label(PERMIT2_ADDRESS, 'Permit2');
        vm.label(address(flashLoanCallback), 'RadiantV2FlashLoanCallback');
        vm.label(USDC, 'USDC');
    }

    function testChargeFlashLoanV2Fee(uint256 amount) external {
        amount = bound(amount, 100_000, (IERC20(USDC).balanceOf(RUSDC_V2) * (BPS_BASE - FEE_RATE)) / BPS_BASE);

        // Encode flash loan params
        DataType.Logic[] memory flashLoanLogics = new DataType.Logic[](1);
        flashLoanLogics[0] = _logicTransferFlashLoanAmountAndFee(address(flashLoanCallback), USDC, amount);
        bytes memory params = abi.encode(flashLoanLogics);

        // Encode logic
        address[] memory tokens = new address[](1);
        tokens[0] = USDC;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;

        DataType.Logic[] memory logics = new DataType.Logic[](1);
        logics[0] = _logicRadiantFlashLoan(v2Pool, address(flashLoanCallback), tokens, amounts, params);

        _distributeToken(tokens, amounts);

        // Prepare assert data
        uint256 expectedFee = FeeLibrary.calcFeeFromAmount(amount, FEE_RATE);
        uint256 feeCollectorBalanceBefore = IERC20(USDC).balanceOf(defaultCollector);

        // Execute
        if (expectedFee > 0) {
            vm.expectEmit(true, true, true, true, address(flashLoanCallback));
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
        amount = bound(amount, 0, (IERC20(USDC).balanceOf(RUSDC_V2) * (BPS_BASE - FEE_RATE)) / BPS_BASE);
        nativeAmount = bound(nativeAmount, 0, 5000 ether);

        // Encode flash loan params
        bytes memory params;
        {
            DataType.Logic[] memory flashLoanLogics = new DataType.Logic[](2);
            flashLoanLogics[0] = _logicTransferFlashLoanAmountAndFee(address(flashLoanCallback), USDC, amount);
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

            logics[0] = _logicRadiantFlashLoan(v2Pool, address(flashLoanCallback), tokens, amounts, params);

            // Get new logics and msg.value amount
            deal(user, nativeAmount);
            _distributeToken(tokens, amounts);
        }

        // Prepare assert data
        uint256 expectedFee = FeeLibrary.calcFeeFromAmount(amount, FEE_RATE);
        uint256 feeCollectorBalanceBefore = IERC20(USDC).balanceOf(defaultCollector);
        uint256 feeCollectorNativeBalanceBefore = defaultCollector.balance;
        uint256 user2NativeBalanceBefore = user2.balance;

        {
            // Execute
            if (expectedFee > 0) {
                vm.expectEmit(true, true, true, true, address(flashLoanCallback));
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

    function _logicRadiantFlashLoan(
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
                    RADIANT_FLASHLOAN_SELECTOR,
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
        uint256 amount
    ) internal view returns (DataType.Logic memory) {
        uint256 radiantFee = _getRadiantFlashLoanFee(amount);
        uint256 amountWithFee = FeeLibrary.calcAmountWithFee(amount, FEE_RATE);
        return
            DataType.Logic(
                token,
                abi.encodeWithSelector(IERC20.transfer.selector, to, amountWithFee + radiantFee),
                inputsEmpty,
                DataType.WrapMode.NONE,
                address(0), // approveTo
                address(0) // callback
            );
    }

    function _distributeToken(address[] memory tokens, uint256[] memory amounts) internal {
        for (uint256 i = 0; i < tokens.length; ++i) {
            // Airdrop radiant flash loan fee and router flash loan fee to agent
            uint256 radiantFee = _getRadiantFlashLoanFee(amounts[i]);
            uint256 routerFee = FeeLibrary.calcFeeFromAmount(amounts[i], FEE_RATE);

            deal(tokens[i], address(userAgent), radiantFee + routerFee);
        }
    }

    function _getRadiantFlashLoanFee(uint256 amount) internal pure returns (uint256) {
        uint256 fee;
        fee = (amount * 9) / BPS_BASE;
        return fee;
    }
}
