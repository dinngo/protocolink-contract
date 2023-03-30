// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {IERC20} from 'openzeppelin-contracts/contracts/token/ERC20/IERC20.sol';
import {SafeCast160} from 'permit2/libraries/SafeCast160.sol';
import {Router, IRouter} from 'src/Router.sol';
import {Permit2FeeCalculator} from 'src/fees/Permit2FeeCalculator.sol';
import {IParam} from 'src/interfaces/IParam.sol';
import {IAgent} from 'src/interfaces/IAgent.sol';
import {IFeeCalculator} from 'src/interfaces/IFeeCalculator.sol';
import {FeeCalculatorUtils, IFeeBase} from 'test/utils/FeeCalculatorUtils.sol';
import {SpenderPermitUtils} from 'test/utils/SpenderPermitUtils.sol';

contract Permit2FeeCalculatorTest is Test, FeeCalculatorUtils, SpenderPermitUtils {
    using SafeCast160 for uint256;

    bytes4 public constant PERMIT2_TRANSFER_FROM_SELECTOR =
        bytes4(keccak256(bytes('transferFrom(address,address,uint160,address)')));
    IERC20 public constant USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    address public constant PERMIT2_ADDR = 0x000000000022D473030F116dDEE9F6B43aC78BA3;

    address public user;
    uint256 public userPrivateKey;
    address public feeCollector;
    IRouter public router;
    IAgent public userAgent;
    IFeeCalculator public permit2FeeCalculator;

    // Empty arrays
    address[] public tokensReturnEmpty;
    IParam.Input[] public inputsEmpty;

    function setUp() external {
        (user, userPrivateKey) = makeAddrAndKey('User');
        feeCollector = makeAddr('FeeCollector');
        address pauser = makeAddr('Pauser');

        // Depoly contracts
        router = new Router(makeAddr('WrappedNative'), pauser, feeCollector);
        vm.prank(user);
        userAgent = IAgent(router.newAgent());
        permit2FeeCalculator = new Permit2FeeCalculator(address(router), ZERO_FEE_RATE);

        // Setup permit2
        spenderSetUp(user, userPrivateKey, router, userAgent);
        permitToken(USDC);

        // Setup fee calculator
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = PERMIT2_TRANSFER_FROM_SELECTOR;
        address[] memory feeCalculators = new address[](1);
        feeCalculators[0] = address(permit2FeeCalculator);
        router.setFeeCalculators(selectors, feeCalculators);

        vm.label(address(router), 'Router');
        vm.label(address(userAgent), 'UserAgent');
        vm.label(feeCollector, 'FeeCollector');
        vm.label(address(permit2FeeCalculator), 'Permit2FeeCalculator');
        vm.label(PERMIT2_ADDR, 'Permit2Address');
    }

    function testChargePermit2TransferFromFee(uint256 amount, uint256 feeRate) external {
        amount = bound(amount, 1e3, 1e18);
        feeRate = bound(feeRate, 0, BPS_BASE - 1);

        // Set fee rate
        IFeeBase(address(permit2FeeCalculator)).setFeeRate(feeRate);

        // Encode logic
        IParam.Logic[] memory logics = new IParam.Logic[](1);
        logics[0] = logicSpenderPermit2ERC20PullToken(USDC, amount.toUint160());

        // Get new logics
        IParam.Fee[] memory fees;
        (logics, fees, ) = router.getLogicsAndFees(logics, 0);

        // Prepare assert data
        uint256 expectedNewAmount = _calculateAmountWithFee(amount, feeRate);
        uint256 expectedFee = _calculateFee(expectedNewAmount, feeRate);
        uint256 newAmount = this.decodePermit2TransferFromAmount(logics[0]);
        uint256 feeCollectorBalanceBefore = USDC.balanceOf(feeCollector);

        deal(address(USDC), user, newAmount);

        // Execute
        address[] memory tokensReturns = new address[](1);
        tokensReturns[0] = address(USDC);
        vm.prank(user);
        router.execute(logics, fees, tokensReturns, SIGNER_REFERRAL);

        assertEq(USDC.balanceOf(address(router)), 0);
        assertEq(USDC.balanceOf(address(userAgent)), 0);
        assertEq(USDC.balanceOf(feeCollector) - feeCollectorBalanceBefore, expectedFee);
        assertEq(USDC.balanceOf(user), amount);
        assertEq(newAmount, expectedNewAmount);
    }

    function decodePermit2TransferFromAmount(IParam.Logic calldata logic) external pure returns (uint256) {
        bytes calldata data = logic.data;
        (, , uint160 amount, ) = abi.decode(data[4:], (address, address, uint160, address));
        return amount;
    }
}
