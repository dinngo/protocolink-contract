// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {SafeERC20, IERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {Router, IRouter} from "../src/Router.sol";
import {FlashLoanCallbackAaveV2, IFlashLoanCallbackAaveV2, IAaveV2Provider} from "../src/FlashLoanCallbackAaveV2.sol";
import {IAaveV2Pool} from "../src/interfaces/aaveV2/IAaveV2Pool.sol";

contract FlashLoanCallbackAaveV2Test is Test {
    using SafeERC20 for IERC20;

    enum InterestRateMode {
        NONE,
        STABLE,
        VARIABLE
    }

    IAaveV2Provider public constant aaveV2Provider = IAaveV2Provider(0xB53C1a33016B2DC2fF3653530bfF1848a515c8c5);
    IERC20 public constant USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    address public constant AUSDC_V2 = 0xBcca60bB61934080951369a648Fb03DF4F96263C;

    address public user;
    IRouter public router;
    IFlashLoanCallbackAaveV2 public flashLoanCallback;
    IAaveV2Pool pool = IAaveV2Pool(IAaveV2Provider(aaveV2Provider).getLendingPool());

    // Empty arrays
    address[] tokensReturnEmpty;
    IRouter.Input[] inputsEmpty;
    IRouter.Output[] outputsEmpty;

    function setUp() external {
        user = makeAddr("user");

        router = new Router();
        flashLoanCallback = new FlashLoanCallbackAaveV2(address(router), address(aaveV2Provider));

        vm.label(address(router), "Router");
        vm.label(address(flashLoanCallback), "FlashLoanCallbackAaveV2");
        vm.label(address(aaveV2Provider), "AaveV2Provider");
        vm.label(address(pool), "AaveV2Pool");
        vm.label(address(USDC), "USDC");
    }

    function testExecuteAaveV2FlashLoan(uint256 amountIn) external {
        vm.assume(amountIn > 1e6);
        IERC20 token = USDC;
        amountIn = bound(amountIn, 1, token.balanceOf(AUSDC_V2));
        vm.label(address(token), "Token");

        address[] memory tokens = new address[](1);
        tokens[0] = address(token);

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amountIn;

        uint256[] memory modes = new uint256[](1);
        modes[0] = uint256(InterestRateMode.NONE);

        // Encode logics
        IRouter.Logic[] memory logics = new IRouter.Logic[](1);
        logics[0] = _logicAaveV2FlashLoan(tokens, amounts, modes);

        // Execute
        vm.prank(user);
        router.execute(logics, tokensReturnEmpty);

        assertEq(token.balanceOf(address(router)), 0);
        assertEq(token.balanceOf(address(flashLoanCallback)), 0);
        assertEq(token.balanceOf(address(user)), 0);
    }

    function _logicAaveV2FlashLoan(address[] memory tokens, uint256[] memory amounts, uint256[] memory modes)
        public
        returns (IRouter.Logic memory)
    {
        // Encode logic
        address receiverAddress = address(flashLoanCallback);
        address onBehalfOf = address(0);
        bytes memory params = _encodeExecute(tokens, amounts);
        uint16 referralCode = 0;

        return IRouter.Logic(
            address(pool), // to
            abi.encodeWithSelector(
                IAaveV2Pool.flashLoan.selector,
                receiverAddress,
                tokens,
                amounts,
                modes,
                onBehalfOf,
                params,
                referralCode
            ),
            inputsEmpty,
            outputsEmpty,
            address(flashLoanCallback) // callback
        );
    }

    function _encodeExecute(address[] memory tokens, uint256[] memory amounts)
        public
        returns (bytes memory)
    {
        // Encode logics
        IRouter.Logic[] memory logics = new IRouter.Logic[](tokens.length);
        for (uint256 i = 0; i < tokens.length; i++) {
            // Airdrop fee to Router
            uint256 fee = amounts[i] * 9 / 10000;
            deal(address(tokens[i]), address(router), fee);

            // Encode transfering token + fee to the flash loan callback
            logics[i] = IRouter.Logic(
                address(tokens[i]), // to
                abi.encodeWithSelector(IERC20.transfer.selector, address(flashLoanCallback), amounts[i] + fee),
                inputsEmpty,
                outputsEmpty,
                address(0) // callback
            );
        }

        // Encode executeByCallback data
        return abi.encodeWithSelector(IRouter.execute.selector, logics, tokensReturnEmpty);
    }
}
