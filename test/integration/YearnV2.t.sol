// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {IERC20} from 'openzeppelin-contracts/contracts/token/ERC20/IERC20.sol';
import {IAgent} from 'src/interfaces/IAgent.sol';
import {Router, IRouter} from 'src/Router.sol';
import {IParam} from 'src/interfaces/IParam.sol';
import {ERC20Permit2Utils} from '../utils/ERC20Permit2Utils.sol';

interface IYVault {
    function deposit(uint256) external;

    function balanceOf(address) external returns (uint256);
}

// Test Yearn V2 which is also an ERC20-compliant token
contract YearnV2Test is Test, ERC20Permit2Utils {
    IERC20 public constant USDT = IERC20(0xdAC17F958D2ee523a2206206994597C13D831ec7); // USDT
    IYVault public constant yVault = IYVault(0x2f08119C6f07c006695E079AAFc638b8789FAf18); // yUSDT
    uint256 public constant BPS_BASE = 10_000;
    uint256 public constant BPS_NOT_USED = 0;
    uint256 internal constant _DUST = 10;

    address public user;
    uint256 public userPrivateKey;
    IRouter public router;
    IAgent public agent;
    bytes[] public permit2DatasEmpty;

    function setUp() external {
        (user, userPrivateKey) = makeAddrAndKey('User');
        router = new Router(
            makeAddr('WrappedNative'),
            permit2Addr,
            address(this),
            makeAddr('Pauser'),
            makeAddr('FeeCollector')
        );
        vm.prank(user);
        agent = IAgent(router.newAgent());

        // User permit token
        erc20Permit2UtilsSetUp(user, userPrivateKey, address(agent));
        permitToken(USDT);

        vm.label(address(router), 'Router');
        vm.label(address(USDT), 'USDT');
        vm.label(address(yVault), 'yVault');
    }

    function testExecuteYearn(uint128 amountIn) external {
        vm.assume(amountIn > 1);
        IERC20 tokenIn = USDT;
        IERC20 tokenOut = IERC20(address(yVault));
        deal(address(tokenIn), user, amountIn);

        // Encode permit2Datas
        bytes[] memory datas = new bytes[](1);
        datas[0] = dataERC20Permit2PullToken(tokenIn, uint160(amountIn));

        // Encode logics
        IParam.Logic[] memory logics = new IParam.Logic[](1);
        logics[0] = _logicYearn(tokenIn, amountIn, BPS_BASE);

        // Execute
        address[] memory tokensReturn = new address[](1);
        tokensReturn[0] = address(tokenOut);
        vm.prank(user);
        router.execute(datas, logics, tokensReturn, SIGNER_REFERRAL);

        assertEq(tokenIn.balanceOf(address(router)), 0);
        assertEq(tokenIn.balanceOf(address(agent)), 0);
        assertEq(yVault.balanceOf(address(router)), 0);
        if (yVault.balanceOf(user) == 0) {
            assertLe(yVault.balanceOf(address(agent)), _DUST);
        } else {
            assertEq(yVault.balanceOf(address(agent)), 0);
        }
    }

    function _logicYearn(
        IERC20 tokenIn,
        uint256 amountIn,
        uint256 balanceBps
    ) public pure returns (IParam.Logic memory) {
        // Encode inputs
        IParam.Input[] memory inputs = new IParam.Input[](1);
        inputs[0].token = address(tokenIn);
        inputs[0].balanceBps = balanceBps;
        if (inputs[0].balanceBps == BPS_NOT_USED) inputs[0].amountOrOffset = amountIn;
        else inputs[0].amountOrOffset = 0;

        return
            IParam.Logic(
                address(yVault), // to
                abi.encodeWithSelector(yVault.deposit.selector, 0), // amount will be replaced with balance
                inputs,
                IParam.WrapMode.NONE,
                address(0), // approveTo
                address(0) // callback
            );
    }
}
