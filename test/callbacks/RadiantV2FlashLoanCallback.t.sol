// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {ERC20, IERC20} from 'lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol';
import {IAgent} from 'src/interfaces/IAgent.sol';
import {DataType} from 'src/libraries/DataType.sol';
import {IAaveV2FlashLoanCallback, IAaveV2Provider} from 'src/callbacks/RadiantV2FlashLoanCallback.sol';
import {RadiantV2FlashLoanCallback} from 'src/callbacks/RadiantV2FlashLoanCallback.sol';

contract RadiantV2FlashLoanCallbackTest is Test {
    IAaveV2Provider public constant radiantV2Provider = IAaveV2Provider(0x091d52CacE1edc5527C99cDCFA6937C1635330E4);
    uint256 public constant BPS_BASE = 10_000;

    address public user;
    address public defaultCollector;
    bytes32 public defaultReferral;
    address public router;
    address public agent;
    IAaveV2FlashLoanCallback public flashLoanCallback;
    IERC20 public mockERC20;

    // Empty arrays
    DataType.Input[] public inputsEmpty;

    function setUp() external {
        vm.createSelectFork(vm.rpcUrl('arbitrum'));

        user = makeAddr('User');
        defaultCollector = makeAddr('defaultCollector');
        defaultReferral = bytes32(bytes20(defaultCollector)) | bytes32(uint256(BPS_BASE));
        // Setup router and agent mock
        router = makeAddr('Router');
        vm.etch(router, 'code');
        agent = makeAddr('Agent');
        vm.etch(agent, 'code');

        flashLoanCallback = new RadiantV2FlashLoanCallback(router, address(radiantV2Provider), 0);
        mockERC20 = new ERC20('mockERC20', 'mock');

        // Return activated agent from router
        vm.mockCall(router, 0, abi.encodeWithSignature('getCurrentUserAgent()'), abi.encode(user, agent));
        vm.mockCall(router, 0, abi.encodeWithSignature('defaultCollector()'), abi.encode(defaultCollector));
        vm.mockCall(router, 0, abi.encodeWithSignature('defaultReferral()'), abi.encode(defaultReferral));
        vm.mockCall(agent, 0, abi.encodeWithSignature('isCharging()'), abi.encode(true));
        vm.label(address(flashLoanCallback), 'RadiantV2FlashLoanCallback');
        vm.label(address(radiantV2Provider), 'RadiantV2Provider');
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
        DataType.Logic[] memory logics = new DataType.Logic[](1);
        logics[0] = DataType.Logic(
            address(assets[0]), // to
            abi.encodeWithSelector(IERC20.transfer.selector, address(flashLoanCallback), amounts[0] + premiumExcess),
            inputsEmpty,
            DataType.WrapMode.NONE,
            address(0), // approveTo
            address(0) // callback
        );

        // Encode execute data
        bytes memory params = abi.encode(logics);

        // Execute
        vm.startPrank(radiantV2Provider.getLendingPool());
        vm.expectRevert(abi.encodeWithSelector(IAaveV2FlashLoanCallback.InvalidBalance.selector, assets[0]));
        flashLoanCallback.executeOperation(assets, amounts, premiums, address(0), params);
        vm.stopPrank();
    }
}
