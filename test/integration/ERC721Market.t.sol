// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {SafeERC20, IERC20} from 'openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol';
import {IERC721} from 'openzeppelin-contracts/contracts/token/ERC721/ERC721.sol';
import {SafeCast160} from 'permit2/libraries/SafeCast160.sol';
import {IAgent} from 'src/interfaces/IAgent.sol';
import {Router, IRouter} from 'src/Router.sol';
import {IParam} from 'src/interfaces/IParam.sol';
import {ERC20Permit2Utils} from '../utils/ERC20Permit2Utils.sol';
import {ERC721Utils} from '../utils/ERC721Utils.sol';
import {MockERC721Market} from '../mocks/MockERC721Market.sol';

contract ERC721MarketTest is Test, ERC20Permit2Utils, ERC721Utils {
    using SafeERC20 for IERC20;
    using SafeCast160 for uint256;

    IERC20 public constant USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    uint256 public constant BPS_BASE = 10_000;
    uint256 public constant SKIP = 0x8000000000000000000000000000000000000000000000000000000000000000;

    address public user;
    uint256 public userPrivateKey;
    IRouter public router;
    IAgent public agent;
    IERC721 public nft;
    MockERC721Market public market;

    // Empty arrays
    IParam.Input[] public inputsEmpty;

    function setUp() external {
        (user, userPrivateKey) = makeAddrAndKey('User');
        router = new Router(makeAddr('WrappedNative'), makeAddr('Pauser'), makeAddr('FeeCollector'));
        vm.prank(user);
        agent = IAgent(router.newAgent());
        market = new MockERC721Market(USDC);
        nft = IERC721(address(market.nft()));

        // User permit token
        erc20Permit2UtilsSetUp(user, userPrivateKey, address(agent));
        permitToken(USDC);
        erc721UtilsSetUp(user, address(agent));
        permitERC721Token(address(nft));

        vm.label(address(router), 'Router');
        vm.label(address(agent), 'Agent');
        vm.label(address(USDC), 'USDC');
        vm.label(address(market), 'ERC721Market');
    }

    function testExecuteERC721MarketTokenToNFT(uint256 tokenId) external {
        IERC20 tokenIn = USDC;
        uint256 amountIn = market.amount();

        tokenId = bound(tokenId, 0, 1e10);
        deal(address(tokenIn), user, amountIn);

        // Encode logics
        IParam.Logic[] memory logics = new IParam.Logic[](2);
        logics[0] = logicERC20Permit2PullToken(tokenIn, amountIn.toUint160());
        logics[1] = _logicERC721MarketTokenToNFT(tokenIn, amountIn, tokenId, user);

        address[] memory tokensReturn = new address[](1);
        tokensReturn[0] = address(tokenIn);

        // Execute
        vm.prank(user);
        router.execute(logics, tokensReturn, SIGNER_REFERRAL);

        // Verify
        assertEq(tokenIn.balanceOf(address(router)), 0);
        assertEq(tokenIn.balanceOf(address(agent)), 0);
        assertEq(nft.ownerOf(tokenId), user);
    }

    function testExecuteERC721MarketNFtToToken(uint256 tokenId) external {
        IERC20 tokenIn = USDC;
        uint256 amountIn = market.amount();

        tokenId = bound(tokenId, 0, 1e10);
        deal(address(tokenIn), user, amountIn);

        vm.startPrank(user);
        tokenIn.approve(address(market), amountIn);
        market.tokenToNft(tokenId, user);
        vm.stopPrank();

        // Encode logics
        IParam.Logic[] memory logics = new IParam.Logic[](3);
        logics[0] = logicERC721PullToken(address(nft), tokenId);
        logics[1] = _logicERC721Approval(nft, address(market));
        logics[2] = _logicERC721MarketNFTToToken(tokenId);

        address[] memory tokensReturn = new address[](1);
        tokensReturn[0] = address(tokenIn);

        // Execute
        uint256 tokenBefore = tokenIn.balanceOf(user);
        vm.prank(user);
        router.execute(logics, tokensReturn, SIGNER_REFERRAL);

        // Verify
        assertEq(tokenIn.balanceOf(address(router)), 0);
        assertEq(tokenIn.balanceOf(address(agent)), 0);
        assertEq(tokenIn.balanceOf(user), tokenBefore + amountIn);
        assertEq(nft.ownerOf(tokenId), address(market));
    }

    function _logicERC721Approval(IERC721 token, address spender) internal view returns (IParam.Logic memory) {
        bytes memory data = abi.encodeWithSelector(IERC721.setApprovalForAll.selector, spender, true);
        return
            IParam.Logic(
                address(token), // to
                data,
                inputsEmpty,
                IParam.WrapMode.NONE,
                address(0), // approveTo
                address(0) // callback
            );
    }

    function _logicERC721MarketTokenToNFT(
        IERC20 tokenIn,
        uint256 amountIn,
        uint256 tokenId,
        address recipient
    ) public view returns (IParam.Logic memory) {
        // Encode data
        bytes memory data = abi.encodeWithSelector(market.tokenToNft.selector, tokenId, recipient);

        // Encode inputs
        IParam.Input[] memory inputs = new IParam.Input[](1);
        inputs[0].token = address(tokenIn);
        inputs[0].amountBps = SKIP;
        inputs[0].amountOrOffset = amountIn;

        return
            IParam.Logic(
                address(market), // to
                data,
                inputs,
                IParam.WrapMode.NONE,
                address(0), // approveTo
                address(0) // callback
            );
    }

    function _logicERC721MarketNFTToToken(uint256 tokenId) public view returns (IParam.Logic memory) {
        // Encode data
        bytes memory data = abi.encodeWithSelector(market.nftToToken.selector, tokenId);
        return
            IParam.Logic(
                address(market), // to
                data,
                inputsEmpty,
                IParam.WrapMode.NONE,
                address(0), // approveTo
                address(0) // callback
            );
    }
}
