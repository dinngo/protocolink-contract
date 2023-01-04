// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "../src/Router.sol";
import "../src/FlashloanAaveV2.sol";
import "../src/interfaces/aaveV2/ILendingPoolAddressesProviderV2.sol";
import "../src/interfaces/aaveV2/ILendingPoolV2.sol";

contract FlashloanAaveV2Test is Test {
    using SafeERC20 for IERC20;

    enum InterestRateMode {
        NONE,
        STABLE,
        VARIABLE
    }

    ILendingPoolAddressesProviderV2 public constant aaveV2Provider =
        ILendingPoolAddressesProviderV2(0xB53C1a33016B2DC2fF3653530bfF1848a515c8c5);
    IERC20 public constant USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    address public constant AUSDC_V2 = 0xBcca60bB61934080951369a648Fb03DF4F96263C;

    address public user;
    IRouter public router;
    IFlashloanAaveV2 public flashloan;
    ILendingPoolV2 pool = ILendingPoolV2(ILendingPoolAddressesProviderV2(aaveV2Provider).getLendingPool());

    function setUp() external {
        user = makeAddr("user");

        router = new Router();
        flashloan = new FlashloanAaveV2(address(router), address(aaveV2Provider));

        vm.label(address(router), "Router");
        vm.label(address(flashloan), "FlashloanAaveV2");
        vm.label(address(aaveV2Provider), "AaveV2Provider");
        vm.label(address(pool), "AaveV2Pool");
        vm.label(address(USDC), "USDC");
    }

    function testExecuteFlashloanAaveV2(uint256 amountIn) external {
        vm.assume(amountIn > 1e6);
        IERC20 asset = USDC;
        amountIn = bound(amountIn, 1, asset.balanceOf(AUSDC_V2));
        vm.label(address(asset), "Asset");

        address[] memory assets = new address[](1);
        assets[0] = address(asset);

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amountIn;

        uint256[] memory modes = new uint256[](1);
        modes[0] = uint256(InterestRateMode.NONE);

        // Encode logics
        IRouter.Logic[] memory logics = new IRouter.Logic[](1);
        logics[0] = _logicFlashloanAaveV2(assets, amounts, modes);

        // Execute
        address[] memory tokensOut = new address[](0);
        uint256[] memory amountsOutMin = new uint256[](0);
        vm.prank(user);
        router.execute(tokensOut, amountsOutMin, logics);

        assertEq(asset.balanceOf(address(router)), 0);
        assertEq(asset.balanceOf(address(flashloan)), 0);
        assertEq(asset.balanceOf(address(user)), 0);
    }

    function _logicFlashloanAaveV2(address[] memory assets, uint256[] memory amounts, uint256[] memory modes)
        public
        returns (IRouter.Logic memory)
    {
        IRouter.AmountInConfig[] memory configsEmpty = new IRouter.AmountInConfig[](0);

        // Encode logic
        address receiverAddress = address(flashloan);
        address onBehalfOf = address(0);
        bytes memory params = _encodeExecuteUserSet(assets, amounts);
        uint16 referralCode = 0;

        return IRouter.Logic(
            address(pool), // to
            configsEmpty,
            abi.encodeWithSelector(
                ILendingPoolV2.flashLoan.selector,
                receiverAddress,
                assets,
                amounts,
                modes,
                onBehalfOf,
                params,
                referralCode
            )
        );
    }

    function _encodeExecuteUserSet(address[] memory assets, uint256[] memory amounts) public returns (bytes memory) {
        // Encode logics
        IRouter.Logic[] memory logics = new IRouter.Logic[](assets.length);
        IRouter.AmountInConfig[] memory configsEmpty = new IRouter.AmountInConfig[](0);

        for (uint256 i = 0; i < assets.length; i++) {
            // Airdrop fee to Router
            uint256 fee = amounts[i] * 9 / 10000;
            deal(address(assets[i]), address(router), fee);

            // Encode transfering token + fee to flashloan callback
            logics[i] = IRouter.Logic(
                address(assets[i]), // to
                configsEmpty,
                abi.encodeWithSelector(IERC20.transfer.selector, address(flashloan), amounts[i] + fee)
            );
        }

        // Encode executeUserSet data
        address[] memory tokensOut = new address[](0);
        uint256[] memory amountsOutMin = new uint256[](0);
        return abi.encodeWithSelector(IRouter.executeUserSet.selector, tokensOut, amountsOutMin, logics);
    }
}
