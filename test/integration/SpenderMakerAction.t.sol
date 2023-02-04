// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {SafeERC20, IERC20} from 'openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol';
import {SpenderMakerAction, ISpenderMakerAction} from '../../src/SpenderMakerAction.sol';
import {Router, IRouter} from '../../src/Router.sol';
import {IDSProxy, IDSProxyRegistry} from '../../src/interfaces/maker/IDSProxy.sol';
import 'forge-std/console.sol';

interface IMakerVat {
    function ilks(bytes32) external view returns (uint, uint, uint, uint, uint);
}

contract SpenderMakerActionTest is Test {
    using SafeERC20 for IERC20;

    address public constant NATIVE = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    // MCD contract address
    address public constant PROXY_REGISTRY = 0x4678f0a6958e4D2Bc4F1BAF7Bc52E8F3564f3fE4;
    address public constant CDP_MANAGER = 0x5ef30b9986345249bc32d8928B7ee64DE9435E39;
    address public constant VAT = 0x35D1b3F3D7966A1DFe207aa4514C12a259A0492B;
    address public constant PROXY_ACTIONS = 0x82ecD135Dce65Fbc6DbdD0e4237E0AF93FFD5038;
    address public constant JUG = 0x19c0976f590D67707E62397C87829d896Dc0f1F1;
    address public constant ETH_JOIN = 0x2F0b23f53734252Bda2277357e97e1517d6B042A;
    address public constant DAI_JOIN = 0x9759A6Ac90977b93B58547b4A71c78317f391A28;

    address public constant DAI_TOKEN = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    string public constant ETH_JOIN_NAME = 'ETH-A';
    uint256 public constant BPS_BASE = 10_000;

    address public user;
    IRouter public router;
    ISpenderMakerAction public spenderMaker;

    // Empty arrays
    address[] tokensReturnEmpty;
    IRouter.Input[] inputsEmpty;
    IRouter.Output[] outputsEmpty;

    function setUp() external {
        user = makeAddr('User');

        router = new Router();
        spenderMaker = new SpenderMakerAction(
            address(router),
            PROXY_REGISTRY,
            CDP_MANAGER,
            PROXY_ACTIONS,
            DAI_TOKEN,
            JUG
        );

        // Label
        vm.label(address(router), 'Router');
        vm.label(address(spenderMaker), 'SpenderMakerAction');

        vm.label(PROXY_REGISTRY, 'PROXY_REGISTRY');
        vm.label(CDP_MANAGER, 'CDP_MANAGER');
        vm.label(VAT, 'VAT');
        vm.label(PROXY_ACTIONS, 'PROXY_ACTIONS');
        vm.label(DAI_TOKEN, 'DAI_TOKEN');
        vm.label(JUG, 'JUG');
        vm.label(ETH_JOIN, 'ETH_JOIN');
        vm.label(DAI_JOIN, 'DAI_JOIN');
    }

    function testAAA() external {
        console.log('Succ!!!');
    }

    function testOpenLockETHAndDraw(uint256 ethLockAmount, uint256 daiDrawAmount) external {
        console.log('init router balance:', address(router).balance);

        // Calculate minimum collateral amount of ETH and drawing minimum and maximum amount of DAI
        bytes32 ilkETH = bytes32(bytes(ETH_JOIN_NAME));
        IMakerVat vat = IMakerVat(VAT);
        (uint256 art, uint256 rate, uint256 spot, uint256 line, uint256 dust) = vat.ilks(ilkETH);
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

    function _getDAIDrawMinAndMinCollateral(uint256 spot, uint256 dust) internal returns (uint256, uint256) {
        uint256 daiDrawMin = dust / 1000000000 ether; // at least draw this much DAI
        uint256 minCollateral = (((daiDrawMin * 1000000000 ether) / spot) * 105) / 100;
        return (daiDrawMin, minCollateral);
    }

    function _getDAIDrawMaxAmount(
        uint256 ilkAmount,
        uint256 daiDrawMin,
        uint256 spot,
        uint256 rate
    ) internal returns (uint256) {
        uint256 daiDrawMax = (ilkAmount * spot) / rate;
        return daiDrawMax > daiDrawMin ? daiDrawMax : daiDrawMin;
    }

    function _logicOpenLockETHAndDraw(
        uint256 value,
        uint256 amountOutMin
    ) public view returns (IRouter.Logic[] memory) {
        // Step 0: transfer ETH to SpenderMaker
        // Step 1: call OpenLockETHAndDraw in SpenderMaker

        // Encode data
        bytes memory data0; // 0x
        bytes memory data1 = abi.encodeWithSelector(
            ISpenderMakerAction.openLockETHAndDraw.selector,
            value,
            ETH_JOIN,
            DAI_JOIN,
            bytes32(bytes(ETH_JOIN_NAME)),
            amountOutMin
        );

        // Encode inputs for step1
        IRouter.Input[] memory inputs1 = new IRouter.Input[](1);
        inputs1[0].token = NATIVE;
        inputs1[0].amountBps = BPS_BASE;
        inputs1[0].amountOffset = type(uint256).max;
        inputs1[0].doApprove = false;

        // Encode outputs for step1
        IRouter.Output[] memory outputs1 = new IRouter.Output[](1);
        outputs1[0].token = DAI_TOKEN;
        outputs1[0].amountMin = amountOutMin;

        IRouter.Logic[] memory logics = new IRouter.Logic[](2);

        logics[0] = IRouter.Logic(
            address(spenderMaker),
            data0,
            new IRouter.Input[](0),
            new IRouter.Output[](0),
            address(0)
        );
        logics[1] = IRouter.Logic(address(spenderMaker), data1, inputs1, outputs1, address(0));

        return logics;
    }
}
