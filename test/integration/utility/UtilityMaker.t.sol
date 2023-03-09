// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {IERC20} from 'openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol';
import {UtilityMaker, IUtilityMaker} from '../../../src/utility/UtilityMaker.sol';
import {Router, IRouter} from '../../../src/Router.sol';
import {IAgent} from '../../../src/interfaces/IAgent.sol';
import {IParam} from '../../../src/interfaces/IParam.sol';
import {IDSProxy, IDSProxyRegistry} from '../../../src/interfaces/maker/IDSProxy.sol';
import {IMakerManager} from '../../../src/interfaces/maker/IMaker.sol';
import {SpenderPermitUtils} from '../../utils/SpenderPermitUtils.sol';
import {SafeCast160} from 'permit2/libraries/SafeCast160.sol';

interface IMakerVat {
    function ilks(bytes32) external view returns (uint256 art, uint256 rate, uint256 spot, uint256 line, uint256 dust);
}

contract UtilityMakerTest is Test, SpenderPermitUtils {
    using SafeCast160 for uint256;

    uint256 public constant SKIP = type(uint256).max;
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

    address public user;
    uint256 public userPrivateKey;
    address public userDSProxy;
    IRouter public router;
    IAgent public agent;
    IUtilityMaker public utilityMaker;
    address public utilityMakerDSProxy;

    // Empty arrays
    address[] tokensReturnEmpty;
    IParam.Input[] inputsEmpty;

    function setUp() external {
        (user, userPrivateKey) = makeAddrAndKey('User');
        router = new Router();
        utilityMaker = new UtilityMaker(address(router), PROXY_REGISTRY, CDP_MANAGER, PROXY_ACTIONS, DAI_TOKEN, JUG);
        utilityMakerDSProxy = IDSProxyRegistry(PROXY_REGISTRY).proxies(address(utilityMaker));

        // Setup
        vm.startPrank(user);
        userDSProxy = IDSProxyRegistry(PROXY_REGISTRY).build();
        agent = IAgent(router.newAgent());
        vm.stopPrank();

        // Setup permit2
        spenderSetUp(user, userPrivateKey, router);
        permitToken(IERC20(GEM));

        // Label
        vm.label(address(userDSProxy), 'UserDSProxy');
        vm.label(address(router), 'Router');
        vm.label(address(agent), 'Agent');
        vm.label(address(utilityMaker), 'UtilityMaker');
        vm.label(address(utilityMakerDSProxy), 'UtilityMakerDSProxy');
        vm.label(address(spender), 'SpenderPermit2ERC20');
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

    function testOpenLockETHAndDraw(uint256 ethLockAmount, uint256 daiDrawAmount) external {
        // Calculate minimum collateral amount of ETH and drawing random amount of DAI between minimum and maximum
        IMakerVat vat = IMakerVat(VAT);
        bytes32 ilkETH = bytes32(bytes(ETH_JOIN_NAME));
        (, uint256 rate, uint256 spot, , uint256 dust) = vat.ilks(ilkETH);
        (uint256 daiDrawMin, uint256 minCollateral) = _getDAIDrawMinAndMinCollateral(spot, dust);

        ethLockAmount = bound(ethLockAmount, minCollateral, 1e22);
        deal(user, ethLockAmount);
        uint256 daiDrawMax = _getDAIDrawMaxAmount(ethLockAmount, daiDrawMin, spot, rate);
        daiDrawAmount = bound(daiDrawAmount, daiDrawMin, daiDrawMax);

        // Encode logic
        IParam.Logic[] memory logics = new IParam.Logic[](1);
        logics[0] = _logicOpenLockETHAndDraw(ethLockAmount, daiDrawAmount);

        // Get param before execute
        uint256 userDAIBalanceBefore = IERC20(DAI_TOKEN).balanceOf(user);
        uint256 userCdpCountBefore = IMakerManager(CDP_MANAGER).count(userDSProxy);

        // Execute
        address[] memory tokensReturn = new address[](1);
        tokensReturn[0] = address(DAI_TOKEN);
        vm.prank(user);
        router.execute{value: ethLockAmount}(logics, tokensReturn);

        assertEq(IERC20(DAI_TOKEN).balanceOf(address(agent)), 0);
        assertEq(IERC20(DAI_TOKEN).balanceOf(address(utilityMaker)), 0);
        assertEq(IERC20(DAI_TOKEN).balanceOf(address(utilityMakerDSProxy)), 0);
        assertEq(address(agent).balance, 0);
        assertEq(address(utilityMaker).balance, 0);
        assertEq(address(utilityMakerDSProxy).balance, 0);
        assertEq(IERC20(DAI_TOKEN).balanceOf(user) - userDAIBalanceBefore, daiDrawAmount);
        assertEq(IMakerManager(CDP_MANAGER).count(userDSProxy) - userCdpCountBefore, 1); // cdp count should increase by 1
    }

    function testOpenLockGemAndDraw(uint256 tokenLockAmount, uint256 daiDrawAmount) external {
        // Calculate minimum collateral amount of token and drawing random amount of DAI between minimum and maximum
        IMakerVat vat = IMakerVat(VAT);
        bytes32 ilkToken = bytes32(bytes(TOKEN_JOIN_NAME));
        (, uint256 rate, uint256 spot, , uint256 dust) = vat.ilks(ilkToken);
        (uint256 daiDrawMin, uint256 minCollateral) = _getDAIDrawMinAndMinCollateral(spot, dust);

        tokenLockAmount = bound(tokenLockAmount, minCollateral, 1e23);
        deal(GEM, user, tokenLockAmount);
        uint256 daiDrawMax = _getDAIDrawMaxAmount(tokenLockAmount, daiDrawMin, spot, rate);
        daiDrawAmount = bound(daiDrawAmount, daiDrawMin, daiDrawMax);

        // Encode logic
        IParam.Logic[] memory logics = new IParam.Logic[](3);
        logics[0] = logicSpenderPermit2ERC20PullToken(IERC20(GEM), tokenLockAmount.toUint160());
        logics[1] = _logicTransferERC20ToUtilityMaker(GEM, tokenLockAmount);
        logics[2] = _logicOpenLockGemAndDraw(tokenLockAmount, daiDrawAmount);

        // Get param before execute
        uint256 userDAIBalanceBefore = IERC20(DAI_TOKEN).balanceOf(user);
        uint256 userCdpCountBefore = IMakerManager(CDP_MANAGER).count(userDSProxy);

        // Execute
        address[] memory tokensReturn = new address[](1);
        tokensReturn[0] = address(DAI_TOKEN);
        vm.prank(user);
        router.execute(logics, tokensReturn);

        assertEq(IERC20(DAI_TOKEN).balanceOf(address(agent)), 0);
        assertEq(IERC20(DAI_TOKEN).balanceOf(address(utilityMaker)), 0);
        assertEq(IERC20(DAI_TOKEN).balanceOf(address(utilityMakerDSProxy)), 0);
        assertEq(IERC20(GEM).balanceOf(address(agent)), 0);
        assertEq(IERC20(GEM).balanceOf(address(utilityMaker)), 0);
        assertEq(IERC20(GEM).balanceOf(address(utilityMakerDSProxy)), 0);
        assertEq(IERC20(DAI_TOKEN).balanceOf(user) - userDAIBalanceBefore, daiDrawAmount);
        assertEq(IMakerManager(CDP_MANAGER).count(userDSProxy) - userCdpCountBefore, 1); // cdp count should increase by 1
    }

    function _getDAIDrawMinAndMinCollateral(uint256 spot, uint256 dust) internal pure returns (uint256, uint256) {
        uint256 daiDrawMin = dust / 1000000000 ether; // at least draw this much DAI
        uint256 minCollateral = (((daiDrawMin * 1000000000 ether) / spot) * 105) / 100;
        return (daiDrawMin, minCollateral);
    }

    function _getDAIDrawMaxAmount(
        uint256 ilkAmount,
        uint256 daiDrawMin,
        uint256 spot,
        uint256 rate
    ) internal pure returns (uint256) {
        uint256 daiDrawMax = (ilkAmount * spot) / rate;
        return daiDrawMax > daiDrawMin ? daiDrawMax : daiDrawMin;
    }

    function _logicOpenLockETHAndDraw(uint256 value, uint256 amountOutMin) public view returns (IParam.Logic memory) {
        // Data for openLockETHAndDraw
        bytes memory data = abi.encodeWithSelector(
            IUtilityMaker.openLockETHAndDraw.selector,
            value,
            ETH_JOIN_A,
            DAI_JOIN,
            bytes32(bytes(ETH_JOIN_NAME)),
            amountOutMin
        );

        // Encode inputs
        IParam.Input[] memory inputs = new IParam.Input[](1);
        inputs[0].token = NATIVE;
        inputs[0].amountBps = SKIP;
        inputs[0].amountOrOffset = value;

        return
            IParam.Logic(
                address(utilityMaker),
                data,
                inputs,
                address(0) // callback
            );
    }

    function _logicTransferERC20ToUtilityMaker(
        address token,
        uint256 amount
    ) internal view returns (IParam.Logic memory) {
        return
            IParam.Logic(
                token,
                abi.encodeWithSelector(IERC20.transfer.selector, utilityMaker, amount),
                inputsEmpty,
                address(0) // callback
            );
    }

    function _logicOpenLockGemAndDraw(uint256 value, uint256 amountOutMin) public view returns (IParam.Logic memory) {
        bytes memory data = abi.encodeWithSelector(
            IUtilityMaker.openLockGemAndDraw.selector,
            GEM_JOIN_LINK_A,
            DAI_JOIN,
            bytes32(bytes(TOKEN_JOIN_NAME)),
            value,
            amountOutMin
        );

        return
            IParam.Logic(
                address(utilityMaker),
                data,
                inputsEmpty,
                address(0) // callback
            );
    }
}
