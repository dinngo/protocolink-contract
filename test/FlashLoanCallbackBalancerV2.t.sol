// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {SafeERC20, IERC20} from 'openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol';
import {Router, IRouter} from '../src/Router.sol';
import {FlashLoanCallbackBalancerV2, IFlashLoanCallbackBalancerV2} from '../src/FlashLoanCallbackBalancerV2.sol';
import {IBalancerV2Vault} from '../src/interfaces/balancerV2/IBalancerV2Vault.sol';

contract FlashLoanCallbackBalancerV2Test is Test {
    IBalancerV2Vault public constant balancerV2Vault = IBalancerV2Vault(0xBA12222222228d8Ba445958a75a0704d566BF2C8);

    address public user;
    IRouter public router;
    IFlashLoanCallbackBalancerV2 public flashLoanCallback;

    function setUp() external {
        user = makeAddr('user');

        router = new Router();
        flashLoanCallback = new FlashLoanCallbackBalancerV2(address(router), address(balancerV2Vault));

        vm.label(address(router), 'Router');
        vm.label(address(flashLoanCallback), 'FlashLoanCallbackBalancerV2');
        vm.label(address(balancerV2Vault), 'BalancerV2Vault');
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
}
