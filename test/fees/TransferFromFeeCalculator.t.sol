// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {IERC20} from 'openzeppelin-contracts/contracts/token/ERC20/IERC20.sol';
import {Router, IRouter} from 'src/Router.sol';
import {TransferFromFeeCalculator} from 'src/fees/TransferFromFeeCalculator.sol';
import {IParam} from 'src/interfaces/IParam.sol';
import {IAgent} from 'src/interfaces/IAgent.sol';
import {IFeeCalculator} from 'src/interfaces/IFeeCalculator.sol';
import {FeeCalculatorUtils, IFeeBase} from 'test/utils/FeeCalculatorUtils.sol';

contract TransferFromFeeCalculatorTest is Test, FeeCalculatorUtils {
    bytes4 public constant TRANSFER_FROM_SELECTOR = bytes4(keccak256(bytes('transferFrom(address,address,uint256)')));
    IERC20 public constant USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    uint256 public constant SIGNER_REFERRAL = 1;

    address public user;
    address public feeCollector;
    IRouter public router;
    IAgent public userAgent;
    IFeeCalculator public transferFromFeeCalculator;

    // Empty arrays
    address[] tokensReturnEmpty;
    IParam.Input[] inputsEmpty;

    function setUp() external {
        user = makeAddr('User');
        feeCollector = makeAddr('FeeCollector');
        address pauser = makeAddr('Pauser');

        // Depoly contracts
        router = new Router(makeAddr('WrappedNative'), pauser, feeCollector);
        vm.prank(user);
        userAgent = IAgent(router.newAgent());
        transferFromFeeCalculator = new TransferFromFeeCalculator(address(router), ZERO_FEE_RATE);

        // Setup fee calculator
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = TRANSFER_FROM_SELECTOR;
        address[] memory feeCalculators = new address[](1);
        feeCalculators[0] = address(transferFromFeeCalculator);
        router.setGeneralFeeCalculators(selectors, feeCalculators);

        vm.label(address(router), 'Router');
        vm.label(address(userAgent), 'UserAgent');
        vm.label(feeCollector, 'FeeCollector');
        vm.label(address(transferFromFeeCalculator), 'TransferFromFeeCalculator');
        vm.label(address(USDC), 'USDC');
    }

    function testChargeTransferFromFee(uint256 amount, uint256 feeRate) external {
        amount = bound(amount, 1e3, 1e18);
        feeRate = bound(feeRate, 0, BPS_BASE - 1);

        // Set fee rate
        IFeeBase(address(transferFromFeeCalculator)).setFeeRate(feeRate);

        // Encode logic
        IParam.Logic[] memory logics = new IParam.Logic[](1);
        logics[0] = _logicTransferFrom(address(USDC), user, address(userAgent), amount);

        // Get new logics
        IParam.Fee[] memory fees;
        (logics, fees, ) = router.getLogicsAndFees(logics, 0);

        // Prepare assert data
        uint256 expectedNewAmount = _calculateAmountWithFee(amount, feeRate);
        uint256 expectedFee = _calculateFee(expectedNewAmount, feeRate);
        uint256 newAmount = this.decodeTransferFromAmount(logics[0]);
        uint256 feeCollectorBalanceBefore = USDC.balanceOf(feeCollector);

        // Approve to agent
        vm.prank(user);
        USDC.approve(address(userAgent), newAmount);
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

    function decodeTransferFromAmount(IParam.Logic calldata logic) external pure returns (uint256) {
        bytes calldata data = logic.data;
        (, , uint256 amount) = abi.decode(data[4:], (address, address, uint256));
        return amount;
    }

    function _logicTransferFrom(
        address token,
        address from,
        address to,
        uint256 amount
    ) internal view returns (IParam.Logic memory) {
        return
            IParam.Logic(
                token,
                abi.encodeWithSelector(TRANSFER_FROM_SELECTOR, from, to, amount),
                inputsEmpty,
                IParam.WrapMode.NONE,
                address(0), // approveTo
                address(0) // callback
            );
    }
}
