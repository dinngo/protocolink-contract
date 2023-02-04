// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {SafeERC20, IERC20} from 'openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol';
import {IRouter} from './interfaces/IRouter.sol';
import {IDSProxy, IDSProxyRegistry} from './interfaces/maker/IDSProxy.sol';
import {IMakerManager, IMakerGemJoin} from './interfaces/maker/IMaker.sol';
import {ISpenderMakerAction} from './interfaces/ISpenderMakerAction.sol';
import {ApproveHelper} from './libraries/ApproveHelper.sol';

///@title Spender for Maker which user can interact with Maker
contract SpenderMakerAction is ISpenderMakerAction {
    using SafeERC20 for IERC20;

    address public constant NATIVE_TOKEN_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    address public immutable router;

    address public immutable proxyRegistry;
    address public immutable cdpManager;
    address public immutable proxyActions;
    address public immutable daiToken;
    address public immutable jug;

    // SpenderMaker's DSProxy
    IDSProxy public immutable dsProxy;

    modifier onlyRouter() {
        if (msg.sender != router) revert InvalidRouter();
        _;
    }

    ///@notice Check if user has permission to modify cdp
    modifier cdpAllowed(uint256 cdp) {
        address user = IRouter(router).user();
        address cdpOwner = IMakerManager(cdpManager).owns(cdp);
        if (
            IDSProxyRegistry(proxyRegistry).proxies(user) != cdpOwner &&
            IMakerManager(cdpManager).cdpCan(cdpOwner, cdp, user) != 1
        ) {
            revert UnauthorizedSender(cdp);
        }

        _;
    }

    constructor(
        address router_,
        address proxyRegistry_,
        address cdpManager_,
        address proxyActions_,
        address daiToken_,
        address jug_
    ) {
        router = router_;
        proxyRegistry = proxyRegistry_;
        cdpManager = cdpManager_;
        proxyActions = proxyActions_;
        daiToken = daiToken_;
        jug = jug_;

        dsProxy = IDSProxy(IDSProxyRegistry(proxyRegistry).build());
    }

    /// @notice Creates a cdp for the user(for a specific `ilk`), deposits `value` amount of ETH in `ethJoin`
    /// and exits `wad` amount of DAI token from `daiJoin` adapter.
    function openLockETHAndDraw(
        uint256 value,
        address ethJoin,
        address daiJoin,
        bytes32 ilk,
        uint256 wadD
    ) external payable onlyRouter returns (uint256 cdp) {
        bytes4 funcSig = 0xe685cc04; // selector of "openLockETHAndDraw(address,address,address,address,bytes32,uint256)"

        try
            dsProxy.execute{value: value}(
                proxyActions,
                abi.encodeWithSelector(funcSig, cdpManager, jug, ethJoin, daiJoin, ilk, wadD)
            )
        returns (bytes32 ret) {
            cdp = uint256(ret);
        } catch Error(string memory reason) {
            revert ActionFail(funcSig, reason);
        } catch {
            revert ActionFail(funcSig, '');
        }

        _transferTokenToRouter(daiToken);
        _transferCdp(cdp);
    }

    /// @notice Creates a cdp for the user(for a specific `ilk`), deposits `wadC` amount of collateral in `gemJoin`
    /// and exits `wadD` amount of DAI token from `daiJoin` adapter.
    function openLockGemAndDraw(
        address gemJoin,
        address daiJoin,
        bytes32 ilk,
        uint256 wadC,
        uint256 wadD
    ) external onlyRouter returns (uint256 cdp) {
        // Get collateral token
        address token = IMakerGemJoin(gemJoin).gem();
        bytes4 funcSig = 0xdb802a32; // selector of "openLockGemAndDraw(address,address,address,address,bytes32,uint256,uint256,bool)"

        ApproveHelper._approve(token, address(dsProxy), wadC);

        try
            dsProxy.execute(
                proxyActions,
                abi.encodeWithSelector(funcSig, cdpManager, jug, gemJoin, daiJoin, ilk, wadC, wadD, true)
            )
        returns (bytes32 ret) {
            cdp = uint256(ret);
        } catch Error(string memory reason) {
            revert ActionFail(funcSig, reason);
        } catch {
            revert ActionFail(funcSig, '');
        }

        ApproveHelper._approveZero(token, address(dsProxy));

        _transferTokenToRouter(daiToken);
        _transferCdp(cdp);
    }

    /// @notice Decrease locked value of `cdp` and withdraws `wad` amount of ETH from `ethJoin` adapter.
    function freeETH(address ethJoin, uint256 cdp, uint256 wad) external onlyRouter cdpAllowed(cdp) {
        bytes4 funcSig = 0x7b5a3b43; // selector of "freeETH(address,address,uint256,uint256)"

        try
            dsProxy.execute(proxyActions, abi.encodeWithSelector(0x7b5a3b43, cdpManager, ethJoin, cdp, wad))
        {} catch Error(string memory reason) {
            revert ActionFail(funcSig, reason);
        } catch {
            revert ActionFail(funcSig, '');
        }

        _transferTokenToRouter(NATIVE_TOKEN_ADDRESS);
    }

    /// @notice Decrease locked value of `cdp` and withdraws `wad` amount of collateral from `gemJoin` adapter.
    function freeGem(address gemJoin, uint256 cdp, uint256 wad) external onlyRouter cdpAllowed(cdp) {
        // Get collateral token
        address token = IMakerGemJoin(gemJoin).gem();
        bytes4 funcSig = 0x6ab6a491; // selector of "freeGem(address,address,uint256,uint256)"

        try
            dsProxy.execute(proxyActions, abi.encodeWithSelector(funcSig, cdpManager, gemJoin, cdp, wad))
        {} catch Error(string memory reason) {
            revert ActionFail(funcSig, reason);
        } catch {
            revert ActionFail(funcSig, '');
        }

        _transferTokenToRouter(token);
    }

    /// @notice Increase debt of `cdp` and exits `wad` amount of DAI token from `daiJoin` adapter.
    function draw(address daiJoin, uint256 cdp, uint256 wad) external onlyRouter cdpAllowed(cdp) {
        bytes4 funcSig = 0x9f6f3d5b; // selector of "draw(address,address,address,uint256,uint256)"

        try
            dsProxy.execute(proxyActions, abi.encodeWithSelector(funcSig, cdpManager, jug, daiJoin, cdp, wad))
        {} catch Error(string memory reason) {
            revert ActionFail(funcSig, reason);
        } catch {
            revert ActionFail(funcSig, '');
        }

        _transferTokenToRouter(daiToken);
    }

    /// @notice Get `user`'s DSProxy.
    function _getProxy(address user) internal view returns (address) {
        return IDSProxyRegistry(proxyRegistry).proxies(user);
    }

    function _transferCdp(uint256 cdp) internal {
        address user = IRouter(router).user();
        bytes4 funcSig = 0x493c2049; // selector of "giveToProxy(address,address,uint256,address)"

        try
            dsProxy.execute(proxyActions, abi.encodeWithSelector(funcSig, proxyRegistry, cdpManager, cdp, user))
        {} catch Error(string memory reason) {
            revert ActionFail(funcSig, reason);
        } catch {
            revert ActionFail(funcSig, '');
        }
    }

    function _transferTokenToRouter(address token) internal {
        if (token == NATIVE_TOKEN_ADDRESS) {
            uint256 balance = address(this).balance;
            (bool succ, ) = router.call{value: balance}('');
            require(succ, 'transfer ETH fail');
        } else {
            uint256 balance = IERC20(token).balanceOf(address(this));
            IERC20(token).safeTransfer(router, balance);
        }
    }
}