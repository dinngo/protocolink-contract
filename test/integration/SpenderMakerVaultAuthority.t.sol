// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {SafeERC20, IERC20} from 'openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol';
import {SpenderMakerVaultAuthority, ISpenderMakerVaultAuthority} from '../../src/SpenderMakerVaultAuthority.sol';
import {Router, IRouter} from '../../src/Router.sol';
import {IDSProxy, IDSProxyRegistry} from '../../src/interfaces/maker/IDSProxy.sol';
import 'forge-std/console.sol';

interface IMakerVat {
    function ilks(bytes32) external view returns (uint, uint, uint, uint, uint);
}

contract SpenderMakerVaultAuthorityTest is Test {
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

    address public user;
    IRouter public router;
    ISpenderMakerVaultAuthority public spenderMaker;
    uint256 daiDrawAmount = 20000 ether;

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
        address userDSProxy = IDSProxyRegistry(PROXY_REGISTRY).build();

        // Open ETH Vault
        uint256 ethAmount = 100 ether;
        deal(user, ethAmount);
        IDSProxy(userDSProxy).execute{value: ethAmount}(
            PROXY_ACTIONS,
            abi.encodeWithSelector(
                0xe685cc04, // selector of "openLockETHAndDraw(address,address,address,address,bytes32,uint256)"
                CDP_MANAGER,
                JUG,
                ETH_JOIN_A,
                DAI_JOIN,
                bytes32(bytes(ETH_JOIN_NAME)),
                daiDrawAmount
            )
        );
        assertEq(IERC20(DAI_TOKEN).balanceOf(user), daiDrawAmount);

        // Open LINK Vault
        uint256 linkAmount = 500000 ether;
        deal(LINK_TOKEN, user, linkAmount);
        IERC20(LINK_TOKEN).approve(userDSProxy, linkAmount);
        IDSProxy(userDSProxy).execute(
            PROXY_ACTIONS,
            abi.encodeWithSelector(
                // selector of "openLockGemAndDraw(address,address,address,address,bytes32,uint256,uint256,bool)"
                0xdb802a32,
                CDP_MANAGER,
                JUG,
                GEM_JOIN_LINK_A,
                DAI_JOIN,
                bytes32(bytes(TOKEN_JOIN_NAME)),
                linkAmount,
                daiDrawAmount,
                true
            )
        );
        assertEq(IERC20(DAI_TOKEN).balanceOf(user), daiDrawAmount * 2);

        vm.stopPrank();

        // Label
        vm.label(address(router), 'Router');
        vm.label(address(spenderMaker), 'SpenderMaker');
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

    function testAAA() external {
        console.log('Succ!!!');
    }
}
