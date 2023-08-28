// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {ERC20, IERC20} from 'openzeppelin-contracts/contracts/token/ERC20/ERC20.sol';
import {IAgent} from 'src/interfaces/IAgent.sol';
import {IParam} from 'src/interfaces/IParam.sol';
import {AaveV2FlashLoanCallback, IAaveV2FlashLoanCallback, IAaveV2Provider} from 'src/callbacks/AaveV2FlashLoanCallback.sol';

contract AaveV2FlashLoanCallbackTest is Test {
    IAaveV2Provider public constant aaveV2Provider = IAaveV2Provider(0xB53C1a33016B2DC2fF3653530bfF1848a515c8c5);

    address public user;
    address public feeCollector;
    address public router;
    address public agent;
    IAaveV2FlashLoanCallback public flashLoanCallback;
    IERC20 public mockERC20;

    // Empty arrays
    IParam.Input[] public inputsEmpty;

    function setUp() external {
        user = makeAddr('User');
        feeCollector = makeAddr('feeCollector');
        // Setup router and agent mock
        router = makeAddr('Router');
        vm.etch(router, 'code');
        agent = makeAddr('Agent');
        vm.etch(agent, 'code');

        flashLoanCallback = new AaveV2FlashLoanCallback(router, address(aaveV2Provider), 0);
        mockERC20 = new ERC20('mockERC20', 'mock');

        // Return activated agent from router
        vm.mockCall(router, 0, abi.encodeWithSignature('getCurrentUserAgent()'), abi.encode(user, agent));
        vm.mockCall(router, 0, abi.encodeWithSignature('feeCollector()'), abi.encode(feeCollector));
        vm.mockCall(agent, 0, abi.encodeWithSignature('isCharging()'), abi.encode(true));
        vm.label(address(flashLoanCallback), 'AaveV2FlashLoanCallback');
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
        vm.expectRevert(IAaveV2FlashLoanCallback.InvalidCaller.selector);
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
        deal(assets[0], agent, premiumExcess);

        // Encode a logic which transfers asset + excess premium to callback
        IParam.Logic[] memory logics = new IParam.Logic[](1);
        logics[0] = IParam.Logic(
            address(assets[0]), // to
            abi.encodeWithSelector(IERC20.transfer.selector, address(flashLoanCallback), amounts[0] + premiumExcess),
            inputsEmpty,
            IParam.WrapMode.NONE,
            address(0), // approveTo
            address(0) // callback
        );

        // Encode execute data
        bytes memory params = abi.encode(logics);

        // Execute
        vm.startPrank(aaveV2Provider.getLendingPool());
        vm.expectRevert(abi.encodeWithSelector(IAaveV2FlashLoanCallback.InvalidBalance.selector, assets[0]));
        flashLoanCallback.executeOperation(assets, amounts, premiums, address(0), params);
        vm.stopPrank();
    }
}
