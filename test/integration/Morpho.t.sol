// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {IERC20} from 'lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol';
import {Router, IRouter} from 'src/Router.sol';
import {IAgent} from 'src/interfaces/IAgent.sol';
import {DataType} from 'src/libraries/DataType.sol';
import {MorphoFlashLoanCallback, IMorphoFlashLoanCallback, IMorpho} from 'src/callbacks/MorphoFlashLoanCallback.sol';

contract MorphoIntegrationTest is Test {
    address public constant MORPHO = 0x64c7044050Ba0431252df24fEd4d9635a275CB41;
    IERC20 public constant USDC = IERC20(0x62bD2A599664D421132d7C54AB4DbE3233f4f0Ae);

    address public user;
    IRouter public router;
    IAgent public agent;
    IMorphoFlashLoanCallback public flashLoanCallback;

    // Empty arrays
    address[] public tokensReturnEmpty;
    DataType.Input[] public inputsEmpty;
    bytes[] public permit2DatasEmpty;

    function setUp() external {
        vm.createSelectFork(vm.rpcUrl('goerli'), 10310460);

        user = makeAddr('User');
        router = new Router(makeAddr('WrappedNative'), makeAddr('Permit2'), address(this));
        vm.prank(user);
        agent = IAgent(router.newAgent());
        flashLoanCallback = new MorphoFlashLoanCallback(address(router), MORPHO, 0);

        vm.label(address(router), 'Router');
        vm.label(address(agent), 'Agent');
        vm.label(MORPHO, 'Morpho');
        vm.label(address(flashLoanCallback), 'MorphoFlashLoanCallback');
        vm.label(address(USDC), 'USDC');
    }

    function testExecuteMorphoFlashLoan(uint256 amount) external {
        IERC20 borrowedToken = USDC;
        amount = bound(amount, 1e6, borrowedToken.balanceOf(MORPHO));
        address token = address(borrowedToken);
        vm.label(token, 'Borrowed Token');

        // Encode logics
        DataType.Logic[] memory logics = new DataType.Logic[](1);
        logics[0] = _logicMorphoFlashLoan(token, amount);

        // Execute
        vm.prank(user);
        router.execute(permit2DatasEmpty, logics, tokensReturnEmpty);

        assertEq(borrowedToken.balanceOf(address(router)), 0);
        assertEq(borrowedToken.balanceOf(address(agent)), 0);
        assertEq(borrowedToken.balanceOf(address(flashLoanCallback)), 0);
        assertEq(borrowedToken.balanceOf(user), 0);
    }

    function _logicMorphoFlashLoan(address token, uint256 amount) public view returns (DataType.Logic memory) {
        // Encode logic
        bytes memory params = _encodeExecute(token, amount);

        return
            DataType.Logic(
                address(flashLoanCallback), // to
                abi.encodeWithSelector(IMorpho.flashLoan.selector, token, amount, params),
                inputsEmpty,
                DataType.WrapMode.NONE,
                address(0), // approveTo
                address(flashLoanCallback) // callback
            );
    }

    function _encodeExecute(address token, uint256 amount) public view returns (bytes memory) {
        // Encode logics
        DataType.Logic[] memory logics = new DataType.Logic[](1);

        // Encode transfering token to the flash loan callback
        logics[0] = DataType.Logic(
            address(token), // to
            abi.encodeWithSelector(IERC20.transfer.selector, address(flashLoanCallback), amount),
            inputsEmpty,
            DataType.WrapMode.NONE,
            address(0), // approveTo
            address(0) // callback
        );

        // Encode execute data
        return abi.encode(logics);
    }
}
