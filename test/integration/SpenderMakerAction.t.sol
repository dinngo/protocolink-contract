// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {SafeERC20, IERC20} from 'openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol';
import {SpenderMakerAction, ISpenderMakerAction} from '../../src/SpenderMakerAction.sol';
import {Router, IRouter} from '../../src/Router.sol';
import {IDSProxy, IDSProxyRegistry} from '../../src/interfaces/maker/IDSProxy.sol';
import 'forge-std/console.sol';

contract SpenderMakerActionTest is Test {
    using SafeERC20 for IERC20;

    address public constant NATIVE = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    // MCD contract address
    address public constant PROXY_REGISTRY = 0x4678f0a6958e4D2Bc4F1BAF7Bc52E8F3564f3fE4;
    address public constant CDP_MANAGER = 0x5ef30b9986345249bc32d8928B7ee64DE9435E39;
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
        vm.label(PROXY_ACTIONS, 'PROXY_ACTIONS');
        vm.label(DAI_TOKEN, 'DAI_TOKEN');
        vm.label(JUG, 'JUG');
        vm.label(ETH_JOIN, 'ETH_JOIN');
        vm.label(DAI_JOIN, 'DAI_JOIN');
    }

    function testAAA() external {
        console.log('Succ!!!');
    }

    function testOpenLockETHAndDraw(uint256 amountIn) external {
        // TODO: modify range
        amountIn = bound(amountIn, 1e12, 1e22);
        deal(user, amountIn);

        uint256 amountOutMin = 1;

        // Encode logic
        IRouter.Logic[] memory logics = new IRouter.Logic[](1);
        logics[0] = _logicOpenLockETHAndDraw(amountIn, amountOutMin);

        // Execute
        address[] memory tokensReturn = new address[](1);
        tokensReturn[0] = address(DAI_TOKEN);
        vm.prank(user);
        router.execute{value: amountIn}(logics, tokensReturn);

        console.log('Succ!!!');
    }

    function _logicOpenLockETHAndDraw(uint256 value, uint256 amountOutMin) public view returns (IRouter.Logic memory) {
        // Encode data
        bytes memory data = abi.encodeWithSelector(
            ISpenderMakerAction.openLockETHAndDraw.selector,
            value,
            ETH_JOIN,
            DAI_JOIN,
            bytes32(keccak256(bytes(ETH_JOIN_NAME))),
            amountOutMin
        );

        // Encode inputs
        IRouter.Input[] memory inputs = new IRouter.Input[](1);
        inputs[0].token = NATIVE;
        inputs[0].amountBps = BPS_BASE;
        inputs[0].amountOffset = type(uint256).max;
        inputs[0].doApprove = false;

        // Encode outputs
        IRouter.Output[] memory outputs = new IRouter.Output[](1);
        outputs[0].token = DAI_TOKEN;
        outputs[0].amountMin = amountOutMin;

        return IRouter.Logic(address(spenderMaker), data, inputs, outputs, address(0));
    }
}
