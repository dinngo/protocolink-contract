// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {IERC20} from 'openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol';
import {SpenderMakerVaultAuthority, ISpenderMakerVaultAuthority} from '../../src/SpenderMakerVaultAuthority.sol';
import {Router, IRouter} from '../../src/Router.sol';
import {IDSProxy, IDSProxyRegistry} from '../../src/interfaces/maker/IDSProxy.sol';
import {IMakerManager, IMakerVat} from '../../src/interfaces/maker/IMaker.sol';
import {SpenderERC20Approval, ISpenderERC20Approval} from '../../src/SpenderERC20Approval.sol';

contract RouterMakerActionTest is Test {
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
    uint256 public constant RAY = 10 ** 27;
    uint256 public constant DRAW_DAI_AMOUNT = 20000 ether;

    ISpenderERC20Approval public spenderERC20;
    address public user;
    address public user2;
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
        user2 = makeAddr('User2');
        router = new Router();
        spenderERC20 = new SpenderERC20Approval(address(router));

        // Build user's DSProxy
        vm.startPrank(user);
        userDSProxy = IDSProxyRegistry(PROXY_REGISTRY).build();

        // Build router's DSProxy
        router.execute(_logicBuildRouterDSProxy(), new address[](0));
        routerDSProxy = IDSProxyRegistry(PROXY_REGISTRY).proxies(address(router));

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

        vm.stopPrank();

        // Label
        vm.label(address(router), 'Router');
        vm.label(address(spenderERC20), 'SpenderERC20');
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

    function testSafeLockETH() external {
        // Setup
        uint256 lockETHAmount = 10 ether;
        deal(user2, lockETHAmount);
        uint256 user2BalanceBefore = user2.balance;
        (, uint256 collateralBefore) = _getCdpInfo(ethCdp);

        // Encode logic
        IRouter.Logic[] memory logics = new IRouter.Logic[](1);
        logics[0] = _logicSafeLockETH(ethCdp, lockETHAmount);

        // Execute
        vm.prank(user2);
        router.execute{value: lockETHAmount}(logics, tokensReturnEmpty);

        (, uint256 collateralAfter) = _getCdpInfo(ethCdp);

        assertEq(address(router).balance, 0);
        assertEq(address(routerDSProxy).balance, 0);
        assertEq(user2BalanceBefore - user2.balance, lockETHAmount);
        assertEq(collateralAfter - collateralBefore, lockETHAmount);
    }

    function testSafeLockGem() external {
        // Setup
        uint256 lockGemAmount = 100 ether;
        deal(GEM, user2, lockGemAmount);
        uint256 user2GemBalanceBefore = IERC20(GEM).balanceOf(user2);
        (, uint256 collateralBefore) = _getCdpInfo(gemCdp);

        // User approve to SpenderERC20Approval
        vm.prank(user2);
        IERC20(GEM).approve(address(spenderERC20), type(uint256).max);

        // Encode logic
        IRouter.Logic[] memory logics = new IRouter.Logic[](2);
        logics[0] = _logicSpenderERC20ApprovalPullToken(GEM, lockGemAmount);
        logics[1] = _logicSafeLockGem(gemCdp, lockGemAmount);

        // Execute
        vm.prank(user2);
        router.execute(logics, tokensReturnEmpty);

        (, uint256 collateralAfter) = _getCdpInfo(gemCdp);
        uint256 user2GemBalanceAfter = IERC20(GEM).balanceOf(user2);

        assertEq(IERC20(GEM).balanceOf(address(router)), 0);
        assertEq(IERC20(GEM).balanceOf(address(routerDSProxy)), 0);
        assertEq(user2GemBalanceBefore - user2GemBalanceAfter, lockGemAmount);
        assertEq(collateralAfter - collateralBefore, lockGemAmount);
    }

    function testWipe() external {
        // Setup
        uint256 wipeAmount = 100 ether;
        deal(DAI_TOKEN, user2, wipeAmount);
        uint256 user2DaiBalanceBefore = IERC20(DAI_TOKEN).balanceOf(user2);
        (uint256 debtBefore, ) = _getCdpInfo(gemCdp);

        // User approve to SpenderERC20Approval
        vm.prank(user2);
        IERC20(DAI_TOKEN).approve(address(spenderERC20), type(uint256).max);

        // Encode logic
        IRouter.Logic[] memory logics = new IRouter.Logic[](2);
        logics[0] = _logicSpenderERC20ApprovalPullToken(DAI_TOKEN, wipeAmount);
        logics[1] = _logicWipe(gemCdp, wipeAmount);

        // Execute
        vm.prank(user2);
        router.execute(logics, tokensReturnEmpty);

        (uint256 debtAfter, ) = _getCdpInfo(gemCdp);
        uint256 user2DaiBalanceAfter = IERC20(DAI_TOKEN).balanceOf(user2);

        assertEq(IERC20(DAI_TOKEN).balanceOf(address(router)), 0);
        assertEq(IERC20(DAI_TOKEN).balanceOf(address(routerDSProxy)), 0);
        assertEq(user2DaiBalanceBefore - user2DaiBalanceAfter, wipeAmount);
        assertApproxEqRel(((debtBefore - debtAfter) / RAY), wipeAmount, 0.001e18);
    }

    function testWipeAll() external {
        // Setup
        uint256 wipeAmount = DRAW_DAI_AMOUNT + 100 ether;
        deal(DAI_TOKEN, user2, wipeAmount);
        uint256 user2DaiBalanceBefore = IERC20(DAI_TOKEN).balanceOf(user2);
        (uint256 debtBefore, ) = _getCdpInfo(gemCdp);

        // User approve to SpenderERC20Approval
        vm.prank(user2);
        IERC20(DAI_TOKEN).approve(address(spenderERC20), type(uint256).max);

        // Encode logic
        IRouter.Logic[] memory logics = new IRouter.Logic[](2);
        logics[0] = _logicSpenderERC20ApprovalPullToken(DAI_TOKEN, wipeAmount);
        logics[1] = _logicWipeAll(gemCdp, wipeAmount);

        // Execute
        address[] memory tokensReturn = new address[](1);
        tokensReturn[0] = address(DAI_TOKEN);
        vm.prank(user2);
        router.execute(logics, tokensReturn);

        (uint256 debtAfter, ) = _getCdpInfo(gemCdp);
        uint256 user2DaiBalanceAfter = IERC20(DAI_TOKEN).balanceOf(user2);

        assertEq(IERC20(DAI_TOKEN).balanceOf(address(router)), 0);
        assertEq(IERC20(DAI_TOKEN).balanceOf(address(routerDSProxy)), 0);
        assertApproxEqRel(user2DaiBalanceBefore - user2DaiBalanceAfter, debtBefore / RAY, 0.001e18);
        assertEq(debtAfter, 0);
    }

    function _logicBuildRouterDSProxy() internal view returns (IRouter.Logic[] memory) {
        IRouter.Logic[] memory logics = new IRouter.Logic[](1);
        logics[0] = IRouter.Logic(
            PROXY_REGISTRY,
            abi.encodeWithSelector(IDSProxyRegistry.build.selector),
            inputsEmpty,
            outputsEmpty,
            address(0), // approveTo,
            address(0) // callback
        );

        return logics;
    }

    function _logicSafeLockETH(uint256 cdp, uint256 amount) internal view returns (IRouter.Logic memory) {
        // Prepare data
        bytes memory data = abi.encodeWithSelector(
            IDSProxy.execute.selector,
            PROXY_ACTIONS,
            abi.encodeWithSelector(
                0xee284576, // selector of "safeLockETH(address,address,uint256,address)"
                CDP_MANAGER,
                ETH_JOIN_A,
                cdp,
                userDSProxy
            )
        );

        // Encode inputs
        IRouter.Input[] memory inputs = new IRouter.Input[](1);
        inputs[0].token = NATIVE;
        inputs[0].amountBps = type(uint256).max;
        inputs[0].amountOrOffset = amount;

        return
            IRouter.Logic(
                routerDSProxy,
                data,
                inputs,
                outputsEmpty,
                address(0), // approveTo,
                address(0) // callback);
            );
    }

    function _logicSafeLockGem(uint256 cdp, uint256 amount) internal view returns (IRouter.Logic memory) {
        // Prepare data
        bytes memory data = abi.encodeWithSelector(
            IDSProxy.execute.selector,
            PROXY_ACTIONS,
            abi.encodeWithSelector(
                0xead64729, // selector of "safeLockGem(address,address,uint256,uint256,bool,address)"
                CDP_MANAGER,
                GEM_JOIN_LINK_A,
                cdp,
                amount,
                true,
                userDSProxy
            )
        );

        // Encode inputs
        IRouter.Input[] memory inputs = new IRouter.Input[](1);
        inputs[0].token = GEM;
        inputs[0].amountBps = type(uint256).max;
        inputs[0].amountOrOffset = amount;

        return
            IRouter.Logic(
                routerDSProxy,
                data,
                inputs,
                outputsEmpty,
                routerDSProxy, // approveTo,
                address(0) // callback);
            );
    }

    function _logicWipe(uint256 cdp, uint256 amount) internal view returns (IRouter.Logic memory) {
        // Prepare data
        bytes memory data = abi.encodeWithSelector(
            IDSProxy.execute.selector,
            PROXY_ACTIONS,
            abi.encodeWithSelector(
                0x4b666199, // selector of "wipe(address,address,uint256,uint256)"
                CDP_MANAGER,
                DAI_JOIN,
                cdp,
                amount
            )
        );

        // Encode inputs
        IRouter.Input[] memory inputs = new IRouter.Input[](1);
        inputs[0].token = DAI_TOKEN;
        inputs[0].amountBps = type(uint256).max;
        inputs[0].amountOrOffset = amount;

        return
            IRouter.Logic(
                routerDSProxy,
                data,
                inputs,
                outputsEmpty,
                routerDSProxy, // approveTo,
                address(0) // callback);
            );
    }

    function _logicWipeAll(uint256 cdp, uint256 amount) internal view returns (IRouter.Logic memory) {
        // Prepare data
        bytes memory data = abi.encodeWithSelector(
            IDSProxy.execute.selector,
            PROXY_ACTIONS,
            abi.encodeWithSelector(
                0x036a2395, // selector of "wipeAll(address,address,uint256)"
                CDP_MANAGER,
                DAI_JOIN,
                cdp
            )
        );

        // Encode inputs
        IRouter.Input[] memory inputs = new IRouter.Input[](1);
        inputs[0].token = DAI_TOKEN;
        inputs[0].amountBps = type(uint256).max;
        inputs[0].amountOrOffset = amount;

        return
            IRouter.Logic(
                routerDSProxy,
                data,
                inputs,
                outputsEmpty,
                routerDSProxy, // approveTo,
                address(0) // callback);
            );
    }

    function _getCdpInfo(uint256 cdp) internal view returns (uint256, uint256) {
        address urn = IMakerManager(CDP_MANAGER).urns(cdp);
        bytes32 ilk = IMakerManager(CDP_MANAGER).ilks(cdp);
        (, uint256 rate, , , ) = IMakerVat(VAT).ilks(ilk);
        (uint256 ink, uint256 art) = IMakerVat(VAT).urns(ilk, urn);
        uint256 debt = art * rate;
        return (debt, ink);
    }

    function _logicSpenderERC20ApprovalPullToken(
        address token,
        uint256 amount
    ) internal view returns (IRouter.Logic memory) {
        return
            IRouter.Logic(
                address(spenderERC20),
                abi.encodeWithSelector(ISpenderERC20Approval.pullToken.selector, token, amount),
                inputsEmpty,
                outputsEmpty,
                address(0), // approveTo,
                address(0) // callback);
            );
    }
}
