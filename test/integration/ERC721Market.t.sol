// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {IERC20} from 'lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol';
import {IERC721} from 'lib/openzeppelin-contracts/contracts/token/ERC721/ERC721.sol';
import {SafeCast160} from 'lib/permit2/src/libraries/SafeCast160.sol';
import {IAgent} from 'src/interfaces/IAgent.sol';
import {Router, IRouter} from 'src/Router.sol';
import {DataType} from 'src/libraries/DataType.sol';
import {ERC20Permit2Utils} from '../utils/ERC20Permit2Utils.sol';
import {ERC721Utils} from '../utils/ERC721Utils.sol';
import {MockERC721Market} from '../mocks/MockERC721Market.sol';

contract ERC721MarketTest is Test, ERC20Permit2Utils, ERC721Utils {
    using SafeCast160 for uint256;

    IERC20 public constant USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    uint256 public constant BPS_NOT_USED = 0;

    address public user;
    uint256 public userPrivateKey;
    IRouter public router;
    IAgent public agent;
    IERC721 public nft;
    MockERC721Market public market;

    // Empty arrays
    DataType.Input[] public inputsEmpty;
    bytes[] public permit2DatasEmpty;

    function setUp() external {
        vm.createSelectFork(vm.rpcUrl('ethereum'));

        (user, userPrivateKey) = makeAddrAndKey('User');
        router = new Router(makeAddr('WrappedNative'), permit2Addr, address(this));
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

        // Encode permit2Datas
        bytes[] memory datas = new bytes[](1);
        datas[0] = dataERC20Permit2PullToken(tokenIn, amountIn.toUint160());

        // Encode logics
        DataType.Logic[] memory logics = new DataType.Logic[](1);
        logics[0] = _logicERC721MarketTokenToNFT(tokenIn, amountIn, tokenId, user);

        address[] memory tokensReturn = new address[](1);
        tokensReturn[0] = address(tokenIn);

        // Execute
        vm.prank(user);
        router.execute(datas, logics, tokensReturn);

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
        DataType.Logic[] memory logics = new DataType.Logic[](3);
        logics[0] = logicERC721PullToken(address(nft), tokenId);
        logics[1] = _logicERC721Approval(nft, address(market));
        logics[2] = _logicERC721MarketNFTToToken(tokenId);

        address[] memory tokensReturn = new address[](1);
        tokensReturn[0] = address(tokenIn);

        // Execute
        uint256 tokenBefore = tokenIn.balanceOf(user);
        vm.prank(user);
        router.execute(permit2DatasEmpty, logics, tokensReturn);

        // Verify
        assertEq(tokenIn.balanceOf(address(router)), 0);
        assertEq(tokenIn.balanceOf(address(agent)), 0);
        assertEq(tokenIn.balanceOf(user), tokenBefore + amountIn);
        assertEq(nft.ownerOf(tokenId), address(market));
    }

    function _logicERC721Approval(IERC721 token, address spender) internal view returns (DataType.Logic memory) {
        bytes memory data = abi.encodeWithSelector(IERC721.setApprovalForAll.selector, spender, true);
        return
            DataType.Logic(
                address(token), // to
                data,
                inputsEmpty,
                DataType.WrapMode.NONE,
                address(0), // approveTo
                address(0) // callback
            );
    }

    function _logicERC721MarketTokenToNFT(
        IERC20 tokenIn,
        uint256 amountIn,
        uint256 tokenId,
        address recipient
    ) public view returns (DataType.Logic memory) {
        // Encode data
        bytes memory data = abi.encodeWithSelector(market.tokenToNft.selector, tokenId, recipient);

        // Encode inputs
        DataType.Input[] memory inputs = new DataType.Input[](1);
        inputs[0].token = address(tokenIn);
        inputs[0].balanceBps = BPS_NOT_USED;
        inputs[0].amountOrOffset = amountIn;

        return
            DataType.Logic(
                address(market), // to
                data,
                inputs,
                DataType.WrapMode.NONE,
                address(0), // approveTo
                address(0) // callback
            );
    }

    function _logicERC721MarketNFTToToken(uint256 tokenId) public view returns (DataType.Logic memory) {
        // Encode data
        bytes memory data = abi.encodeWithSelector(market.nftToToken.selector, tokenId);
        return
            DataType.Logic(
                address(market), // to
                data,
                inputsEmpty,
                DataType.WrapMode.NONE,
                address(0), // approveTo
                address(0) // callback
            );
    }
}
