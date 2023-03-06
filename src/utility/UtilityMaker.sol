// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {SafeERC20, IERC20} from 'openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol';
import {IRouter} from '../interfaces/IRouter.sol';
import {IUtilityMaker} from '../interfaces/utility/IUtilityMaker.sol';
import {IDSProxy, IDSProxyRegistry} from '../interfaces/maker/IDSProxy.sol';
import {IMakerManager, IMakerGemJoin} from '../interfaces/maker/IMaker.sol';
import {ApproveHelper} from '../libraries/ApproveHelper.sol';

contract UtilityMaker is IUtilityMaker {
    using SafeERC20 for IERC20;

    address public constant NATIVE_TOKEN_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address public immutable router;
    address public immutable proxyRegistry;
    address public immutable cdpManager;
    address public immutable proxyActions;
    address public immutable daiToken;
    address public immutable jug;
    // UtilityMaker's DSProxy
    IDSProxy public immutable dsProxy;

    modifier onlyAgent() {
        address agent = IRouter(router).getAgent();
        if (msg.sender != agent) revert InvalidAgent();
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
    ) external payable onlyAgent returns (uint256 cdp) {
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

        _transferTokenToAgent(daiToken);
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
    ) external onlyAgent returns (uint256 cdp) {
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

        _transferTokenToAgent(daiToken);
        _transferCdp(cdp);
    }

    function _transferTokenToAgent(address token) internal {
        address agent = IRouter(router).getAgent();
        uint256 balance = IERC20(token).balanceOf(address(this));
        IERC20(token).safeTransfer(agent, balance);
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
}
