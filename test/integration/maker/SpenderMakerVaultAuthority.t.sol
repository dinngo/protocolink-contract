// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {IERC20} from 'openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol';
import {SpenderMakerVaultAuthority, ISpenderMakerVaultAuthority} from '../../../src/SpenderMakerVaultAuthority.sol';
import {Router, IRouter} from '../../../src/Router.sol';
import {IAgent} from '../../../src/interfaces/IAgent.sol';
import {IParam} from '../../../src/interfaces/IParam.sol';
import {IDSProxy, IDSProxyRegistry} from '../../../src/interfaces/maker/IDSProxy.sol';
import {IMakerManager, IMakerVat} from '../../../src/interfaces/maker/IMaker.sol';
import {MakerCommonUtils} from '../../utils/MakerCommonUtils.sol';

contract SpenderMakerVaultAuthorityTest is Test, MakerCommonUtils {
    address public constant NATIVE = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    uint256 public constant DRAW_DAI_AMOUNT = 20000 ether;

    ISpenderMakerVaultAuthority public spenderMaker;
    address public user;
    address public user2;
    IRouter public router;
    IAgent public userAgent;
    IAgent public user2Agent;
    address public userDSProxy;
    address public user2DSProxy;
    uint256 public userEthCdp;
    uint256 public userGemCdp;
    uint256 public user2EthCdp;

    // Empty arrays
    address[] tokensReturnEmpty;
    IParam.Input[] inputsEmpty;

    function setUp() external {
        user = makeAddr('User');
        user2 = makeAddr('User2');
        router = new Router();
        spenderMaker = new SpenderMakerVaultAuthority(
            address(router),
            PROXY_REGISTRY,
            CDP_MANAGER,
            PROXY_ACTIONS,
            DAI_TOKEN,
            JUG
        );

        // Setup user
        vm.startPrank(user);
        userDSProxy = IDSProxyRegistry(PROXY_REGISTRY).build();
        userAgent = IAgent(router.newAgent());

        // Open ETH Vault
        uint256 ethAmount = 100 ether;
        deal(user, ethAmount);
        bytes32 ret = IDSProxy(userDSProxy).execute{value: ethAmount}(
            PROXY_ACTIONS,
            abi.encodeWithSelector(
                0xe685cc04, // selector of "openLockETHAndDraw(address,address,address,address,bytes32,uint256)"
                CDP_MANAGER,
                JUG,
                ETH_JOIN_A,
                DAI_JOIN,
                bytes32(bytes(ETH_JOIN_NAME)),
                DRAW_DAI_AMOUNT
            )
        );
        userEthCdp = uint256(ret);
        assertEq(IERC20(DAI_TOKEN).balanceOf(user), DRAW_DAI_AMOUNT);

        // Open LINK Vault
        uint256 gemAmount = 500000 ether;
        deal(GEM, user, gemAmount);
        IERC20(GEM).approve(userDSProxy, gemAmount);
        ret = IDSProxy(userDSProxy).execute(
            PROXY_ACTIONS,
            abi.encodeWithSelector(
                // selector of "openLockGemAndDraw(address,address,address,address,bytes32,uint256,uint256,bool)"
                0xdb802a32,
                CDP_MANAGER,
                JUG,
                GEM_JOIN_LINK_A,
                DAI_JOIN,
                bytes32(bytes(TOKEN_JOIN_NAME)),
                gemAmount,
                DRAW_DAI_AMOUNT,
                true
            )
        );
        userGemCdp = uint256(ret);
        assertEq(IERC20(DAI_TOKEN).balanceOf(user), DRAW_DAI_AMOUNT * 2);

        // approve
        address spenderMakerDSProxy = IDSProxyRegistry(PROXY_REGISTRY).proxies(address(spenderMaker));
        _allowCdp(userDSProxy, userEthCdp, spenderMakerDSProxy);
        _allowCdp(userDSProxy, userGemCdp, spenderMakerDSProxy);

        vm.stopPrank();

        // Setup user2 who doesn't give authority
        vm.startPrank(user2);
        user2DSProxy = IDSProxyRegistry(PROXY_REGISTRY).build();
        user2Agent = IAgent(router.newAgent());

        // Open user2 ETH Vault
        deal(user2, ethAmount);
        ret = IDSProxy(user2DSProxy).execute{value: ethAmount}(
            PROXY_ACTIONS,
            abi.encodeWithSelector(
                0xe685cc04, // selector of "openLockETHAndDraw(address,address,address,address,bytes32,uint256)"
                CDP_MANAGER,
                JUG,
                ETH_JOIN_A,
                DAI_JOIN,
                bytes32(bytes(ETH_JOIN_NAME)),
                DRAW_DAI_AMOUNT
            )
        );
        user2EthCdp = uint256(ret);
        assertEq(IERC20(DAI_TOKEN).balanceOf(user2), DRAW_DAI_AMOUNT);

        vm.stopPrank();

        // Label
        vm.label(address(router), 'Router');
        vm.label(address(userAgent), 'UserAgent');
        vm.label(address(user2Agent), 'User2Agent');
        vm.label(address(spenderMaker), 'SpenderMaker');
        vm.label(address(spenderMakerDSProxy), 'SpenderMakerDSProxy');
        vm.label(address(userDSProxy), 'UserDSProxy');
        vm.label(address(user2DSProxy), 'User2DSProxy');

        makerCommonSetUp();
    }

    function testFreeETH() external {
        // Setup
        uint256 freeETHAmount = 1 ether;
        uint256 userEthBalanceBefore = user.balance;

        // Encode logic
        IParam.Logic[] memory logics = new IParam.Logic[](1);
        logics[0] = _logicFreeETH(userEthCdp, freeETHAmount);

        // Execute
        address[] memory tokensReturn = new address[](1);
        tokensReturn[0] = address(NATIVE);
        vm.prank(user);
        router.execute(logics, tokensReturn);

        assertEq(user.balance - userEthBalanceBefore, freeETHAmount);
        assertEq(address(router).balance, 0);
        assertEq(address(userAgent).balance, 0);
        assertEq(address(spenderMaker).balance, 0);
    }

    function testFreeGem() external {
        // Setup
        uint256 freeGemAmount = 100 ether;
        uint256 userEthBalanceBefore = IERC20(GEM).balanceOf(user);

        // Encode logic
        IParam.Logic[] memory logics = new IParam.Logic[](1);
        logics[0] = _logicFreeGem(userGemCdp, freeGemAmount);

        // Execute
        address[] memory tokensReturn = new address[](1);
        tokensReturn[0] = address(GEM);
        vm.prank(user);
        router.execute(logics, tokensReturn);

        uint256 userEthBalanceAfter = IERC20(GEM).balanceOf(user);

        assertEq(userEthBalanceAfter - userEthBalanceBefore, freeGemAmount);
        assertEq(IERC20(GEM).balanceOf(address(router)), 0);
        assertEq(IERC20(GEM).balanceOf(address(userAgent)), 0);
        assertEq(IERC20(GEM).balanceOf(address(spenderMaker)), 0);
    }

    function testDraw() external {
        // Setup
        uint256 drawDaiAmount = 1000 ether;
        uint256 userDaiBalanceBefore = IERC20(DAI_TOKEN).balanceOf(user);

        // Encode logic
        IParam.Logic[] memory logics = new IParam.Logic[](1);
        logics[0] = _logicDraw(userEthCdp, drawDaiAmount);

        // Execute
        address[] memory tokensReturn = new address[](1);
        tokensReturn[0] = address(DAI_TOKEN);
        vm.prank(user);
        router.execute(logics, tokensReturn);

        uint256 userDaiBalanceAfter = IERC20(DAI_TOKEN).balanceOf(user);

        assertEq(userDaiBalanceAfter - userDaiBalanceBefore, drawDaiAmount);
        assertEq(IERC20(DAI_TOKEN).balanceOf(address(router)), 0);
        assertEq(IERC20(DAI_TOKEN).balanceOf(address(userAgent)), 0);
        assertEq(IERC20(DAI_TOKEN).balanceOf(address(spenderMaker)), 0);
    }

    function testFreeETHWithoutAuthority() external {
        // Setup
        uint256 freeETHAmount = 1 ether;

        // Encode logic
        IParam.Logic[] memory logics = new IParam.Logic[](1);
        logics[0] = _logicFreeETH(user2EthCdp, freeETHAmount);

        // Execute
        address[] memory tokensReturn = new address[](1);
        tokensReturn[0] = address(NATIVE);
        vm.expectRevert(abi.encodeWithSelector(ISpenderMakerVaultAuthority.UnauthorizedSender.selector, user2EthCdp));
        vm.prank(user2);
        router.execute(logics, tokensReturn);
    }

    function _allowCdp(address dsProxy, uint256 cdp, address usr) internal {
        IDSProxy(dsProxy).execute(
            PROXY_ACTIONS,
            abi.encodeWithSelector(
                0xba727a95, // selector of "cdpAllow(address,uint256,address,uint256)"
                CDP_MANAGER,
                cdp,
                usr,
                1
            )
        );
    }

    function _logicFreeETH(uint256 cdp, uint256 amount) internal view returns (IParam.Logic memory) {
        // Prepare datas
        bytes memory data = abi.encodeWithSelector(
            ISpenderMakerVaultAuthority.freeETH.selector,
            ETH_JOIN_A,
            cdp,
            amount
        );

        return
            IParam.Logic(
                address(spenderMaker),
                data,
                inputsEmpty,
                address(0) // callback
            );
    }

    function _logicFreeGem(uint256 cdp, uint256 amount) internal view returns (IParam.Logic memory) {
        // Prepare datas
        bytes memory data = abi.encodeWithSelector(
            ISpenderMakerVaultAuthority.freeGem.selector,
            GEM_JOIN_LINK_A,
            cdp,
            amount
        );

        return
            IParam.Logic(
                address(spenderMaker),
                data,
                inputsEmpty,
                address(0) // callback
            );
    }

    function _logicDraw(uint256 cdp, uint256 amount) internal view returns (IParam.Logic memory) {
        // Prepare datas
        bytes memory data = abi.encodeWithSelector(ISpenderMakerVaultAuthority.draw.selector, DAI_JOIN, cdp, amount);

        return
            IParam.Logic(
                address(spenderMaker),
                data,
                inputsEmpty,
                address(0) // callback
            );
    }
}
