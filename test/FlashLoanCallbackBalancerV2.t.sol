// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {SafeERC20, IERC20} from 'openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol';
import {Router, IRouter} from '../src/Router.sol';
import {FlashLoanCallbackBalancerV2, IFlashLoanCallbackBalancerV2} from '../src/FlashLoanCallbackBalancerV2.sol';
import {IBalancerV2Vault} from '../src/interfaces/balancerV2/IBalancerV2Vault.sol';
import {MockERC20} from './mocks/MockERC20.sol';

contract FlashLoanCallbackBalancerV2Test is Test {
    IBalancerV2Vault public constant balancerV2Vault = IBalancerV2Vault(0xBA12222222228d8Ba445958a75a0704d566BF2C8);

    address public user;
    IRouter public router;
    IFlashLoanCallbackBalancerV2 public flashLoanCallback;
    IERC20 public mockERC20;

    // Empty arrays
    address[] tokensReturnEmpty;
    IRouter.Input[] inputsEmpty;
    IRouter.Output[] outputsEmpty;

    function setUp() external {
        user = makeAddr('User');

        router = new Router();
        flashLoanCallback = new FlashLoanCallbackBalancerV2(address(router), address(balancerV2Vault));
        mockERC20 = new MockERC20('Mock ERC20', 'mERC20');

        vm.label(address(router), 'Router');
        vm.label(address(flashLoanCallback), 'FlashLoanCallbackBalancerV2');
        vm.label(address(balancerV2Vault), 'BalancerV2Vault');
        vm.label(address(mockERC20), 'mERC20');
    }

    // Cannot call flash loan callback directly
    function testCannotBeCalledByInvalidCaller() external {
        address[] memory tokens = new address[](0);
        uint256[] memory amounts = new uint256[](0);
        uint256[] memory feeAmounts = new uint256[](0);

        // Execute
        vm.startPrank(user);
        vm.expectRevert(IFlashLoanCallbackBalancerV2.InvalidCaller.selector);
        flashLoanCallback.receiveFlashLoan(tokens, amounts, feeAmounts, '');
        vm.stopPrank();
    }

    function testCannotHaveExcessBalance() external {
        address[] memory tokens = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        uint256[] memory feeAmounts = new uint256[](1);

        tokens[0] = address(mockERC20);
        amounts[0] = 1;
        feeAmounts[0] = 2;
        uint256 feeExcess = feeAmounts[0] + 3;

        // Airdrop token and excess fee to Router
        deal(tokens[0], address(flashLoanCallback), amounts[0] + 10); // Assume someone deliberately donates 10 tokens to callback in advanced
        deal(tokens[0], address(router), feeExcess);

        // Encode a logic which transfers token + excess fee to callback
        IRouter.Logic[] memory logics = new IRouter.Logic[](1);
        logics[0] = IRouter.Logic(
            address(tokens[0]), // to
            abi.encodeWithSelector(IERC20.transfer.selector, address(flashLoanCallback), amounts[0] + feeExcess),
            inputsEmpty,
            outputsEmpty,
            address(0) // callback
        );

        // Encode execute data
        bytes memory userData = abi.encodeWithSelector(IRouter.execute.selector, logics, tokensReturnEmpty);

        // Execute
        vm.startPrank(address(balancerV2Vault));
        vm.expectRevert(abi.encodeWithSelector(IFlashLoanCallbackBalancerV2.ExcessBalance.selector, tokens[0]));
        flashLoanCallback.receiveFlashLoan(tokens, amounts, feeAmounts, userData);
        vm.stopPrank();
    }
}
