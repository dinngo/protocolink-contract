// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {IERC20} from 'openzeppelin-contracts/contracts/token/ERC20/IERC20.sol';
import {Router} from 'src/Router.sol';
import {FeeCalculatorBase} from 'src/fees/FeeCalculatorBase.sol';
import {TransferFromFeeCalculator} from 'src/fees/TransferFromFeeCalculator.sol';
import {IParam} from 'src/interfaces/IParam.sol';
import {IAgent} from 'src/interfaces/IAgent.sol';

contract TransferFromFeeCalculatorTest is Test {
    event FeeCharged(address indexed token, uint256 amount, bytes32 metadata);

    bytes4 public constant TRANSFER_FROM_SELECTOR = bytes4(keccak256(bytes('transferFrom(address,address,uint256)')));
    address public constant ANY_TO_ADDRESS = address(0);
    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    uint256 public constant SIGNER_REFERRAL = 1;
    uint256 public constant BPS_BASE = 10_000;
    bytes32 public constant META_DATA = bytes32(bytes('erc20:transfer-from'));

    address public user;
    address public feeCollector;
    Router public router;
    IAgent public userAgent;
    address public transferFromFeeCalculator;

    // Empty arrays
    address[] tokensReturnEmpty;
    IParam.Input[] inputsEmpty;

    function setUp() external {
        user = makeAddr('User');
        feeCollector = makeAddr('FeeCollector');
        address pauser = makeAddr('Pauser');

        // Depoly contracts
        router = new Router(makeAddr('WrappedNative'), address(this), pauser, feeCollector);
        vm.prank(user);
        userAgent = IAgent(router.newAgent());
        transferFromFeeCalculator = address(new TransferFromFeeCalculator(address(router), 0));

        // Setup fee calculator
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = TRANSFER_FROM_SELECTOR;
        address[] memory tos = new address[](1);
        tos[0] = address(ANY_TO_ADDRESS);
        address[] memory feeCalculators = new address[](1);
        feeCalculators[0] = transferFromFeeCalculator;
        router.setFeeCalculators(selectors, tos, feeCalculators);

        vm.label(address(router), 'Router');
        vm.label(address(userAgent), 'UserAgent');
        vm.label(feeCollector, 'FeeCollector');
        vm.label(transferFromFeeCalculator, 'TransferFromFeeCalculator');
        vm.label(USDC, 'USDC');
    }

    function testChargeTransferFromFee(uint256 amount, uint256 feeRate) external {
        feeRate = bound(feeRate, 0, BPS_BASE - 1);
        amount = bound(amount, 0, (IERC20(USDC).totalSupply() * (BPS_BASE - feeRate)) / BPS_BASE);

        // Set fee rate
        FeeCalculatorBase(transferFromFeeCalculator).setFeeRate(feeRate);

        // Encode logic
        IParam.Logic[] memory logics = new IParam.Logic[](1);
        logics[0] = _logicTransferFrom(USDC, user, address(userAgent), amount);

        // Get new logics
        (logics, ) = router.getUpdatedLogicsAndMsgValue(logics, 0);

        // Prepare assert data
        uint256 expectedNewAmount = FeeCalculatorBase(transferFromFeeCalculator).calculateAmountWithFee(amount);
        uint256 expectedFee = FeeCalculatorBase(transferFromFeeCalculator).calculateFee(expectedNewAmount);
        uint256 newAmount = this.decodeTransferFromAmount(logics[0]);
        uint256 feeCollectorBalanceBefore = IERC20(USDC).balanceOf(feeCollector);

        // Approve to agent
        vm.prank(user);
        IERC20(USDC).approve(address(userAgent), newAmount);
        deal(USDC, user, newAmount);

        // Execute
        address[] memory tokensReturns = new address[](1);
        tokensReturns[0] = USDC;
        if (expectedFee > 0) {
            vm.expectEmit(true, true, true, true, address(userAgent));
            emit FeeCharged(USDC, expectedFee, META_DATA);
        }
        vm.prank(user);
        router.execute(logics, tokensReturns, SIGNER_REFERRAL);

        assertEq(IERC20(USDC).balanceOf(address(router)), 0);
        assertEq(IERC20(USDC).balanceOf(address(userAgent)), 0);
        assertEq(IERC20(USDC).balanceOf(feeCollector) - feeCollectorBalanceBefore, expectedFee);
        assertEq(IERC20(USDC).balanceOf(user), amount);
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
