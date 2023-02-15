// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {ERC20} from 'openzeppelin-contracts/contracts/token/ERC20/ERC20.sol';
import {SafeERC20, IERC20} from 'openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol';
import {Router, IRouter} from '../src/Router.sol';
import {FlashLoanCallbackAaveV2, IFlashLoanCallbackAaveV2, IAaveV2Provider} from '../src/FlashLoanCallbackAaveV2.sol';

contract FlashLoanCallbackAaveV2Test is Test {
    IAaveV2Provider public constant aaveV2Provider = IAaveV2Provider(0xB53C1a33016B2DC2fF3653530bfF1848a515c8c5);

    address public user;
    IRouter public router;
    IFlashLoanCallbackAaveV2 public flashLoanCallback;
    IERC20 public mockERC20;

    // Empty arrays
    address[] tokensReturnEmpty;
    IRouter.Input[] inputsEmpty;
    IRouter.Output[] outputsEmpty;

    function setUp() external {
        user = makeAddr('User');

        router = new Router();
        flashLoanCallback = new FlashLoanCallbackAaveV2(address(router), address(aaveV2Provider));
        mockERC20 = new ERC20('mockERC20', 'mock');

        vm.label(address(router), 'Router');
        vm.label(address(flashLoanCallback), 'FlashLoanCallbackAaveV2');
        vm.label(address(aaveV2Provider), 'AaveV2Provider');
        vm.label(address(mockERC20), 'mERC20');
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

    function testCannotHaveInvalidBalance() external {
        address[] memory assets = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        uint256[] memory premiums = new uint256[](1);

        assets[0] = address(mockERC20);
        amounts[0] = 1;
        premiums[0] = 2;
        uint256 premiumExcess = premiums[0] + 3;

        // Airdrop asset and excess premium to Router
        deal(assets[0], address(flashLoanCallback), amounts[0] + 10); // Assume someone deliberately donates 10 assets to callback in advanced
        deal(assets[0], address(router), premiumExcess);

        // Encode a logic which transfers asset + excess premium to callback
        IRouter.Logic[] memory logics = new IRouter.Logic[](1);
        logics[0] = IRouter.Logic(
            address(assets[0]), // to
            abi.encodeWithSelector(IERC20.transfer.selector, address(flashLoanCallback), amounts[0] + premiumExcess),
            inputsEmpty,
            outputsEmpty,
            address(0), // approveTo
            address(0) // callback
        );

        // Encode execute data
        bytes memory params = abi.encodeWithSelector(IRouter.execute.selector, logics, tokensReturnEmpty);

        // Execute
        vm.startPrank(aaveV2Provider.getLendingPool());
        vm.expectRevert(abi.encodeWithSelector(IFlashLoanCallbackAaveV2.InvalidBalance.selector, assets[0]));
        flashLoanCallback.executeOperation(assets, amounts, premiums, address(0), params);
        vm.stopPrank();
    }
}
