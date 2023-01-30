// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {SafeERC20, IERC20} from 'openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol';
import {IRouter} from './interfaces/IRouter.sol';
import {IDSProxy, IDSProxyRegistry} from './interfaces/maker/IDSProxy.sol';
import {IMakerManager, IMakerChainLog} from './interfaces/maker/IMaker.sol';
import {ISpenderMakerAction} from './interfaces/ISpenderMakerAction.sol';
import {Utils} from './libraries/utils.sol';

contract SpenderMakerAction is ISpenderMakerAction {
    using SafeERC20 for IERC20;

    IDSProxyRegistry public constant PROXY_REGISTRY = IDSProxyRegistry(0x4678f0a6958e4D2Bc4F1BAF7Bc52E8F3564f3fE4);
    IMakerManager public constant CDP_MANAGER = IMakerManager(0x5ef30b9986345249bc32d8928B7ee64DE9435E39);
    address public constant PROXY_ACTIONS = 0x82ecD135Dce65Fbc6DbdD0e4237E0AF93FFD5038;
    address public constant DAI_TOKEN = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address public constant CHAIN_LOG = 0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F;

    address public immutable router;

    modifier onlyRouter() {
        if (msg.sender != router) revert InvalidRouter();
        _;
    }

    modifier cdpAllowed(address user, uint256 cdp) {
        address owner = CDP_MANAGER.owns(cdp);
        require(
            PROXY_REGISTRY.proxies(user) == owner || CDP_MANAGER.cdpCan(owner, cdp, user) == 1,
            'Unauthorized sender of cdp'
        );
        _;
    }

    constructor(address router_) {
        router = router_;
        _createDSProxy();
    }

    function openLockETHAndDraw(
        uint256 value,
        address ethJoin,
        address daiJoin,
        bytes32 ilk,
        uint256 wadD
    ) external payable returns (uint256 cdp) {
        IDSProxy proxy = IDSProxy(_getProxy(address(this)));
        value = Utils._getBalance(address(0), value);
        bytes4 funcSig = 0xe685cc04; // selector of "openLockETHAndDraw(address,address,address,address,bytes32,uint256)"

        try
            proxy.execute{value: value}(
                PROXY_ACTIONS,
                abi.encodeWithSelector(funcSig, address(CDP_MANAGER), getMcdJug(), ethJoin, daiJoin, ilk, wadD)
            )
        returns (bytes32 ret) {
            cdp = uint256(ret);
        } catch Error(string memory reason) {
            revert ActionFail(funcSig, reason);
        } catch {
            revert ActionFail(funcSig, '');
        }

        _transferDAIToRouter();
        _transferCdp(cdp);
    }

    /*   function openLockETHAndDraw(
        uint256 value,
        address ethJoin,
        address daiJoin,
        bytes32 ilk,
        uint256 wadD
    ) external payable returns (uint256 cdp) {
        IDSProxy proxy = IDSProxy(_getProxy(address(this)));
        // if amount == type(uint256).max return balance of Proxy
        value = _getBalance(address(0), value);

        try
            proxy.execute{value: value}(
                getProxyActions(),
                abi.encodeWithSelector(
                    // selector of "openLockETHAndDraw(address,address,address,address,bytes32,uint256)"
                    0xe685cc04,
                    getCdpManager(),
                    getMcdJug(),
                    ethJoin,
                    daiJoin,
                    ilk,
                    wadD
                )
            )
        returns (bytes32 ret) {
            cdp = uint256(ret);
        } catch Error(string memory reason) {
            _revertMsg("openLockETHAndDraw", reason);
        } catch {
            _revertMsg("openLockETHAndDraw");
        }


        _transferDAIToRouter();
        _transferCdp();
    }

    function openLockGemAndDraw(
        address gemJoin,
        address daiJoin,
        bytes32 ilk,
        uint256 wadC,
        uint256 wadD
    ) external payable returns (uint256 cdp) {
        IDSProxy proxy = IDSProxy(_getProxy(address(this)));
        address token = IMakerGemJoin(gemJoin).gem();

        // if amount == type(uint256).max return balance of Proxy
        wadC = _getBalance(token, wadC);

        _tokenApprove(token, address(proxy), wadC);
        try
            proxy.execute(
                getProxyActions(),
                abi.encodeWithSelector(
                    // selector of "openLockGemAndDraw(address,address,address,address,bytes32,uint256,uint256,bool)"
                    0xdb802a32,
                    getCdpManager(),
                    getMcdJug(),
                    gemJoin,
                    daiJoin,
                    ilk,
                    wadC,
                    wadD,
                    true
                )
            )
        returns (bytes32 ret) {
            cdp = uint256(ret);
        } catch Error(string memory reason) {
            _revertMsg("openLockGemAndDraw", reason);
        } catch {
            _revertMsg("openLockGemAndDraw");
        }
        _tokenApproveZero(token, address(proxy));

        
    }
    function safeLockETH(
        uint256 value,
        address ethJoin,
        uint256 cdp
    ) external payable {
        
        IDSProxy proxy = IDSProxy(_getProxy(address(this)));
        address owner = _getProxy(_getSender());
        // if amount == type(uint256).max return balance of Proxy
        value = _getBalance(address(0), value);

        try
            proxy.execute{value: value}(
                getProxyActions(),
                abi.encodeWithSelector(
                    // selector of "safeLockETH(address,address,uint256,address)"
                    0xee284576,
                    getCdpManager(),
                    ethJoin,
                    cdp,
                    owner
                )
            )
        {} catch Error(string memory reason) {
            _revertMsg("safeLockETH", reason);
        } catch {
            _revertMsg("safeLockETH");
        }
    }

    function safeLockGem(
        address gemJoin,
        uint256 cdp,
        uint256 wad
    ) external payable {
        IDSProxy proxy = IDSProxy(_getProxy(address(this)));
        address owner = _getProxy(_getSender());
        address token = IMakerGemJoin(gemJoin).gem();
        // if amount == type(uint256).max return balance of Proxy
        wad = _getBalance(token, wad);
        _tokenApprove(token, address(proxy), wad);
        try
            proxy.execute(
                getProxyActions(),
                abi.encodeWithSelector(
                    // selector of "safeLockGem(address,address,uint256,uint256,bool,address)"
                    0xead64729,
                    getCdpManager(),
                    gemJoin,
                    cdp,
                    wad,
                    true,
                    owner
                )
            )
        {} catch Error(string memory reason) {
            _revertMsg("safeLockGem", reason);
        } catch {
            _revertMsg("safeLockGem");
        }
        _tokenApproveZero(token, address(proxy));
    }

    function freeETH(
        address ethJoin,
        uint256 cdp,
        uint256 wad
    ) external payable cdpAllowed(cdp) {
        // Check msg.sender authority
        IDSProxy proxy = IDSProxy(_getProxy(address(this)));
        try
            proxy.execute(
                getProxyActions(),
                abi.encodeWithSelector(
                    // selector of "freeETH(address,address,uint256,uint256)"
                    0x7b5a3b43,
                    getCdpManager(),
                    ethJoin,
                    cdp,
                    wad
                )
            )
        {} catch Error(string memory reason) {
            _revertMsg("freeETH", reason);
        } catch {
            _revertMsg("freeETH");
        }
    }

    function freeGem(
        address gemJoin,
        uint256 cdp,
        uint256 wad
    ) external payable cdpAllowed(cdp) {
        // Check msg.sender authority
        IDSProxy proxy = IDSProxy(_getProxy(address(this)));
        address token = IMakerGemJoin(gemJoin).gem();
        try
            proxy.execute(
                getProxyActions(),
                abi.encodeWithSelector(
                    // selector of "freeGem(address,address,uint256,uint256)"
                    0x6ab6a491,
                    getCdpManager(),
                    gemJoin,
                    cdp,
                    wad
                )
            )
        {} catch Error(string memory reason) {
            _revertMsg("freeGem", reason);
        } catch {
            _revertMsg("freeGem");
        }

        // Update post process
        _updateToken(token);
    }

    function draw(
        address daiJoin,
        uint256 cdp,
        uint256 wad
    ) external payable cdpAllowed(cdp) {
       
        _transferDAIToRouter();
    }

    function wipe(
        address daiJoin,
        uint256 cdp,
        uint256 wad
    ) external payable {
        
    }
   */

    function getMcdJug() public view returns (address) {
        return IMakerChainLog(CHAIN_LOG).getAddress('MCD_JUG');
    }

    function _getProxy(address user) internal view returns (address) {
        return IDSProxyRegistry(PROXY_REGISTRY).proxies(user);
    }

    function _createDSProxy() internal {
        IDSProxyRegistry(PROXY_REGISTRY).build();
    }

    function _transferCdp(uint256 cdp) internal {
        IDSProxy proxy = IDSProxy(_getProxy(address(this)));
        address user = IRouter(router).user();
        bytes4 funcSig = 0x493c2049; // selector of "giveToProxy(address,address,uint256,address)"
        try
            proxy.execute(
                address(PROXY_ACTIONS),
                abi.encodeWithSelector(funcSig, PROXY_REGISTRY, address(CDP_MANAGER), cdp, user)
            )
        {} catch Error(string memory reason) {
            revert ActionFail(funcSig, reason);
        } catch {
            revert ActionFail(funcSig, '');
        }
    }

    function _transferDAIToRouter() internal {
        uint256 balance = IERC20(DAI_TOKEN).balanceOf(address(this));
        IERC20(DAI_TOKEN).safeTransfer(router, balance);
    }
}
