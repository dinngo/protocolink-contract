// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {SafeERC20, IERC20} from 'openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol';
import {UtilityMaker, IUtilityMaker} from '../../src/utility/UtilityMaker.sol';
import {Router, IRouter} from '../../src/Router.sol';
import {IDSProxy, IDSProxyRegistry} from '../../src/interfaces/maker/IDSProxy.sol';
import {SpenderERC20Approval, ISpenderERC20Approval} from '../../src/SpenderERC20Approval.sol';
import 'forge-std/console.sol';

interface IMakerVat {
    function ilks(bytes32) external view returns (uint256 art, uint256 rate, uint256 spot, uint256 line, uint256 dust);
}

contract UtilityMakerTest is Test {
    using SafeERC20 for IERC20;

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
    uint256 public constant BPS_BASE = 10_000;

    address public user;
    IRouter public router;
    IUtilityMaker public utilityMaker;
    ISpenderERC20Approval public spenderERC20;

    // Empty arrays
    address[] tokensReturnEmpty;
    IRouter.Input[] inputsEmpty;
    IRouter.Output[] outputsEmpty;

    function setUp() external {
        user = makeAddr('User');

        router = new Router();
        utilityMaker = new UtilityMaker(address(router), PROXY_REGISTRY, CDP_MANAGER, PROXY_ACTIONS, DAI_TOKEN, JUG);
        spenderERC20 = new SpenderERC20Approval(address(router));

        vm.prank(user);
        IERC20(GEM).approve(address(spenderERC20), type(uint256).max);

        // Label
        vm.label(address(router), 'Router');
        vm.label(address(utilityMaker), 'UtilityMaker');
        vm.label(address(spenderERC20), 'SpenderERC20');
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
        bytes32 ilkETH = bytes32(bytes(ETH_JOIN_NAME));
        console.log('ilkETH:');
        console.logBytes32(ilkETH);

        IMakerVat vat = IMakerVat(VAT);
        (, uint256 rate, uint256 spot, , uint256 dust) = vat.ilks(ilkETH);
        (uint256 daiDrawMin, uint256 minCollateral) = _getDAIDrawMinAndMinCollateral(spot, dust);

        ethLockAmount = bound(ethLockAmount, minCollateral, 1e22);
        uint256 daiDrawMax = _getDAIDrawMaxAmount(ethLockAmount, daiDrawMin, spot, rate);
        daiDrawAmount = bound(daiDrawAmount, daiDrawMin, daiDrawMax);

        // Encode logic
        IRouter.Logic[] memory logics = new IRouter.Logic[](2);
        deal(user, ethLockAmount);
        logics = _logicOpenLockETHAndDraw(ethLockAmount, daiDrawAmount);

        // Execute
        address[] memory tokensReturn = new address[](1);
        tokensReturn[0] = address(DAI_TOKEN);
        vm.prank(user);
        router.execute{value: ethLockAmount}(logics, tokensReturn);

        console.log('Succ!!!');
    }

    function testOpenLockGemAndDraw(uint256 tokenLockAmount, uint256 daiDrawAmount) external {
        // Calculate minimum collateral amount of token and drawing random amount of DAI between minimum and maximum
        bytes32 ilkToken = bytes32(bytes(TOKEN_JOIN_NAME));
        console.log('ilkToken:');
        console.logBytes32(ilkToken);

        IMakerVat vat = IMakerVat(VAT);
        (, uint256 rate, uint256 spot, , uint256 dust) = vat.ilks(ilkToken);
        (uint256 daiDrawMin, uint256 minCollateral) = _getDAIDrawMinAndMinCollateral(spot, dust);

        tokenLockAmount = bound(tokenLockAmount, minCollateral, 1e23);
        uint256 daiDrawMax = _getDAIDrawMaxAmount(tokenLockAmount, daiDrawMin, spot, rate);
        daiDrawAmount = bound(daiDrawAmount, daiDrawMin, daiDrawMax);

        // Encode logic
        IRouter.Logic[] memory logics = new IRouter.Logic[](2);
        deal(GEM, user, tokenLockAmount);
        logics = _logicOpenLockGemAndDraw(GEM, tokenLockAmount, daiDrawAmount);

        // Execute
        address[] memory tokensReturn = new address[](1);
        tokensReturn[0] = address(DAI_TOKEN);
        vm.prank(user);
        router.execute(logics, tokensReturn);

        console.log('Succ!!!');
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

    function _logicOpenLockETHAndDraw(
        uint256 value,
        uint256 amountOutMin
    ) public view returns (IRouter.Logic[] memory) {
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
        IRouter.Input[] memory inputs = new IRouter.Input[](1);
        inputs[0].token = NATIVE;
        inputs[0].amountBps = type(uint256).max;
        inputs[0].amountOrOffset = value;

        // Encode outputs
        IRouter.Output[] memory outputs = new IRouter.Output[](1);
        outputs[0].token = DAI_TOKEN;
        outputs[0].amountMin = amountOutMin;

        IRouter.Logic[] memory logics = new IRouter.Logic[](1);
        logics[0] = IRouter.Logic(
            address(utilityMaker),
            data,
            inputs,
            outputs,
            address(0), // approveTo,
            address(0) // callback
        );

        return logics;
    }

    function _logicOpenLockGemAndDraw(
        address collateral,
        uint256 value,
        uint256 amountOutMin
    ) public view returns (IRouter.Logic[] memory) {
        // Step 0: pull collateral to router from SpenderERC20
        // Step 1: transfer token to UtilityMaker
        // Step 2: call openLockGemAndDraw on UtilityMaker

        // Prepare datas
        bytes memory data0 = abi.encodeWithSelector(ISpenderERC20Approval.pullToken.selector, collateral, value);
        bytes memory data1 = abi.encodeWithSelector(IERC20.transfer.selector, utilityMaker, value);
        bytes memory data2 = abi.encodeWithSelector(
            IUtilityMaker.openLockGemAndDraw.selector,
            GEM_JOIN_LINK_A,
            DAI_JOIN,
            bytes32(bytes(TOKEN_JOIN_NAME)),
            value,
            amountOutMin
        );

        // Encode inputs
        // IRouter.Input[] memory inputs = new IRouter.Input[](3);
        // inputs[2].token = collateral;
        // inputs[2].amountBps = type(uint256).max;
        // inputs[2].amountOrOffset = value;

        // Encode outputs
        IRouter.Output[] memory outputs = new IRouter.Output[](1);
        outputs[0].token = DAI_TOKEN;
        outputs[0].amountMin = amountOutMin;

        IRouter.Logic[] memory logics = new IRouter.Logic[](3);
        logics[0] = IRouter.Logic(
            address(spenderERC20),
            data0,
            inputsEmpty,
            outputsEmpty,
            address(0), // approveTo,
            address(0) // callback
        );

        logics[1] = IRouter.Logic(
            collateral,
            data1,
            inputsEmpty,
            outputsEmpty,
            address(0), // approveTo,
            address(0) // callback
        );

        logics[2] = IRouter.Logic(
            address(utilityMaker),
            data2,
            inputsEmpty,
            outputs,
            address(0), // approveTo,
            address(0) // callback
        );

        return logics;
    }
}
