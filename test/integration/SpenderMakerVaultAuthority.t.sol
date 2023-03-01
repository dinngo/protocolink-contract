// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {IERC20} from 'openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol';
import {SpenderMakerVaultAuthority, ISpenderMakerVaultAuthority} from '../../src/SpenderMakerVaultAuthority.sol';
import {Router, IRouter} from '../../src/Router.sol';
import {IDSProxy, IDSProxyRegistry} from '../../src/interfaces/maker/IDSProxy.sol';
import {IMakerManager, IMakerVat} from '../../src/interfaces/maker/IMaker.sol';
import {SpenderERC20Approval, ISpenderERC20Approval} from '../../src/SpenderERC20Approval.sol';

contract SpenderMakerVaultAuthorityTest is Test {
    address public constant NATIVE = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address public constant LINK_TOKEN = 0x514910771AF9Ca656af840dff83E8264EcF986CA;

    // MCD contract address
    address public constant PROXY_REGISTRY = 0x4678f0a6958e4D2Bc4F1BAF7Bc52E8F3564f3fE4;
    address public constant CDP_MANAGER = 0x5ef30b9986345249bc32d8928B7ee64DE9435E39;
    address public constant VAT = 0x35D1b3F3D7966A1DFe207aa4514C12a259A0492B;
    address public constant PROXY_ACTIONS = 0x82ecD135Dce65Fbc6DbdD0e4237E0AF93FFD5038;
    address public constant JUG = 0x19c0976f590D67707E62397C87829d896Dc0f1F1;
    address public constant ETH_JOIN_A = 0x2F0b23f53734252Bda2277357e97e1517d6B042A;
    address public constant DAI_JOIN = 0x9759A6Ac90977b93B58547b4A71c78317f391A28;
    address public constant GEM_JOIN_LINK_A = 0xdFccAf8fDbD2F4805C174f856a317765B49E4a50;
    address public constant DAI_TOKEN = 0x6B175474E89094C44Da98b954EedeAC495271d0F;

    address public constant GEM = LINK_TOKEN;
    string public constant ETH_JOIN_NAME = 'ETH-A';
    string public constant TOKEN_JOIN_NAME = 'LINK-A';
    uint256 public constant DRAW_DAI_AMOUNT = 20000 ether;

    ISpenderMakerVaultAuthority public spenderMaker;
    address public user;
    IRouter public router;
    address public userDSProxy;
    address public routerDSProxy;
    uint256 ethCdp;
    uint256 gemCdp;

    // Empty arrays
    address[] tokensReturnEmpty;
    IRouter.Input[] inputsEmpty;
    IRouter.Output[] outputsEmpty;

    function setUp() external {
        user = makeAddr('User');
        router = new Router();
        spenderMaker = new SpenderMakerVaultAuthority(
            address(router),
            PROXY_REGISTRY,
            CDP_MANAGER,
            PROXY_ACTIONS,
            DAI_TOKEN,
            JUG
        );

        // Build user's DSProxy
        vm.startPrank(user);
        userDSProxy = IDSProxyRegistry(PROXY_REGISTRY).build();

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
        ethCdp = uint256(ret);
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
        gemCdp = uint256(ret);
        assertEq(IERC20(DAI_TOKEN).balanceOf(user), DRAW_DAI_AMOUNT * 2);

        // approve
        address spenderMakerDSProxy = IDSProxyRegistry(PROXY_REGISTRY).proxies(address(spenderMaker));
        _allowCdp(userDSProxy, ethCdp, spenderMakerDSProxy);
        _allowCdp(userDSProxy, gemCdp, spenderMakerDSProxy);

        vm.stopPrank();

        // Label
        vm.label(address(router), 'Router');
        vm.label(address(spenderMaker), 'SpenderMaker');
        vm.label(address(spenderMakerDSProxy), 'SpenderMakerDSProxy');
        vm.label(address(routerDSProxy), 'RouterDSProxy');
        vm.label(address(userDSProxy), 'UserDSProxy');
        vm.label(PROXY_REGISTRY, 'PROXY_REGISTRY');
        vm.label(CDP_MANAGER, 'CDP_MANAGER');
        vm.label(VAT, 'VAT');
        vm.label(PROXY_ACTIONS, 'PROXY_ACTIONS');
        vm.label(DAI_TOKEN, 'DAI_TOKEN');
        vm.label(JUG, 'JUG');
        vm.label(ETH_JOIN_A, 'ETH_JOIN_A');
        vm.label(DAI_JOIN, 'DAI_JOIN');
        vm.label(GEM, 'GEM');
    }

    function testFreeETH() external {
        // Setup
        uint256 freeETHAmount = 1 ether;
        uint256 userEthBalanceBefore = user.balance;

        // Encode logic
        IRouter.Logic[] memory logics = new IRouter.Logic[](1);
        logics[0] = _logicFreeETH(ethCdp, freeETHAmount);

        // Execute
        address[] memory tokensReturn = new address[](1);
        tokensReturn[0] = address(NATIVE);
        vm.prank(user);
        router.execute(logics, tokensReturn);

        assertEq(user.balance - userEthBalanceBefore, freeETHAmount);
        assertEq(address(router).balance, 0);
        assertEq(address(spenderMaker).balance, 0);
    }

    function testFreeGem() external {
        // Setup
        uint256 freeGemAmount = 100 ether;
        uint256 userEthBalanceBefore = IERC20(GEM).balanceOf(user);

        // Encode logic
        IRouter.Logic[] memory logics = new IRouter.Logic[](1);
        logics[0] = _logicFreeGem(gemCdp, freeGemAmount, GEM);

        // Execute
        address[] memory tokensReturn = new address[](1);
        tokensReturn[0] = address(GEM);
        vm.prank(user);
        router.execute(logics, tokensReturn);

        uint256 userEthBalanceAfter = IERC20(GEM).balanceOf(user);

        assertEq(userEthBalanceAfter - userEthBalanceBefore, freeGemAmount);
        assertEq(IERC20(GEM).balanceOf(address(router)), 0);
        assertEq(IERC20(GEM).balanceOf(address(spenderMaker)), 0);
    }

    function testDraw() external {
        // Setup
        uint256 drawDaiAmount = 1000 ether;
        uint256 userDaiBalanceBefore = IERC20(DAI_TOKEN).balanceOf(user);

        // Encode logic
        IRouter.Logic[] memory logics = new IRouter.Logic[](1);
        logics[0] = _logicDraw(ethCdp, drawDaiAmount);

        // Execute
        address[] memory tokensReturn = new address[](1);
        tokensReturn[0] = address(DAI_TOKEN);
        vm.prank(user);
        router.execute(logics, tokensReturn);

        uint256 userDaiBalanceAfter = IERC20(DAI_TOKEN).balanceOf(user);

        assertEq(userDaiBalanceAfter - userDaiBalanceBefore, drawDaiAmount);
        assertEq(IERC20(DAI_TOKEN).balanceOf(address(router)), 0);
        assertEq(IERC20(DAI_TOKEN).balanceOf(address(spenderMaker)), 0);
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

    function _logicFreeETH(uint256 cdp, uint256 amount) internal view returns (IRouter.Logic memory) {
        // Prepare datas
        bytes memory data = abi.encodeWithSelector(
            ISpenderMakerVaultAuthority.freeETH.selector,
            ETH_JOIN_A,
            cdp,
            amount
        );

        // Encode outputs
        IRouter.Output[] memory outputs = new IRouter.Output[](1);
        outputs[0].token = NATIVE;
        outputs[0].amountMin = amount;

        return
            IRouter.Logic(
                address(spenderMaker),
                data,
                inputsEmpty,
                outputs,
                address(0), // approveTo,
                address(0) // callback
            );
    }

    function _logicFreeGem(
        uint256 cdp,
        uint256 amount,
        address collateral
    ) internal view returns (IRouter.Logic memory) {
        // Prepare datas
        bytes memory data = abi.encodeWithSelector(
            ISpenderMakerVaultAuthority.freeGem.selector,
            GEM_JOIN_LINK_A,
            cdp,
            amount
        );

        // Encode outputs
        IRouter.Output[] memory outputs = new IRouter.Output[](1);
        outputs[0].token = collateral;
        outputs[0].amountMin = amount;

        return
            IRouter.Logic(
                address(spenderMaker),
                data,
                inputsEmpty,
                outputs,
                address(0), // approveTo,
                address(0) // callback
            );
    }

    function _logicDraw(uint256 cdp, uint256 amount) internal view returns (IRouter.Logic memory) {
        // Prepare datas
        bytes memory data = abi.encodeWithSelector(ISpenderMakerVaultAuthority.draw.selector, DAI_JOIN, cdp, amount);

        // Encode outputs
        IRouter.Output[] memory outputs = new IRouter.Output[](1);
        outputs[0].token = DAI_TOKEN;
        outputs[0].amountMin = amount;

        return
            IRouter.Logic(
                address(spenderMaker),
                data,
                inputsEmpty,
                outputs,
                address(0), // approveTo,
                address(0) // callback
            );
    }
}
