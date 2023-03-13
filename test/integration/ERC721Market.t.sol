// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {SafeERC20, IERC20} from 'openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol';
import {IERC721} from 'openzeppelin-contracts/contracts/token/ERC721/ERC721.sol';
import {SafeCast160} from 'permit2/libraries/SafeCast160.sol';
import {IAgent} from '../../src/interfaces/IAgent.sol';
import {Router, IRouter} from '../../src/Router.sol';
import {IParam} from '../../src/interfaces/IParam.sol';
import {SpenderPermitUtils} from '../utils/SpenderPermitUtils.sol';
import {SpenderERC721Utils} from '../utils/SpenderERC721Utils.sol';
import {MockERC721Market} from '../mocks/MockERC721Market.sol';

contract ERC721MarketTest is Test, SpenderPermitUtils, SpenderERC721Utils {
    using SafeERC20 for IERC20;
    using SafeCast160 for uint256;

    IERC20 public constant USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    uint256 public constant BPS_BASE = 10_000;
    uint256 public constant SKIP = type(uint256).max;

    address public user;
    uint256 public userPrivateKey;
    IRouter public router;
    IAgent public agent;
    IERC721 public nft;
    MockERC721Market public market;

    // Empty arrays
    IParam.Input[] inputsEmpty;

    function setUp() external {
        (user, userPrivateKey) = makeAddrAndKey('User');
        router = new Router();
        vm.prank(user);
        agent = IAgent(router.newAgent());
        market = new MockERC721Market(USDC);
        nft = IERC721(address(market.nft()));

        // User permit token
        spenderSetUp(user, userPrivateKey, router);
        permitToken(USDC);
        spenderERC721SetUp(user, address(router));
        permitERC721Token(address(nft));

        vm.label(address(router), 'Router');
        vm.label(address(agent), 'Agent');
        vm.label(address(spender), 'SpenderPermit2ERC20');
        vm.label(address(erc721Spender), 'SpenderERC721Approval');
        vm.label(address(USDC), 'USDC');
        vm.label(address(market), 'ERC721Market');
    }

    function testExecuteERC721MarketTokenToNFT(uint256 tokenId) external {
        IERC20 tokenIn = USDC;
        uint256 amountIn = market.amount();

        tokenId = bound(tokenId, 0, 1e10);
        deal(address(tokenIn), user, amountIn);

        // Encode logics
        IParam.Logic[] memory logics = new IParam.Logic[](3);
        logics[0] = logicSpenderPermit2ERC20PullToken(tokenIn, amountIn.toUint160());
        logics[1] = _logicTokenApproval(tokenIn, address(market), amountIn, SKIP);
        logics[2] = _logicERC721MarketTokenToNFT(tokenIn, amountIn, tokenId);
        // TODO: Return nft to user

        address[] memory tokensReturn = new address[](1);
        tokensReturn[0] = address(tokenIn);

        // Execute
        vm.prank(user);
        router.execute(logics, tokensReturn);

        // Verify
        assertEq(tokenIn.balanceOf(address(router)), 0);
        assertEq(tokenIn.balanceOf(address(agent)), 0);
        assertEq(nft.ownerOf(tokenId), address(agent));
    }

    function testExecuteERC721MarketNFtToToken(uint256 tokenId) external {
        IERC20 tokenIn = USDC;
        uint256 amountIn = market.amount();

        tokenId = bound(tokenId, 0, 1e10);
        deal(address(tokenIn), user, amountIn);

        vm.startPrank(user);
        tokenIn.approve(address(market), amountIn);
        market.tokenToNft(tokenId);
        vm.stopPrank();

        // Encode logics
        IParam.Logic[] memory logics = new IParam.Logic[](3);
        logics[0] = logicSpenderERC721PullToken(address(nft), tokenId);
        logics[1] = _logicERC721Approval(nft, address(market));
        logics[2] = _logicERC721MarketNFTToToken(tokenId);
        // TODO: Return nft to user

        address[] memory tokensReturn = new address[](1);
        tokensReturn[0] = address(tokenIn);

        // Execute
        uint256 tokenBefore = tokenIn.balanceOf(user);
        vm.prank(user);
        router.execute(logics, tokensReturn);

        // Verify
        assertEq(tokenIn.balanceOf(address(router)), 0);
        assertEq(tokenIn.balanceOf(address(agent)), 0);
        assertEq(tokenIn.balanceOf(address(user)), tokenBefore + amountIn);
        assertEq(nft.ownerOf(tokenId), address(market));
    }

    function _logicTokenApproval(
        IERC20 token,
        address spender,
        uint256 amount,
        uint256 amountBps
    ) internal pure returns (IParam.Logic memory) {
        // Encode data
        bytes memory data = abi.encodeCall(IERC20.approve, (spender, amount));
        IParam.Input[] memory inputs = new IParam.Input[](1);
        inputs[0].token = address(token);
        inputs[0].amountBps = amountBps;
        if (amountBps == SKIP) {
            inputs[0].amountOrOffset = amount;
        } else {
            inputs[0].amountOrOffset = 0x20;
        }

        return IParam.Logic(address(token), data, inputs, address(0));
    }

    function _logicERC721Approval(IERC721 token, address spender) internal view returns (IParam.Logic memory) {
        bytes memory data = abi.encodeWithSelector(IERC721.setApprovalForAll.selector, spender, true);
        return
            IParam.Logic(
                address(token), // to
                data,
                inputsEmpty,
                address(0) // callback
            );
    }

    function _logicERC721MarketTokenToNFT(
        IERC20 tokenIn,
        uint256 amountIn,
        uint256 tokenId
    ) public view returns (IParam.Logic memory) {
        // Encode data
        bytes memory data = abi.encodeWithSelector(market.tokenToNft.selector, tokenId);

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
                address(0) // callback
            );
    }
}
