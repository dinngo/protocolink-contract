// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "../src/Router.sol";
import "../src/FlashloanBalancerV2.sol";
import "../src/interfaces/balancerV2/IBalancerV2Vault.sol";

contract FlashloanBalancerV2Test is Test {
    using SafeERC20 for IERC20;

    IBalancerV2Vault public constant balancerV2Vault = IBalancerV2Vault(0xBA12222222228d8Ba445958a75a0704d566BF2C8);
    IERC20 public constant USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);

    address public user;
    IRouter public router;
    IFlashloanBalancerV2 public flashloan;

    function setUp() external {
        user = makeAddr("user");

        router = new Router();
        flashloan = new FlashloanBalancerV2(address(router), address(balancerV2Vault));

        vm.label(address(router), "Router");
        vm.label(address(flashloan), "FlashloanBalancerV2");
        vm.label(address(USDC), "USDC");
    }

    function testExecuteFlashloanBalancerV2(uint256 amountIn) external {
        vm.assume(amountIn > 1e6);
        IERC20 token = USDC;
        amountIn = bound(amountIn, 1, token.balanceOf(address(balancerV2Vault)) / 2);
        vm.label(address(token), "Token");

        address[] memory tokens = new address[](1);
        tokens[0] = address(token);

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amountIn;

        // Encode logics
        IRouter.Logic[] memory logics = new IRouter.Logic[](1);
        logics[0] = _logicFlashloanBalancerV2(tokens, amounts);

        // Execute
        address[] memory tokensOut = new address[](0);
        uint256[] memory amountsOutMin = new uint256[](0);
        vm.prank(user);
        router.execute(tokensOut, amountsOutMin, logics);

        assertEq(token.balanceOf(address(router)), 0);
        assertEq(token.balanceOf(address(flashloan)), 0);
        assertEq(token.balanceOf(address(user)), 0);
    }

    function _logicFlashloanBalancerV2(address[] memory tokens, uint256[] memory amounts)
        public
        view
        returns (IRouter.Logic memory)
    {
        IRouter.AmountInConfig[] memory configsEmpty = new IRouter.AmountInConfig[](0);

        // Encode logic
        address receiver = address(flashloan);
        bytes memory userData = _encodeExecuteUserSet(tokens, amounts);

        return IRouter.Logic(
            address(balancerV2Vault), // to
            configsEmpty,
            abi.encodeWithSelector(IBalancerV2Vault.flashLoan.selector, receiver, tokens, amounts, userData)
        );
    }

    function _encodeExecuteUserSet(address[] memory tokens, uint256[] memory amounts)
        public
        view
        returns (bytes memory)
    {
        // Encode logics
        IRouter.Logic[] memory logics = new IRouter.Logic[](tokens.length);
        IRouter.AmountInConfig[] memory configsEmpty = new IRouter.AmountInConfig[](0);

        for (uint256 i = 0; i < tokens.length; i++) {
            // Encode transfering token to flashloan callback
            logics[i] = IRouter.Logic(
                address(tokens[i]), // to
                configsEmpty,
                abi.encodeWithSelector(IERC20.transfer.selector, address(flashloan), amounts[i])
            );
        }

        // Encode executeUserSet data
        address[] memory tokensOut = new address[](0);
        uint256[] memory amountsOutMin = new uint256[](0);
        return abi.encodeWithSelector(IRouter.executeUserSet.selector, tokensOut, amountsOutMin, logics);
    }
}
