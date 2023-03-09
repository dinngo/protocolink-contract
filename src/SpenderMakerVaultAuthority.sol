// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {SafeERC20, IERC20, Address} from 'openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol';
import {IRouter} from './interfaces/IRouter.sol';
import {IDSProxy, IDSProxyRegistry} from './interfaces/maker/IDSProxy.sol';
import {IMakerManager, IMakerGemJoin} from './interfaces/maker/IMaker.sol';
import {ISpenderMakerVaultAuthority} from './interfaces/ISpenderMakerVaultAuthority.sol';

///@title Spender for Maker which user can interact with Maker
contract SpenderMakerVaultAuthority is ISpenderMakerVaultAuthority {
    using SafeERC20 for IERC20;
    using Address for address payable;

    address public constant NATIVE_TOKEN_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address public immutable router;
    address public immutable proxyRegistry;
    address public immutable cdpManager;
    address public immutable proxyActions;
    address public immutable daiToken;
    address public immutable jug;
    // SpenderMakerVaultAuthority's DSProxy
    IDSProxy public immutable dsProxy;

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

    receive() external payable {}

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

    /// @notice Decrease locked value of `cdp` and withdraws `wad` amount of ETH from `ethJoin` adapter.
    function freeETH(address ethJoin, uint256 cdp, uint256 wad) external cdpAllowed(cdp) {
        address agent = IRouter(router).getAgent();
        if (msg.sender != agent) revert InvalidAgent();

        dsProxy.execute(
            proxyActions,
            abi.encodeWithSelector(
                0x7b5a3b43, // selector of "freeETH(address,address,uint256,uint256)"
                cdpManager,
                ethJoin,
                cdp,
                wad
            )
        );

        payable(agent).sendValue(wad);
    }

    /// @notice Decrease locked value of `cdp` and withdraws `wad` amount of collateral from `gemJoin` adapter.
    function freeGem(address gemJoin, uint256 cdp, uint256 wad) external cdpAllowed(cdp) {
        address agent = IRouter(router).getAgent();
        if (msg.sender != agent) revert InvalidAgent();

        // Get collateral token
        address token = IMakerGemJoin(gemJoin).gem();

        dsProxy.execute(
            proxyActions,
            abi.encodeWithSelector(
                0x6ab6a491, // selector of "freeGem(address,address,uint256,uint256)"
                cdpManager,
                gemJoin,
                cdp,
                wad
            )
        );

        IERC20(token).safeTransfer(agent, wad);
    }

    /// @notice Increase debt of `cdp` and exits `wad` amount of DAI token from `daiJoin` adapter.
    function draw(address daiJoin, uint256 cdp, uint256 wad) external cdpAllowed(cdp) {
        address agent = IRouter(router).getAgent();
        if (msg.sender != agent) revert InvalidAgent();

        dsProxy.execute(
            proxyActions,
            abi.encodeWithSelector(
                0x9f6f3d5b, // selector of "draw(address,address,address,uint256,uint256)"
                cdpManager,
                jug,
                daiJoin,
                cdp,
                wad
            )
        );

        IERC20(daiToken).safeTransfer(agent, wad);
    }
}
