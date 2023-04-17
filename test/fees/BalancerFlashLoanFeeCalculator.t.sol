// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {IERC20} from 'openzeppelin-contracts/contracts/token/ERC20/IERC20.sol';
import {Router, IRouter} from 'src/Router.sol';
import {IParam} from 'src/interfaces/IParam.sol';
import {IAgent} from 'src/interfaces/IAgent.sol';
import {FeeCalculatorBase} from 'src/fees/FeeCalculatorBase.sol';
import {BalancerFlashLoanFeeCalculator} from 'src/fees/BalancerFlashLoanFeeCalculator.sol';
import {BalancerV2FlashLoanCallback, IBalancerV2FlashLoanCallback} from 'src/callbacks/BalancerV2FlashLoanCallback.sol';

contract BalancerFlashLoanFeeCalculatorTest is Test {
    event FeeCharged(address indexed token, uint256 amount, bytes32 metadata);

    address public constant BALANCER_V2_VAULT = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;
    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    bytes4 public constant BALANCER_FLASHLOAN_SELECTOR =
        bytes4(keccak256(bytes('flashLoan(address,address[],uint256[],bytes)')));
    uint256 public constant SIGNER_REFERRAL = 1;
    uint256 public constant SKIP = 0x8000000000000000000000000000000000000000000000000000000000000000;
    uint256 public constant BPS_BASE = 10_000;

    address public user;
    IAgent public userAgent;
    address public feeCollector;
    address public flashLoanFeeCalculator;
    Router public router;
    IBalancerV2FlashLoanCallback public flashLoanCallback;

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
        flashLoanCallback = new BalancerV2FlashLoanCallback(address(router), BALANCER_V2_VAULT);
        flashLoanFeeCalculator = address(new BalancerFlashLoanFeeCalculator(address(router), 0));

        // Setup fee calculator
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = BALANCER_FLASHLOAN_SELECTOR;
        address[] memory tos = new address[](1);
        tos[0] = BALANCER_V2_VAULT;
        address[] memory feeCalculators = new address[](1);
        feeCalculators[0] = address(flashLoanFeeCalculator);
        router.setFeeCalculators(selectors, tos, feeCalculators);

        vm.label(address(router), 'Router');
        vm.label(address(userAgent), 'UserAgent');
        vm.label(feeCollector, 'FeeCollector');
        vm.label(address(flashLoanFeeCalculator), 'BalancerFlashLoanFeeCalculator');
        vm.label(address(flashLoanCallback), 'BalancerV2FlashLoanCallback');
        vm.label(BALANCER_V2_VAULT, 'BalancerV2Vault');
        vm.label(USDC, 'USDC');
    }

    function testChargeFlashLoanFee() external {
        uint256 amount = (10000 * 10) ^ 6;
        uint256 feeRate = 20;

        // Set fee rate
        FeeCalculatorBase(flashLoanFeeCalculator).setFeeRate(feeRate);

        // Encode flashloan userData
        IParam.Logic[] memory flashLoanLogics = new IParam.Logic[](1);
        flashLoanLogics[0] = _logicTransferFlashLoanAmount(
            address(flashLoanCallback),
            USDC,
            FeeCalculatorBase(flashLoanFeeCalculator).calculateAmountWithFee(amount)
        );
        bytes memory userData = abi.encode(flashLoanLogics, feesEmpty, tokensReturnEmpty);

        address[] memory tokens = new address[](1);
        tokens[0] = USDC;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;

        // Encode logics
        IParam.Logic[] memory logics = new IParam.Logic[](1);
        logics[0] = _logicBalancerV2FlashLoan(tokens, amounts, userData);

        // Get new logics and fees
        IParam.Fee[] memory fees;
        (logics, , fees) = router.getLogicsAndFees(logics, 0);

        _distributeToken(tokens, amounts);

        // Execute
        vm.prank(user);
        router.execute(logics, fees, tokensReturnEmpty, SIGNER_REFERRAL);
    }

    function _logicBalancerV2FlashLoan(
        address[] memory tokens,
        uint256[] memory amounts,
        bytes memory userData
    ) public view returns (IParam.Logic memory) {
        return
            IParam.Logic(
                BALANCER_V2_VAULT, // to
                abi.encodeWithSelector(
                    BALANCER_FLASHLOAN_SELECTOR,
                    address(flashLoanCallback),
                    tokens,
                    amounts,
                    userData
                ),
                inputsEmpty,
                IParam.WrapMode.NONE,
                address(0), // approveTo
                address(flashLoanCallback) // callback
            );
    }

    function _logicTransferFlashLoanAmount(
        address to,
        address token,
        uint256 amount
    ) internal view returns (IParam.Logic memory) {
        // uint256 fee = (amount * 9) / BPS_BASE;
        return
            IParam.Logic(
                token,
                abi.encodeWithSelector(IERC20.transfer.selector, to, amount),
                inputsEmpty,
                IParam.WrapMode.NONE,
                address(0), // approveTo
                address(0) // callback
            );
    }

    function _distributeToken(address[] memory tokens, uint256[] memory amounts) internal {
        for (uint256 i = 0; i < tokens.length; ++i) {
            uint256 amountWithRouterFee = FeeCalculatorBase(flashLoanFeeCalculator).calculateAmountWithFee(amounts[i]);

            // Airdrop router flashloan fee to agent
            uint256 routerFee = FeeCalculatorBase(flashLoanFeeCalculator).calculateFee(amountWithRouterFee);

            deal(tokens[i], address(userAgent), routerFee);
        }
    }
}
