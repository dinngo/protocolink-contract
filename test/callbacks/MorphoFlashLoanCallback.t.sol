// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {ERC20, IERC20} from 'lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol';
import {IAgent} from 'src/interfaces/IAgent.sol';
import {DataType} from 'src/libraries/DataType.sol';
import {MorphoFlashLoanCallback, IMorphoFlashLoanCallback} from 'src/callbacks/MorphoFlashLoanCallback.sol';
import {console2} from 'forge-std/console2.sol';

contract MorphoFlashLoanCallbackTest is Test {
    address public constant MORPHO = 0x64c7044050Ba0431252df24fEd4d9635a275CB41;
    uint256 public constant BPS_BASE = 10_000;

    address public user;
    address public defaultCollector;
    bytes32 public defaultReferral;
    address public router;
    address public agent;
    IMorphoFlashLoanCallback public flashLoanCallback;
    IERC20 public mockERC20;

    // Empty arrays
    DataType.Input[] public inputsEmpty;

    function setUp() external {
        vm.createSelectFork(vm.rpcUrl('goerli'), 10310460);

        user = makeAddr('User');
        defaultCollector = makeAddr('defaultCollector');
        defaultReferral = bytes32(bytes20(defaultCollector)) | bytes32(uint256(BPS_BASE));
        // Setup router and agent mock
        router = makeAddr('Router');
        vm.etch(router, 'code');
        agent = makeAddr('Agent');
        vm.etch(agent, 'code');

        flashLoanCallback = new MorphoFlashLoanCallback(address(router), MORPHO, 0);
        mockERC20 = new ERC20('mockERC20', 'mock');

        // Return activated agent from router
        vm.mockCall(router, 0, abi.encodeWithSignature('getCurrentUserAgent()'), abi.encode(user, agent));
        vm.mockCall(router, 0, abi.encodeWithSignature('defaultCollector()'), abi.encode(defaultCollector));
        vm.mockCall(router, 0, abi.encodeWithSignature('defaultReferral()'), abi.encode(defaultReferral));
        vm.mockCall(agent, 0, abi.encodeWithSignature('isCharging()'), abi.encode(true));
        vm.label(address(flashLoanCallback), 'MorphoFlashLoanCallback');
        vm.label(MORPHO, 'Morpho');
        vm.label(address(mockERC20), 'mERC20');
    }

    // Cannot call flash loan callback receive function directly
    function testCannotBeCalledByInvalidCaller() external {
        uint256 amount;

        // Execute
        vm.startPrank(user);
        vm.expectRevert(IMorphoFlashLoanCallback.InvalidCaller.selector);
        flashLoanCallback.onMorphoFlashLoan(amount, '');
        vm.stopPrank();
    }

    function testCannotHaveInvalidBalance() external {
        address token = address(mockERC20);
        uint256 amount = 1;
        uint256 feeAmount = 2;
        uint256 feeExcess = feeAmount + 3;

        // Airdrop token and excess fee to Router
        deal(token, address(flashLoanCallback), amount + 10); // Assume someone deliberately donates 10 tokens to callback in advanced
        deal(token, agent, feeExcess);

        // Encode a logic which transfers token + excess fee to callback
        DataType.Logic[] memory logics = new DataType.Logic[](1);
        logics[0] = DataType.Logic(
            address(token), // to
            abi.encodeWithSelector(IERC20.transfer.selector, address(flashLoanCallback), amount + feeExcess),
            inputsEmpty,
            DataType.WrapMode.NONE,
            address(0), // approveTo
            address(0) // callback
        );

        // Encode execute data
        bytes memory data = abi.encode(logics);
        bytes memory userData = abi.encode(token, data);

        // Execute
        vm.startPrank(MORPHO);
        vm.expectRevert(abi.encodeWithSelector(IMorphoFlashLoanCallback.InvalidBalance.selector, token));
        flashLoanCallback.onMorphoFlashLoan(amount, userData);
        vm.stopPrank();
    }
}
