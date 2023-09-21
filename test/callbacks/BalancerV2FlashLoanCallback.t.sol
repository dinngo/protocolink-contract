// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {ERC20, IERC20} from 'lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol';
import {IAgent} from 'src/interfaces/IAgent.sol';
import {DataType} from 'src/libraries/DataType.sol';
import {BalancerV2FlashLoanCallback, IBalancerV2FlashLoanCallback} from 'src/callbacks/BalancerV2FlashLoanCallback.sol';

contract BalancerV2FlashLoanCallbackTest is Test {
    address public constant BALANCER_V2_VAULT = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;
    uint256 public constant BPS_BASE = 10_000;

    address public user;
    address public defaultCollector;
    bytes32 public defaultReferral;
    address public router;
    address public agent;
    IBalancerV2FlashLoanCallback public flashLoanCallback;
    IERC20 public mockERC20;

    // Empty arrays
    DataType.Input[] public inputsEmpty;

    function setUp() external {
        vm.createSelectFork(vm.rpcUrl('ethereum'));

        user = makeAddr('User');
        defaultCollector = makeAddr('defaultCollector');
        defaultReferral = bytes32(bytes20(defaultCollector)) | bytes32(uint256(BPS_BASE));
        // Setup router and agent mock
        router = makeAddr('Router');
        vm.etch(router, 'code');
        agent = makeAddr('Agent');
        vm.etch(agent, 'code');

        flashLoanCallback = new BalancerV2FlashLoanCallback(address(router), BALANCER_V2_VAULT, 0);
        mockERC20 = new ERC20('mockERC20', 'mock');

        // Return activated agent from router
        vm.mockCall(router, 0, abi.encodeWithSignature('getCurrentUserAgent()'), abi.encode(user, agent));
        vm.mockCall(router, 0, abi.encodeWithSignature('defaultCollector()'), abi.encode(defaultCollector));
        vm.mockCall(router, 0, abi.encodeWithSignature('defaultReferral()'), abi.encode(defaultReferral));
        vm.mockCall(agent, 0, abi.encodeWithSignature('isCharging()'), abi.encode(true));
        vm.label(address(flashLoanCallback), 'BalancerV2FlashLoanCallback');
        vm.label(BALANCER_V2_VAULT, 'BalancerV2Vault');
        vm.label(address(mockERC20), 'mERC20');
    }

    // Cannot call flash loan callback directly
    function testCannotBeCalledByInvalidCaller() external {
        address[] memory tokens = new address[](0);
        uint256[] memory amounts = new uint256[](0);
        uint256[] memory feeAmounts = new uint256[](0);

        // Execute
        vm.startPrank(user);
        vm.expectRevert(IBalancerV2FlashLoanCallback.InvalidCaller.selector);
        flashLoanCallback.receiveFlashLoan(tokens, amounts, feeAmounts, '');
        vm.stopPrank();
    }

    function testCannotHaveInvalidBalance() external {
        address[] memory tokens = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        uint256[] memory feeAmounts = new uint256[](1);

        tokens[0] = address(mockERC20);
        amounts[0] = 1;
        feeAmounts[0] = 2;
        uint256 feeExcess = feeAmounts[0] + 3;

        // Airdrop token and excess fee to Router
        deal(tokens[0], address(flashLoanCallback), amounts[0] + 10); // Assume someone deliberately donates 10 tokens to callback in advanced
        deal(tokens[0], agent, feeExcess);

        // Encode a logic which transfers token + excess fee to callback
        DataType.Logic[] memory logics = new DataType.Logic[](1);
        logics[0] = DataType.Logic(
            address(tokens[0]), // to
            abi.encodeWithSelector(IERC20.transfer.selector, address(flashLoanCallback), amounts[0] + feeExcess),
            inputsEmpty,
            DataType.WrapMode.NONE,
            address(0), // approveTo
            address(0) // callback
        );

        // Encode execute data
        bytes memory userData = abi.encode(logics);

        // Execute
        vm.startPrank(BALANCER_V2_VAULT);
        vm.expectRevert(abi.encodeWithSelector(IBalancerV2FlashLoanCallback.InvalidBalance.selector, tokens[0]));
        flashLoanCallback.receiveFlashLoan(tokens, amounts, feeAmounts, userData);
        vm.stopPrank();
    }
}
