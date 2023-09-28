// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {IERC20} from 'lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol';
import {Router, IRouter} from 'src/Router.sol';
import {IAgent} from 'src/interfaces/IAgent.sol';
import {DataType} from 'src/libraries/DataType.sol';
import {IDSProxy} from 'src/interfaces/maker/IDSProxy.sol';
import {ERC20Permit2Utils} from 'test/utils/ERC20Permit2Utils.sol';
import {MakerCommonUtils, IMakerManager, IMakerVat, IDSProxyRegistry} from 'test/utils/MakerCommonUtils.sol';
import {SafeCast160} from 'lib/permit2/src/libraries/SafeCast160.sol';

contract AgentMakerActionTest is Test, MakerCommonUtils, ERC20Permit2Utils {
    using SafeCast160 for uint256;

    uint256 public constant BPS_NOT_USED = 0;
    address public constant NATIVE = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    uint256 public constant RAY = 10 ** 27;
    uint256 public constant DRAW_DAI_AMOUNT = 20000 ether;

    address public user;
    address public user2;
    uint256 public user2PrivateKey;
    IRouter public router;
    IAgent public userAgent;
    IAgent public user2Agent;
    address public userDSProxy;
    address public userAgentDSProxy;
    address public user2AgentDSProxy;
    uint256 public ethCdp;
    uint256 public gemCdp;

    // Empty arrays
    address[] public tokensReturnEmpty;
    DataType.Input[] public inputsEmpty;
    bytes[] public permit2DatasEmpty;

    function setUp() external {
        vm.createSelectFork(vm.rpcUrl('ethereum'));

        user = makeAddr('User');
        (user2, user2PrivateKey) = makeAddrAndKey('User2');
        router = new Router(makeAddr('WrappedNative'), permit2Addr, address(this));

        // Empty router the balance
        vm.prank(address(router));
        (bool success, ) = payable(address(0)).call{value: address(router).balance}('');
        assertTrue(success);

        // Build user's DSProxy
        vm.startPrank(user);
        userDSProxy = IDSProxyRegistry(PROXY_REGISTRY).build();

        // Build user agent's DSProxy
        userAgent = IAgent(router.newAgent());
        router.execute(permit2DatasEmpty, _logicBuildAgentDSProxy(), tokensReturnEmpty);
        userAgentDSProxy = IDSProxyRegistry(PROXY_REGISTRY).proxies(address(userAgent));

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

        // Open GEM Vault
        uint256 gemAmount = 20 * (10 ** GEM_DECIMAL);
        deal(GEM, user, gemAmount);
        IERC20(GEM).approve(userDSProxy, gemAmount);
        ret = IDSProxy(userDSProxy).execute(
            PROXY_ACTIONS,
            abi.encodeWithSelector(
                // selector of "openLockGemAndDraw(address,address,address,address,bytes32,uint256,uint256,bool)"
                0xdb802a32,
                CDP_MANAGER,
                JUG,
                GEM_JOIN_TOKEN,
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

        _allowCdp(user, userDSProxy, ethCdp, userAgentDSProxy);
        _allowCdp(user, userDSProxy, gemCdp, userAgentDSProxy);

        // Build user2's agent
        vm.startPrank(user2);
        user2Agent = IAgent(router.newAgent());
        router.execute(permit2DatasEmpty, _logicBuildAgentDSProxy(), tokensReturnEmpty);
        user2AgentDSProxy = IDSProxyRegistry(PROXY_REGISTRY).proxies(address(user2Agent));
        vm.stopPrank();

        // Setup permit2
        erc20Permit2UtilsSetUp(user2, user2PrivateKey, address(user2Agent));
        permitToken(IERC20(GEM));
        permitToken(IERC20(DAI_TOKEN));

        // Label
        vm.label(address(router), 'Router');
        vm.label(address(userDSProxy), 'UserDSProxy');
        vm.label(address(userAgent), 'UserAgent');
        vm.label(address(user2Agent), 'User2Agent');
        vm.label(address(userAgentDSProxy), 'UserAgentDSProxy');
        vm.label(address(user2AgentDSProxy), 'User2AgentDSProxy');

        _makerCommonSetUp();
    }

    function testLockETH() external {
        // Setup
        uint256 lockETHAmount = 10 ether;
        deal(user2, lockETHAmount);
        uint256 user2BalanceBefore = user2.balance;
        (, uint256 collateralBefore) = _getCdpInfo(ethCdp);

        // Encode logic
        DataType.Logic[] memory logics = new DataType.Logic[](1);
        logics[0] = _logicLockETH(ethCdp, lockETHAmount);

        // Execute
        vm.prank(user2);
        router.execute{value: lockETHAmount}(permit2DatasEmpty, logics, tokensReturnEmpty);

        (, uint256 collateralAfter) = _getCdpInfo(ethCdp);

        assertEq(address(router).balance, 0);
        assertEq(address(user2Agent).balance, 0);
        assertEq(address(user2AgentDSProxy).balance, 0);
        assertEq(user2BalanceBefore - user2.balance, lockETHAmount);
        assertEq(collateralAfter - collateralBefore, lockETHAmount);
    }

    function testFreeETH() external {
        // Setup
        uint256 freeETHAmount = 1 ether;
        uint256 userEthBalanceBefore = user.balance;

        // Encode logic
        DataType.Logic[] memory logics = new DataType.Logic[](1);
        logics[0] = _logicFreeETH(userAgentDSProxy, ethCdp, freeETHAmount);

        // Execute
        address[] memory tokensReturn = new address[](1);
        tokensReturn[0] = address(NATIVE);
        vm.prank(user);
        router.execute(permit2DatasEmpty, logics, tokensReturn);

        assertEq(user.balance - userEthBalanceBefore, freeETHAmount);
        assertEq(address(router).balance, 0);
        assertEq(address(userAgent).balance, 0);
    }

    function testFreeETHWithAuthority() external {
        // Setup
        uint256 freeETHAmount = 1 ether;
        uint256 user2EthBalanceBefore = user2.balance;

        // User approve to user2
        _allowCdp(user, userDSProxy, ethCdp, user2AgentDSProxy);

        // Encode logic
        DataType.Logic[] memory logics = new DataType.Logic[](1);
        logics[0] = _logicFreeETH(user2AgentDSProxy, ethCdp, freeETHAmount);

        // Execute
        address[] memory tokensReturn = new address[](1);
        tokensReturn[0] = address(NATIVE);
        vm.prank(user2);
        router.execute(permit2DatasEmpty, logics, tokensReturn);

        assertEq(user2.balance - user2EthBalanceBefore, freeETHAmount);
        assertEq(address(router).balance, 0);
        assertEq(address(user2Agent).balance, 0);
    }

    function testFreeETHWithoutAuthority() external {
        // Setup
        uint256 freeETHAmount = 1 ether;

        // Encode logic
        DataType.Logic[] memory logics = new DataType.Logic[](1);
        logics[0] = _logicFreeETH(user2AgentDSProxy, ethCdp, freeETHAmount);

        // Execute
        address[] memory tokensReturn = new address[](1);
        tokensReturn[0] = address(NATIVE);
        vm.expectRevert('ERROR_ROUTER_EXECUTE');
        vm.prank(user2);
        router.execute(permit2DatasEmpty, logics, tokensReturn);
    }

    function testLockGem() external {
        // Setup
        uint256 lockGemAmount = 10 * (10 ** GEM_DECIMAL);
        deal(GEM, user2, lockGemAmount);
        uint256 user2GemBalanceBefore = IERC20(GEM).balanceOf(user2);
        (, uint256 collateralBefore) = _getCdpInfo(gemCdp);

        // Encode permit2Datas
        bytes[] memory datas = new bytes[](1);
        datas[0] = dataERC20Permit2PullToken(IERC20(GEM), lockGemAmount.toUint160());

        // Encode logic
        DataType.Logic[] memory logics = new DataType.Logic[](2);
        logics[0] = _logicAgentERC20ApprovalToDSProxy(user2AgentDSProxy, GEM, lockGemAmount);
        logics[1] = _logicLockGem(gemCdp, lockGemAmount);

        // Execute
        vm.prank(user2);
        router.execute(datas, logics, tokensReturnEmpty);

        (, uint256 collateralAfter) = _getCdpInfo(gemCdp);
        uint256 collateralDiff = (collateralAfter - collateralBefore) / (10 ** (18 - GEM_DECIMAL));
        uint256 user2GemBalanceAfter = IERC20(GEM).balanceOf(user2);

        assertEq(IERC20(GEM).balanceOf(address(router)), 0);
        assertEq(IERC20(GEM).balanceOf(address(user2Agent)), 0);
        assertEq(IERC20(GEM).balanceOf(address(user2AgentDSProxy)), 0);
        assertEq(user2GemBalanceBefore - user2GemBalanceAfter, lockGemAmount);
        assertEq(collateralDiff, lockGemAmount);
    }

    function testFreeGem() external {
        // Setup
        uint256 freeGemAmount = 10 * (10 ** GEM_DECIMAL);
        uint256 userEthBalanceBefore = IERC20(GEM).balanceOf(user);

        // Encode logic
        DataType.Logic[] memory logics = new DataType.Logic[](1);
        logics[0] = _logicFreeGem(gemCdp, freeGemAmount);

        // Execute
        address[] memory tokensReturn = new address[](1);
        tokensReturn[0] = address(GEM);
        vm.prank(user);
        router.execute(permit2DatasEmpty, logics, tokensReturn);

        uint256 userEthBalanceAfter = IERC20(GEM).balanceOf(user);

        assertEq(userEthBalanceAfter - userEthBalanceBefore, freeGemAmount);
        assertEq(IERC20(GEM).balanceOf(address(router)), 0);
        assertEq(IERC20(GEM).balanceOf(address(userAgent)), 0);
    }

    function testWipe() external {
        // Setup
        uint256 wipeAmount = 100 ether;
        deal(DAI_TOKEN, user2, wipeAmount);
        uint256 user2DaiBalanceBefore = IERC20(DAI_TOKEN).balanceOf(user2);
        (uint256 debtBefore, ) = _getCdpInfo(gemCdp);

        // Encode permit2Datas
        bytes[] memory datas = new bytes[](1);
        datas[0] = dataERC20Permit2PullToken(IERC20(DAI_TOKEN), wipeAmount.toUint160());

        // Encode logic
        DataType.Logic[] memory logics = new DataType.Logic[](2);
        logics[0] = _logicAgentERC20ApprovalToDSProxy(user2AgentDSProxy, DAI_TOKEN, wipeAmount);
        logics[1] = _logicWipe(gemCdp, wipeAmount);

        // Execute
        vm.prank(user2);
        router.execute(datas, logics, tokensReturnEmpty);

        (uint256 debtAfter, ) = _getCdpInfo(gemCdp);
        uint256 user2DaiBalanceAfter = IERC20(DAI_TOKEN).balanceOf(user2);

        assertEq(IERC20(DAI_TOKEN).balanceOf(address(router)), 0);
        assertEq(IERC20(DAI_TOKEN).balanceOf(address(user2Agent)), 0);
        assertEq(IERC20(DAI_TOKEN).balanceOf(address(user2AgentDSProxy)), 0);
        assertEq(user2DaiBalanceBefore - user2DaiBalanceAfter, wipeAmount);
        assertApproxEqRel(((debtBefore - debtAfter) / RAY), wipeAmount, 0.001e18);
    }

    function testWipeAll() external {
        // Setup
        uint256 wipeAmount = DRAW_DAI_AMOUNT + 100 ether;
        deal(DAI_TOKEN, user2, wipeAmount);
        uint256 user2DaiBalanceBefore = IERC20(DAI_TOKEN).balanceOf(user2);
        (uint256 debtBefore, ) = _getCdpInfo(gemCdp);

        // Encode permit2Datas
        bytes[] memory datas = new bytes[](1);
        datas[0] = dataERC20Permit2PullToken(IERC20(DAI_TOKEN), wipeAmount.toUint160());

        // Encode logic
        DataType.Logic[] memory logics = new DataType.Logic[](2);
        logics[0] = _logicAgentERC20ApprovalToDSProxy(user2AgentDSProxy, DAI_TOKEN, wipeAmount);
        logics[1] = _logicWipeAll(gemCdp);

        // Execute
        address[] memory tokensReturn = new address[](1);
        tokensReturn[0] = address(DAI_TOKEN);
        vm.prank(user2);
        router.execute(datas, logics, tokensReturn);

        (uint256 debtAfter, ) = _getCdpInfo(gemCdp);
        uint256 user2DaiBalanceAfter = IERC20(DAI_TOKEN).balanceOf(user2);

        assertEq(IERC20(DAI_TOKEN).balanceOf(address(router)), 0);
        assertEq(IERC20(DAI_TOKEN).balanceOf(address(user2Agent)), 0);
        assertEq(IERC20(DAI_TOKEN).balanceOf(address(user2AgentDSProxy)), 0);
        assertApproxEqRel(user2DaiBalanceBefore - user2DaiBalanceAfter, debtBefore / RAY, 0.001e18);
        assertEq(debtAfter, 0);
    }

    function testDraw() external {
        // Setup
        uint256 drawDaiAmount = 1000 ether;
        uint256 userDaiBalanceBefore = IERC20(DAI_TOKEN).balanceOf(user);

        // Encode logic
        DataType.Logic[] memory logics = new DataType.Logic[](1);
        logics[0] = _logicDraw(ethCdp, drawDaiAmount);

        // Execute
        address[] memory tokensReturn = new address[](1);
        tokensReturn[0] = address(DAI_TOKEN);
        vm.prank(user);
        router.execute(permit2DatasEmpty, logics, tokensReturn);

        uint256 userDaiBalanceAfter = IERC20(DAI_TOKEN).balanceOf(user);

        assertEq(userDaiBalanceAfter - userDaiBalanceBefore, drawDaiAmount);
        assertEq(IERC20(DAI_TOKEN).balanceOf(address(router)), 0);
        assertEq(IERC20(DAI_TOKEN).balanceOf(address(userAgent)), 0);
    }

    function _getCdpInfo(uint256 cdp) internal view returns (uint256, uint256) {
        address urn = IMakerManager(CDP_MANAGER).urns(cdp);
        bytes32 ilk = IMakerManager(CDP_MANAGER).ilks(cdp);
        (, uint256 rate, , , ) = IMakerVat(VAT).ilks(ilk);
        (uint256 ink, uint256 art) = IMakerVat(VAT).urns(ilk, urn);
        uint256 debt = art * rate;
        return (debt, ink);
    }

    function _logicBuildAgentDSProxy() internal view returns (DataType.Logic[] memory) {
        DataType.Logic[] memory logics = new DataType.Logic[](1);
        logics[0] = DataType.Logic(
            PROXY_REGISTRY,
            abi.encodeWithSelector(IDSProxyRegistry.build.selector),
            inputsEmpty,
            DataType.WrapMode.NONE,
            address(0),
            address(0) // callback
        );

        return logics;
    }

    function _logicAgentERC20ApprovalToDSProxy(
        address dsProxy,
        address token,
        uint256 amount
    ) internal view returns (DataType.Logic memory) {
        return
            DataType.Logic(
                token,
                abi.encodeWithSelector(IERC20.approve.selector, dsProxy, amount),
                inputsEmpty,
                DataType.WrapMode.NONE,
                address(0), // approveTo
                address(0) // callback
            );
    }

    function _logicLockETH(uint256 cdp, uint256 amount) internal view returns (DataType.Logic memory) {
        // Prepare data
        bytes memory data = abi.encodeWithSelector(
            IDSProxy.execute.selector,
            PROXY_ACTIONS,
            abi.encodeWithSelector(
                0xe205c108, // selector of "lockETH(address,address,uint256)"
                CDP_MANAGER,
                ETH_JOIN_A,
                cdp
            )
        );

        // Encode inputs
        DataType.Input[] memory inputs = new DataType.Input[](1);
        inputs[0].token = NATIVE;
        inputs[0].balanceBps = BPS_NOT_USED;
        inputs[0].amountOrOffset = amount;

        return
            DataType.Logic(
                user2AgentDSProxy,
                data,
                inputs,
                DataType.WrapMode.NONE,
                address(0), // approveTo
                address(0) // callback
            );
    }

    function _logicFreeETH(address dsProxy, uint256 cdp, uint256 amount) internal view returns (DataType.Logic memory) {
        // Prepare data
        bytes memory data = abi.encodeWithSelector(
            IDSProxy.execute.selector,
            PROXY_ACTIONS,
            abi.encodeWithSelector(
                0x7b5a3b43, // selector of "freeETH(address,address,uint256,uint256)"
                CDP_MANAGER,
                ETH_JOIN_A,
                cdp,
                amount
            )
        );

        return
            DataType.Logic(
                dsProxy,
                data,
                inputsEmpty,
                DataType.WrapMode.NONE,
                address(0), // approveTo
                address(0) // callback
            );
    }

    function _logicLockGem(uint256 cdp, uint256 amount) internal view returns (DataType.Logic memory) {
        // Prepare data
        bytes memory data = abi.encodeWithSelector(
            IDSProxy.execute.selector,
            PROXY_ACTIONS,
            abi.encodeWithSelector(
                0x3e29e565, // selector of "lockGem(address,address,uint256,uint256,bool)"
                CDP_MANAGER,
                GEM_JOIN_TOKEN,
                cdp,
                amount,
                true
            )
        );

        return
            DataType.Logic(
                user2AgentDSProxy,
                data,
                inputsEmpty,
                DataType.WrapMode.NONE,
                address(0), // approveTo
                address(0) // callback
            );
    }

    function _logicFreeGem(uint256 cdp, uint256 amount) internal view returns (DataType.Logic memory) {
        // Prepare datas
        bytes memory data = abi.encodeWithSelector(
            IDSProxy.execute.selector,
            PROXY_ACTIONS,
            abi.encodeWithSelector(
                0x6ab6a491, // selector of "freeGem(address,address,uint256,uint256)"
                CDP_MANAGER,
                GEM_JOIN_TOKEN,
                cdp,
                amount
            )
        );

        return
            DataType.Logic(
                userAgentDSProxy,
                data,
                inputsEmpty,
                DataType.WrapMode.NONE,
                address(0), // approveTo
                address(0) // callback
            );
    }

    function _logicWipe(uint256 cdp, uint256 amount) internal view returns (DataType.Logic memory) {
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

        return
            DataType.Logic(
                user2AgentDSProxy,
                data,
                inputsEmpty,
                DataType.WrapMode.NONE,
                address(0), // approveTo
                address(0) // callback
            );
    }

    function _logicWipeAll(uint256 cdp) internal view returns (DataType.Logic memory) {
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

        return
            DataType.Logic(
                user2AgentDSProxy,
                data,
                inputsEmpty,
                DataType.WrapMode.NONE,
                address(0), // approveTo
                address(0) // callback
            );
    }

    function _logicDraw(uint256 cdp, uint256 amount) internal view returns (DataType.Logic memory) {
        // Prepare datas
        bytes memory data = abi.encodeWithSelector(
            IDSProxy.execute.selector,
            PROXY_ACTIONS,
            abi.encodeWithSelector(
                0x9f6f3d5b, // selector of "draw(address,address,address,uint256,uint256)"
                CDP_MANAGER,
                JUG,
                DAI_JOIN,
                cdp,
                amount
            )
        );

        return
            DataType.Logic(
                userAgentDSProxy,
                data,
                inputsEmpty,
                DataType.WrapMode.NONE,
                address(0), // approveTo
                address(0) // callback
            );
    }
}
