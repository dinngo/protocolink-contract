// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {SafeERC20, IERC20} from 'openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol';
import {Router, IRouter} from '../src/Router.sol';
import {FlashLoanCallbackAaveV2, IFlashLoanCallbackAaveV2, IAaveV2Provider} from '../src/FlashLoanCallbackAaveV2.sol';

contract FlashLoanCallbackAaveV2Test is Test {
    IAaveV2Provider public constant aaveV2Provider = IAaveV2Provider(0xB53C1a33016B2DC2fF3653530bfF1848a515c8c5);

    address public user;
    IRouter public router;
    IFlashLoanCallbackAaveV2 public flashLoanCallback;

    function setUp() external {
        user = makeAddr('user');

        router = new Router();
        flashLoanCallback = new FlashLoanCallbackAaveV2(address(router), address(aaveV2Provider));

        vm.label(address(router), 'Router');
        vm.label(address(flashLoanCallback), 'FlashLoanCallbackAaveV2');
        vm.label(address(aaveV2Provider), 'AaveV2Provider');
    }

    // Cannot call flash loan callback directly
    function testCannotBeCalledByInvalidCaller() external {
        address[] memory assets = new address[](0);
        uint256[] memory amounts = new uint256[](0);
        uint256[] memory premiums = new uint256[](0);

        // Execute
        vm.startPrank(user);
        vm.expectRevert(IFlashLoanCallbackAaveV2.InvalidCaller.selector);
        flashLoanCallback.executeOperation(assets, amounts, premiums, address(0), '');
        vm.stopPrank();
    }
}
