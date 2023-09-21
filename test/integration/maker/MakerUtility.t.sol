// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {IERC20} from 'lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol';
import {MakerUtility, IMakerUtility} from 'src/utilities/MakerUtility.sol';
import {Router, IRouter} from 'src/Router.sol';
import {IAgent} from 'src/interfaces/IAgent.sol';
import {DataType} from 'src/libraries/DataType.sol';
import {ERC20Permit2Utils} from 'test/utils/ERC20Permit2Utils.sol';
import {MakerCommonUtils, IMakerManager, IMakerVat, IDSProxyRegistry} from 'test/utils/MakerCommonUtils.sol';
import {SafeCast160} from 'lib/permit2/src/libraries/SafeCast160.sol';

contract MakerUtilityTest is Test, MakerCommonUtils, ERC20Permit2Utils {
    using SafeCast160 for uint256;

    uint256 public constant BPS_NOT_USED = 0;
    address public constant NATIVE = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    address public user;
    uint256 public userPrivateKey;
    address public userDSProxy;
    IRouter public router;
    IAgent public agent;
    IMakerUtility public makerUtility;
    address public makerUtilityDSProxy;

    // Empty arrays
    DataType.Input[] public inputsEmpty;
    bytes[] public permit2DatasEmpty;

    function setUp() external {
        vm.createSelectFork(vm.rpcUrl('ethereum'));

        (user, userPrivateKey) = makeAddrAndKey('User');
        router = new Router(makeAddr('WrappedNative'), permit2Addr, address(this));
        makerUtility = new MakerUtility(address(router), PROXY_REGISTRY, CDP_MANAGER, PROXY_ACTIONS, DAI_TOKEN, JUG);
        makerUtilityDSProxy = IDSProxyRegistry(PROXY_REGISTRY).proxies(address(makerUtility));

        // Setup
        vm.startPrank(user);
        userDSProxy = IDSProxyRegistry(PROXY_REGISTRY).build();
        agent = IAgent(router.newAgent());
        vm.stopPrank();

        // Setup permit2
        erc20Permit2UtilsSetUp(user, userPrivateKey, address(agent));
        permitToken(IERC20(GEM));

        // Label
        vm.label(address(userDSProxy), 'UserDSProxy');
        vm.label(address(router), 'Router');
        vm.label(address(agent), 'Agent');
        vm.label(address(makerUtility), 'MakerUtility');
        vm.label(address(makerUtilityDSProxy), 'MakerUtilityDSProxy');

        _makerCommonSetUp();
    }

    function testOpenLockETHAndDraw(uint256 ethLockAmount, uint256 daiDrawAmount) external {
        // Calculate minimum collateral amount of ETH and drawing random amount of DAI between minimum and maximum
        IMakerVat vat = IMakerVat(VAT);
        bytes32 ilkETH = bytes32(bytes(ETH_JOIN_NAME));
        (, uint256 rate, uint256 spot, , uint256 dust) = vat.ilks(ilkETH);
        (uint256 daiDrawMin, uint256 minCollateral) = _getDAIDrawMinAndMinCollateral(spot, dust, ETH_DECIMAL);

        ethLockAmount = bound(ethLockAmount, minCollateral, 1e22);
        deal(user, ethLockAmount);
        uint256 daiDrawMax = _getDAIDrawMaxAmount(ethLockAmount, daiDrawMin, spot, rate);
        daiDrawAmount = bound(daiDrawAmount, daiDrawMin, daiDrawMax);

        // Encode logic
        DataType.Logic[] memory logics = new DataType.Logic[](1);
        logics[0] = _logicOpenLockETHAndDraw(ethLockAmount, daiDrawAmount);

        // Get param before execute
        uint256 userDAIBalanceBefore = IERC20(DAI_TOKEN).balanceOf(user);
        uint256 userCdpCountBefore = IMakerManager(CDP_MANAGER).count(userDSProxy);

        // Execute
        address[] memory tokensReturn = new address[](1);
        tokensReturn[0] = address(DAI_TOKEN);
        vm.prank(user);
        router.execute{value: ethLockAmount}(permit2DatasEmpty, logics, tokensReturn);

        assertEq(IERC20(DAI_TOKEN).balanceOf(address(agent)), 0);
        assertEq(IERC20(DAI_TOKEN).balanceOf(address(makerUtility)), 0);
        assertEq(IERC20(DAI_TOKEN).balanceOf(address(makerUtilityDSProxy)), 0);
        assertEq(address(agent).balance, 0);
        assertEq(address(makerUtility).balance, 0);
        assertEq(address(makerUtilityDSProxy).balance, 0);
        assertEq(IERC20(DAI_TOKEN).balanceOf(user) - userDAIBalanceBefore, daiDrawAmount);
        assertEq(IMakerManager(CDP_MANAGER).count(userDSProxy) - userCdpCountBefore, 1); // cdp count should increase by 1
    }

    function testCannotOpenLockETHAndDrawByInvalidSender() external {
        vm.prank(user);
        vm.expectRevert(IMakerUtility.InvalidAgent.selector);
        makerUtility.openLockETHAndDraw(0, address(0), address(0), bytes32(''), 0);
    }

    function testOpenLockGemAndDraw(uint256 tokenLockAmount, uint256 daiDrawAmount) external {
        // Calculate minimum collateral amount of token and drawing random amount of DAI between minimum and maximum
        IMakerVat vat = IMakerVat(VAT);
        bytes32 ilkToken = bytes32(bytes(TOKEN_JOIN_NAME));
        (, uint256 rate, uint256 spot, , uint256 dust) = vat.ilks(ilkToken);
        (uint256 daiDrawMin, uint256 minCollateral) = _getDAIDrawMinAndMinCollateral(spot, dust, GEM_DECIMAL);
        tokenLockAmount = bound(tokenLockAmount, minCollateral, 20 * (10 ** GEM_DECIMAL));

        deal(GEM, user, tokenLockAmount);
        uint256 daiDrawMax = _getDAIDrawMaxAmount(tokenLockAmount, daiDrawMin, spot, rate);
        daiDrawAmount = bound(daiDrawAmount, daiDrawMin, daiDrawMax);

        // Encode permit2Datas
        bytes[] memory datas = new bytes[](1);
        datas[0] = dataERC20Permit2PullToken(IERC20(GEM), tokenLockAmount.toUint160());

        // Encode logic
        DataType.Logic[] memory logics = new DataType.Logic[](2);
        logics[0] = _logicTransferERC20ToMakerUtility(GEM, tokenLockAmount);
        logics[1] = _logicOpenLockGemAndDraw(tokenLockAmount, daiDrawAmount);

        // Get param before execute
        uint256 userDAIBalanceBefore = IERC20(DAI_TOKEN).balanceOf(user);
        uint256 userCdpCountBefore = IMakerManager(CDP_MANAGER).count(userDSProxy);

        // Execute
        address[] memory tokensReturn = new address[](1);
        tokensReturn[0] = address(DAI_TOKEN);
        vm.prank(user);
        router.execute(datas, logics, tokensReturn);

        assertEq(IERC20(DAI_TOKEN).balanceOf(address(agent)), 0);
        assertEq(IERC20(DAI_TOKEN).balanceOf(address(makerUtility)), 0);
        assertEq(IERC20(DAI_TOKEN).balanceOf(address(makerUtilityDSProxy)), 0);
        assertEq(IERC20(GEM).balanceOf(address(agent)), 0);
        assertEq(IERC20(GEM).balanceOf(address(makerUtility)), 0);
        assertEq(IERC20(GEM).balanceOf(address(makerUtilityDSProxy)), 0);
        assertEq(IERC20(DAI_TOKEN).balanceOf(user) - userDAIBalanceBefore, daiDrawAmount);
        assertEq(IMakerManager(CDP_MANAGER).count(userDSProxy) - userCdpCountBefore, 1); // cdp count should increase by 1
    }

    function testCannotOpenLockGemAndDrawByInvalidSender() external {
        vm.prank(user);
        vm.expectRevert(IMakerUtility.InvalidAgent.selector);
        makerUtility.openLockGemAndDraw(address(0), address(0), bytes32(''), 0, 0);
    }

    function _getDAIDrawMinAndMinCollateral(
        uint256 spot,
        uint256 dust,
        uint256 collateralDecimal
    ) internal pure returns (uint256, uint256) {
        uint256 daiDrawMin = dust / 1000000000 ether; // at least draw this much DAI
        uint256 minCollateral = dust / spot / (10 ** (18 - collateralDecimal));
        minCollateral = (minCollateral * 105) / 100; // 5% Buffer
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

    function _logicOpenLockETHAndDraw(uint256 value, uint256 amountOutMin) public view returns (DataType.Logic memory) {
        // Data for openLockETHAndDraw
        bytes memory data = abi.encodeWithSelector(
            IMakerUtility.openLockETHAndDraw.selector,
            value,
            ETH_JOIN_A,
            DAI_JOIN,
            bytes32(bytes(ETH_JOIN_NAME)),
            amountOutMin
        );

        // Encode inputs
        DataType.Input[] memory inputs = new DataType.Input[](1);
        inputs[0].token = NATIVE;
        inputs[0].balanceBps = BPS_NOT_USED;
        inputs[0].amountOrOffset = value;

        return
            DataType.Logic(
                address(makerUtility),
                data,
                inputs,
                DataType.WrapMode.NONE,
                address(0), // approveTo
                address(0) // callback
            );
    }

    function _logicTransferERC20ToMakerUtility(
        address token,
        uint256 amount
    ) internal view returns (DataType.Logic memory) {
        return
            DataType.Logic(
                token,
                abi.encodeWithSelector(IERC20.transfer.selector, makerUtility, amount),
                inputsEmpty,
                DataType.WrapMode.NONE,
                address(0), // approveTo
                address(0) // callback
            );
    }

    function _logicOpenLockGemAndDraw(uint256 value, uint256 amountOutMin) public view returns (DataType.Logic memory) {
        bytes memory data = abi.encodeWithSelector(
            IMakerUtility.openLockGemAndDraw.selector,
            GEM_JOIN_TOKEN,
            DAI_JOIN,
            bytes32(bytes(TOKEN_JOIN_NAME)),
            value,
            amountOutMin
        );

        return
            DataType.Logic(
                address(makerUtility),
                data,
                inputsEmpty,
                DataType.WrapMode.NONE,
                address(0), // approveTo
                address(0) // callback
            );
    }
}
