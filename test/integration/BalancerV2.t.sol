// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {IERC20} from 'openzeppelin-contracts/contracts/token/ERC20/IERC20.sol';
import {Router, IRouter} from 'src/Router.sol';
import {IAgent} from 'src/interfaces/IAgent.sol';
import {IParam} from 'src/interfaces/IParam.sol';
import {BalancerV2FlashLoanCallback, IBalancerV2FlashLoanCallback} from 'src/callbacks/BalancerV2FlashLoanCallback.sol';

interface IBalancerV2Vault {
    function flashLoan(
        address receiver,
        address[] calldata tokens,
        uint256[] calldata amounts,
        bytes calldata userData
    ) external;
}

contract BalancerV2IntegrationTest is Test {
    uint256 public constant SIGNER_REFERRAL = 1;
    IBalancerV2Vault public constant balancerV2Vault = IBalancerV2Vault(0xBA12222222228d8Ba445958a75a0704d566BF2C8);
    IERC20 public constant USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);

    address public user;
    IRouter public router;
    IBalancerV2FlashLoanCallback public flashLoanCallback;

    // Empty arrays
    address[] public tokensReturnEmpty;
    IParam.Input[] public inputsEmpty;
    bytes[] public permit2DatasEmpty;

    function setUp() external {
        user = makeAddr('User');
        router = new Router(
            makeAddr('WrappedNative'),
            makeAddr('Permit2'),
            address(this),
            makeAddr('Pauser'),
            makeAddr('FeeCollector')
        );
        flashLoanCallback = new BalancerV2FlashLoanCallback(address(router), address(balancerV2Vault), 0);

        vm.label(address(router), 'Router');
        vm.label(address(flashLoanCallback), 'BalancerV2FlashLoanCallback');
        vm.label(address(balancerV2Vault), 'BalancerV2Vault');
        vm.label(address(USDC), 'USDC');
    }

    function testExecuteBalancerV2FlashLoan(uint256 amountIn) external {
        IERC20 token = USDC;
        amountIn = bound(amountIn, 1e6, token.balanceOf(address(balancerV2Vault)));
        vm.label(address(token), 'Token');

        address[] memory tokens = new address[](1);
        tokens[0] = address(token);

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amountIn;

        // Encode logics
        IParam.Logic[] memory logics = new IParam.Logic[](1);
        logics[0] = _logicBalancerV2FlashLoan(tokens, amounts);

        // Execute
        vm.prank(user);
        router.execute(permit2DatasEmpty, logics, tokensReturnEmpty, SIGNER_REFERRAL);

        address agent = router.getAgent(user);
        assertEq(token.balanceOf(address(router)), 0);
        assertEq(token.balanceOf(address(agent)), 0);
        assertEq(token.balanceOf(address(flashLoanCallback)), 0);
        assertEq(token.balanceOf(user), 0);
    }

    function _logicBalancerV2FlashLoan(
        address[] memory tokens,
        uint256[] memory amounts
    ) public view returns (IParam.Logic memory) {
        // Encode logic
        address receiver = address(flashLoanCallback);
        bytes memory userData = _encodeExecute(tokens, amounts);

        return
            IParam.Logic(
                address(balancerV2Vault), // to
                abi.encodeWithSelector(IBalancerV2Vault.flashLoan.selector, receiver, tokens, amounts, userData),
                inputsEmpty,
                IParam.WrapMode.NONE,
                address(0), // approveTo
                address(flashLoanCallback) // callback
            );
    }

    function _encodeExecute(address[] memory tokens, uint256[] memory amounts) public view returns (bytes memory) {
        // Encode logics
        IParam.Logic[] memory logics = new IParam.Logic[](tokens.length);
        for (uint256 i = 0; i < tokens.length; ++i) {
            // Encode transfering token to the flash loan callback
            logics[i] = IParam.Logic(
                address(tokens[i]), // to
                abi.encodeWithSelector(IERC20.transfer.selector, address(flashLoanCallback), amounts[i]),
                inputsEmpty,
                IParam.WrapMode.NONE,
                address(0), // approveTo
                address(0) // callback
            );
        }

        // Encode execute data
        return abi.encode(logics);
    }
}
