// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {IDSProxy} from 'src/interfaces/maker/IDSProxy.sol';

contract MakerCommonUtils is Test {
    address public constant WBTC_TOKEN = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;

    // MCD contract address
    address public constant PROXY_REGISTRY = 0x4678f0a6958e4D2Bc4F1BAF7Bc52E8F3564f3fE4;
    address public constant CDP_MANAGER = 0x5ef30b9986345249bc32d8928B7ee64DE9435E39;
    address public constant VAT = 0x35D1b3F3D7966A1DFe207aa4514C12a259A0492B;
    address public constant PROXY_ACTIONS = 0x82ecD135Dce65Fbc6DbdD0e4237E0AF93FFD5038;
    address public constant JUG = 0x19c0976f590D67707E62397C87829d896Dc0f1F1;
    address public constant ETH_JOIN_A = 0x2F0b23f53734252Bda2277357e97e1517d6B042A;
    address public constant DAI_JOIN = 0x9759A6Ac90977b93B58547b4A71c78317f391A28;
    address public constant GEM_JOIN_WBTC_C = 0x7f62f9592b823331E012D3c5DdF2A7714CfB9de2;
    address public constant DAI_TOKEN = 0x6B175474E89094C44Da98b954EedeAC495271d0F;

    address public constant GEM = WBTC_TOKEN;
    uint256 public constant GEM_DECIMAL = 8;
    uint256 public constant ETH_DECIMAL = 18;
    string public constant ETH_JOIN_NAME = 'ETH-A';
    string public constant TOKEN_JOIN_NAME = 'WBTC-C';
    address public constant GEM_JOIN_TOKEN = GEM_JOIN_WBTC_C;

    function _makerCommonSetUp() internal {
        // Label
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

    function _allowCdp(address cdpOwner, address dsProxy, uint256 cdp, address usr) internal {
        vm.prank(cdpOwner);
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
}

interface IMakerManager {
    function cdpCan(address, uint, address) external view returns (uint);

    function ilks(uint) external view returns (bytes32);

    function owns(uint) external view returns (address);

    function urns(uint) external view returns (address);

    function count(address) external view returns (uint256);
}

interface IMakerVat {
    function ilks(bytes32) external view returns (uint, uint, uint, uint, uint);

    function urns(bytes32, address) external view returns (uint, uint);
}

interface IDSProxyRegistry {
    function proxies(address input) external view returns (address);

    function build() external returns (address);
}
