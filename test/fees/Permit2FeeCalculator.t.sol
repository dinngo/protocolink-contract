// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {IERC20} from 'openzeppelin-contracts/contracts/token/ERC20/IERC20.sol';
import {SafeCast160} from 'permit2/libraries/SafeCast160.sol';
import {Router} from 'src/Router.sol';
import {FeeCalculatorBase} from 'src/fees/FeeCalculatorBase.sol';
import {Permit2FeeCalculator} from 'src/fees/Permit2FeeCalculator.sol';
import {IParam} from 'src/interfaces/IParam.sol';
import {IAgent} from 'src/interfaces/IAgent.sol';
import {ERC20Permit2Utils} from 'test/utils/ERC20Permit2Utils.sol';

contract Permit2FeeCalculatorTest is Test, ERC20Permit2Utils {
    using SafeCast160 for uint256;

    event FeeCharged(address indexed token, uint256 amount, bytes32 metadata);

    bytes4 public constant PERMIT2_TRANSFER_FROM_SELECTOR =
        bytes4(keccak256(bytes('transferFrom(address,address,uint160,address)')));
    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public constant PERMIT2_ADDR = 0x000000000022D473030F116dDEE9F6B43aC78BA3;
    uint256 public constant BPS_BASE = 10_000;
    bytes32 public constant META_DATA = bytes32(bytes('permit2:pull-token'));

    address public user;
    uint256 public userPrivateKey;
    address public feeCollector;
    Router public router;
    IAgent public userAgent;
    address public permit2FeeCalculator;

    // Empty arrays
    address[] public tokensReturnEmpty;
    IParam.Input[] public inputsEmpty;

    function setUp() external {
        (user, userPrivateKey) = makeAddrAndKey('User');
        feeCollector = makeAddr('FeeCollector');
        address pauser = makeAddr('Pauser');

        // Depoly contracts
        router = new Router(makeAddr('WrappedNative'), address(this), pauser, feeCollector);
        vm.prank(user);
        userAgent = IAgent(router.newAgent());
        permit2FeeCalculator = address(new Permit2FeeCalculator(address(router), 0));

        // Setup permit2
        erc20Permit2UtilsSetUp(user, userPrivateKey, address(userAgent));
        permitToken(IERC20(USDC));

        // Setup fee calculator
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = PERMIT2_TRANSFER_FROM_SELECTOR;
        address[] memory tos = new address[](1);
        tos[0] = PERMIT2_ADDR;
        address[] memory feeCalculators = new address[](1);
        feeCalculators[0] = permit2FeeCalculator;
        router.setFeeCalculators(selectors, tos, feeCalculators);

        vm.label(address(router), 'Router');
        vm.label(address(userAgent), 'UserAgent');
        vm.label(feeCollector, 'FeeCollector');
        vm.label(permit2FeeCalculator, 'Permit2FeeCalculator');
        vm.label(PERMIT2_ADDR, 'Permit2Address');
    }

    function testChargePermit2TransferFromFee(uint256 amount, uint256 feeRate) external {
        feeRate = bound(feeRate, 0, BPS_BASE - 1);
        amount = bound(amount, 0, (IERC20(USDC).totalSupply() * (BPS_BASE - feeRate)) / BPS_BASE);

        // Set fee rate
        FeeCalculatorBase(permit2FeeCalculator).setFeeRate(feeRate);

        // Encode logic
        IParam.Logic[] memory logics = new IParam.Logic[](1);
        logics[0] = logicERC20Permit2PullToken(IERC20(USDC), amount.toUint160());

        // Get new logics
        (logics, ) = router.getLogicsAndMsgValueWithFee(logics, 0);

        // Prepare assert data
        uint256 expectedNewAmount = FeeCalculatorBase(permit2FeeCalculator).calculateAmountWithFee(amount);
        uint256 expectedFee = FeeCalculatorBase(permit2FeeCalculator).calculateFee(expectedNewAmount);
        uint256 newAmount = this.decodePermit2TransferFromAmount(logics[0]);
        uint256 feeCollectorBalanceBefore = IERC20(USDC).balanceOf(feeCollector);

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

    function decodePermit2TransferFromAmount(IParam.Logic calldata logic) external pure returns (uint256) {
        bytes calldata data = logic.data;
        (, , uint160 amount, ) = abi.decode(data[4:], (address, address, uint160, address));
        return amount;
    }
}
