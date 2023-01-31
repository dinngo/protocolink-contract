// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {SafeERC20, IERC20} from 'openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol';
import {IRouter} from './interfaces/IRouter.sol';
import {IDSProxy, IDSProxyRegistry} from './interfaces/maker/IDSProxy.sol';
import {IMakerManager, IMakerGemJoin, IMakerChainLog} from './interfaces/maker/IMaker.sol';
import {ISpenderMakerAction} from './interfaces/ISpenderMakerAction.sol';
import {Utils} from './libraries/utils.sol';
import {ApproveHelper} from './libraries/ApproveHelper.sol';

///@title Spender for Maker which user can interact with Maker
contract SpenderMakerAction is ISpenderMakerAction {
    using SafeERC20 for IERC20;

    address public constant NATIVE_TOKEN_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
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

    ///@notice Check if user has permission to modify cdp
    modifier cdpAllowed(uint256 cdp) {
        address user = IRouter(router).user();
        address cdpOwner = CDP_MANAGER.owns(cdp);
        require(
            PROXY_REGISTRY.proxies(user) == cdpOwner || CDP_MANAGER.cdpCan(cdpOwner, cdp, user) == 1,
            'Unauthorized sender of cdp'
        );
        _;
    }

    constructor(address router_) {
        router = router_;
        _createDSProxy();
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
        // Get spender DSProxy
        IDSProxy dsProxy = IDSProxy(_getProxy(address(this)));
        value = Utils._getBalance(NATIVE_TOKEN_ADDRESS, value);
        bytes4 funcSig = 0xe685cc04; // selector of "openLockETHAndDraw(address,address,address,address,bytes32,uint256)"

        try
            dsProxy.execute{value: value}(
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

        _transferTokenToRouter(DAI_TOKEN);
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
    ) external payable onlyRouter returns (uint256 cdp) {
        // Get spender DSProxy
        IDSProxy dsProxy = IDSProxy(_getProxy(address(this)));

        // Get collateral token
        address token = IMakerGemJoin(gemJoin).gem();
        wadC = Utils._getBalance(token, wadC);
        bytes4 funcSig = 0xdb802a32; // selector of "openLockGemAndDraw(address,address,address,address,bytes32,uint256,uint256,bool)"

        ApproveHelper._approve(token, address(dsProxy), wadC);

        try
            dsProxy.execute(
                address(PROXY_ACTIONS),
                abi.encodeWithSelector(
                    funcSig,
                    address(CDP_MANAGER),
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
            revert ActionFail(funcSig, reason);
        } catch {
            revert ActionFail(funcSig, '');
        }

        ApproveHelper._approveZero(token, address(dsProxy));

        _transferTokenToRouter(DAI_TOKEN);
        _transferCdp(cdp);
    }

    /// @notice Deposits `value` amount of ETH in `ethJoin` adapter and increase the locked value of `cdp`.
    function safeLockETH(uint256 value, address ethJoin, uint256 cdp) external payable onlyRouter {
        // Get spender DSProxy
        IDSProxy dsProxy = IDSProxy(_getProxy(address(this)));
        address user = IRouter(router).user();
        address userDSProxy = _getProxy(user);
        value = Utils._getBalance(NATIVE_TOKEN_ADDRESS, value);
        bytes4 funcSig = 0xee284576; // selector of "safeLockETH(address,address,uint256,address)"

        try
            dsProxy.execute{value: value}(
                address(PROXY_ACTIONS),
                abi.encodeWithSelector(funcSig, address(CDP_MANAGER), ethJoin, cdp, userDSProxy)
            )
        {} catch Error(string memory reason) {
            revert ActionFail(funcSig, reason);
        } catch {
            revert ActionFail(funcSig, '');
        }
    }

    /// @notice Deposits `wad` amount of collateral in `gemJoin` adapter and increase the locked value of `cdp`.
    function safeLockGem(address gemJoin, uint256 cdp, uint256 wad) external payable onlyRouter {
        // Get spender DSProxy
        IDSProxy dsProxy = IDSProxy(_getProxy(address(this)));
        address user = IRouter(router).user();
        address userDSProxy = _getProxy(user);

        // Get collateral token
        address token = IMakerGemJoin(gemJoin).gem();
        wad = Utils._getBalance(token, wad);
        bytes4 funcSig = 0xead64729; // selector of "safeLockGem(address,address,uint256,uint256,bool,address)"

        ApproveHelper._approve(token, address(dsProxy), wad);

        try
            dsProxy.execute(
                address(PROXY_ACTIONS),
                abi.encodeWithSelector(funcSig, address(CDP_MANAGER), gemJoin, cdp, wad, true, userDSProxy)
            )
        {} catch Error(string memory reason) {
            revert ActionFail(funcSig, reason);
        } catch {
            revert ActionFail(funcSig, '');
        }

        ApproveHelper._approveZero(token, address(dsProxy));
    }

    /// @notice Decrease locked value of `cdp` and withdraws `wad` amount of ETH from `ethJoin` adapter.
    function freeETH(address ethJoin, uint256 cdp, uint256 wad) external payable onlyRouter cdpAllowed(cdp) {
        // Get spender DSProxy
        IDSProxy dsProxy = IDSProxy(_getProxy(address(this)));
        bytes4 funcSig = 0x7b5a3b43; // selector of "freeETH(address,address,uint256,uint256)"

        try
            dsProxy.execute(
                address(PROXY_ACTIONS),
                abi.encodeWithSelector(0x7b5a3b43, address(CDP_MANAGER), ethJoin, cdp, wad)
            )
        {} catch Error(string memory reason) {
            revert ActionFail(funcSig, reason);
        } catch {
            revert ActionFail(funcSig, '');
        }

        _transferTokenToRouter(NATIVE_TOKEN_ADDRESS);
    }

    /// @notice Decrease locked value of `cdp` and withdraws `wad` amount of collateral from `gemJoin` adapter.
    function freeGem(address gemJoin, uint256 cdp, uint256 wad) external payable onlyRouter cdpAllowed(cdp) {
        // Get spender DSProxy
        IDSProxy dsProxy = IDSProxy(_getProxy(address(this)));

        // Get collateral token
        address token = IMakerGemJoin(gemJoin).gem();
        bytes4 funcSig = 0x6ab6a491; // selector of "freeGem(address,address,uint256,uint256)"

        try
            dsProxy.execute(
                address(PROXY_ACTIONS),
                abi.encodeWithSelector(funcSig, address(CDP_MANAGER), gemJoin, cdp, wad)
            )
        {} catch Error(string memory reason) {
            revert ActionFail(funcSig, reason);
        } catch {
            revert ActionFail(funcSig, '');
        }

        _transferTokenToRouter(token);
    }

    /// @notice Increase debt of `cdp` and exits `wad` amount of DAI token from `daiJoin` adapter.
    function draw(address daiJoin, uint256 cdp, uint256 wad) external payable onlyRouter cdpAllowed(cdp) {
        // Get spender DSProxy
        IDSProxy proxy = IDSProxy(_getProxy(address(this)));
        bytes4 funcSig = 0x9f6f3d5b; // selector of "draw(address,address,address,uint256,uint256)"

        try
            proxy.execute(
                address(PROXY_ACTIONS),
                abi.encodeWithSelector(funcSig, address(CDP_MANAGER), getMcdJug(), daiJoin, cdp, wad)
            )
        {} catch Error(string memory reason) {
            revert ActionFail(funcSig, reason);
        } catch {
            revert ActionFail(funcSig, '');
        }

        _transferTokenToRouter(DAI_TOKEN);
    }

    /// @notice Repay `wad` amount of DAI token to `daiJoin` adapter and decrease the debt of `cdp`.
    function wipe(address daiJoin, uint256 cdp, uint256 wad) external payable onlyRouter {
        // Get spender DSProxy
        IDSProxy dsProxy = IDSProxy(_getProxy(address(this)));
        bytes4 funcSig = 0x4b666199; // selector of "wipe(address,address,uint256,uint256)"

        ApproveHelper._approve(DAI_TOKEN, address(dsProxy), wad);

        try
            dsProxy.execute(
                address(PROXY_ACTIONS),
                abi.encodeWithSelector(funcSig, address(CDP_MANAGER), daiJoin, cdp, wad)
            )
        {} catch Error(string memory reason) {
            revert ActionFail(funcSig, reason);
        } catch {
            revert ActionFail(funcSig, '');
        }

        ApproveHelper._approveZero(DAI_TOKEN, address(dsProxy));
    }

    /// @notice Repay all the necessary amount of DAI token to `daiJoin` adapter and set the debt to zero of `cdp`.
    function wipeAll(address daiJoin, uint256 cdp) external payable onlyRouter {
        // Get spender DSProxy
        IDSProxy dsProxy = IDSProxy(_getProxy(address(this)));
        bytes4 funcSig = 0x036a2395; // selector of "wipeAll(address,address,uint256)"

        ApproveHelper._approveMax(DAI_TOKEN, address(dsProxy), type(uint256).max);

        try
            dsProxy.execute(address(PROXY_ACTIONS), abi.encodeWithSelector(funcSig, address(CDP_MANAGER), daiJoin, cdp))
        {} catch Error(string memory reason) {
            revert ActionFail(funcSig, reason);
        } catch {
            revert ActionFail(funcSig, '');
        }

        ApproveHelper._approveZero(DAI_TOKEN, address(dsProxy));

        // Transfer remaining token to router
        _transferTokenToRouter(DAI_TOKEN);
    }

    function getMcdJug() public view returns (address) {
        return IMakerChainLog(CHAIN_LOG).getAddress('MCD_JUG');
    }

    /// @notice Get `user`'s DSProxy.
    function _getProxy(address user) internal view returns (address) {
        return IDSProxyRegistry(PROXY_REGISTRY).proxies(user);
    }

    function _createDSProxy() internal {
        IDSProxyRegistry(PROXY_REGISTRY).build();
    }

    function _transferCdp(uint256 cdp) internal {
        // Get spender DSProxy
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
