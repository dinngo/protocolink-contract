// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {IERC20} from 'lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol';
import {IERC1155} from 'lib/openzeppelin-contracts/contracts/token/ERC1155/ERC1155.sol';
import {SafeCast160} from 'lib/permit2/src/libraries/SafeCast160.sol';
import {IAgent} from 'src/interfaces/IAgent.sol';
import {Router, IRouter} from 'src/Router.sol';
import {DataType} from 'src/libraries/DataType.sol';
import {ERC20Permit2Utils} from '../utils/ERC20Permit2Utils.sol';
import {ERC1155Utils} from '../utils/ERC1155Utils.sol';
import {MockERC1155Market} from '../mocks/MockERC1155Market.sol';

contract ERC1155MarketTest is Test, ERC20Permit2Utils, ERC1155Utils {
    using SafeCast160 for uint256;

    IERC20 public constant USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    uint256 public constant BPS_NOT_USED = 0;

    address public user;
    uint256 public userPrivateKey;
    IRouter public router;
    IAgent public agent;
    IERC1155 public nft;
    MockERC1155Market public market;

    // Empty arrays
    DataType.Input[] public inputsEmpty;
    bytes[] public permit2DatasEmpty;

    function setUp() external {
        vm.createSelectFork(vm.rpcUrl('ethereum'));

        (user, userPrivateKey) = makeAddrAndKey('User');
        router = new Router(makeAddr('WrappedNative'), permit2Addr, address(this));
        vm.prank(user);
        agent = IAgent(router.newAgent());
        market = new MockERC1155Market(USDC);
        nft = IERC1155(address(market.nft()));

        // User permit token
        erc20Permit2UtilsSetUp(user, userPrivateKey, address(agent));
        permitToken(USDC);
        erc1155UtilsSetUp(user, address(agent));
        permitERC1155Token(address(nft));

        vm.label(address(router), 'Router');
        vm.label(address(agent), 'Agent');
        vm.label(address(USDC), 'USDC');
        vm.label(address(market), 'ERC1155Market');
    }

    function testExecuteERC1155MarketTokenToNFT(uint256 tokenId, uint256 amount) external {
        IERC20 tokenIn = USDC;

        tokenId = bound(tokenId, 0, 1e10);
        amount = bound(amount, 1, 1e5);
        uint256 amountIn = amount * market.amount();
        deal(address(tokenIn), user, amountIn);

        // Encode permit2Datas
        bytes[] memory datas = new bytes[](1);
        datas[0] = dataERC20Permit2PullToken(tokenIn, amountIn.toUint160());

        // Encode logics
        DataType.Logic[] memory logics = new DataType.Logic[](1);
        logics[0] = _logicERC1155MarketTokenToNFT(tokenIn, amountIn, tokenId, amount, user);
        address[] memory tokensReturn = new address[](1);
        tokensReturn[0] = address(tokenIn);

        // Execute
        vm.prank(user);
        router.execute(datas, logics, tokensReturn);

        // Verify
        assertEq(tokenIn.balanceOf(address(router)), 0);
        assertEq(tokenIn.balanceOf(address(agent)), 0);
        assertEq(nft.balanceOf(user, tokenId), amount);
    }

    function testExecuteERC1155MarketNFtToToken(uint256 tokenId, uint256 amount) external {
        IERC20 tokenIn = USDC;

        tokenId = bound(tokenId, 0, 1e10);
        amount = bound(amount, 0, 1e5);
        uint256 amountIn = amount * market.amount();
        deal(address(tokenIn), user, amountIn);

        vm.startPrank(user);
        tokenIn.approve(address(market), amountIn);
        market.tokenToNft(tokenId, amount, user);
        vm.stopPrank();

        // Encode logics
        DataType.Logic[] memory logics = new DataType.Logic[](3);
        logics[0] = logicERC1155PullToken(address(nft), tokenId, amount);
        logics[1] = _logicERC1155Approval(nft, address(market));
        logics[2] = _logicERC1155MarketNFTToToken(tokenId, amount);
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
        assertEq(nft.balanceOf(address(market), tokenId), amount);
    }

    function testExecuteERC1155MarketTokenToNFTBatch(uint256 tokenId, uint256 amount) external {
        IERC20 tokenIn = USDC;

        tokenId = bound(tokenId, 0, 1e10);
        amount = bound(amount, 1, 1e5);
        uint256 amountIn = amount * market.amount();
        deal(address(tokenIn), user, amountIn);

        // Encode permit2Datas
        bytes[] memory datas = new bytes[](1);
        datas[0] = dataERC20Permit2PullToken(tokenIn, amountIn.toUint160());

        // Encode logics
        DataType.Logic[] memory logics = new DataType.Logic[](1);
        logics[0] = _logicERC1155MarketTokenToNFTBatch(tokenIn, amountIn, tokenId, amount, user);
        address[] memory tokensReturn = new address[](1);
        tokensReturn[0] = address(tokenIn);

        // Execute
        vm.prank(user);
        router.execute(datas, logics, tokensReturn);

        // Verify
        assertEq(tokenIn.balanceOf(address(router)), 0);
        assertEq(tokenIn.balanceOf(address(agent)), 0);
        assertEq(nft.balanceOf(user, tokenId), amount);
    }

    function testExecuteERC1155MarketNFtBatchToToken(uint256 tokenId, uint256 amount) external {
        IERC20 tokenIn = USDC;

        tokenId = bound(tokenId, 0, 1e10);
        amount = bound(amount, 0, 1e5);
        uint256 amountIn = amount * market.amount();
        deal(address(tokenIn), user, amountIn);

        vm.startPrank(user);
        tokenIn.approve(address(market), amountIn);
        market.tokenToNft(tokenId, amount, user);
        vm.stopPrank();

        // Encode logics
        DataType.Logic[] memory logics = new DataType.Logic[](3);
        logics[0] = logicERC1155PullToken(address(nft), tokenId, amount);
        logics[1] = _logicERC1155Approval(nft, address(market));
        logics[2] = _logicERC1155MarketNFTBatchToToken(tokenId, amount);
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
        assertEq(nft.balanceOf(address(market), tokenId), amount);
    }

    function _logicERC1155Approval(IERC1155 token, address spender) internal view returns (DataType.Logic memory) {
        bytes memory data = abi.encodeWithSelector(IERC1155.setApprovalForAll.selector, spender, true);
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

    function _logicERC1155MarketTokenToNFT(
        IERC20 tokenIn,
        uint256 amountIn,
        uint256 tokenId,
        uint256 amount,
        address recipient
    ) public view returns (DataType.Logic memory) {
        // Encode data
        bytes memory data = abi.encodeWithSelector(market.tokenToNft.selector, tokenId, amount, recipient);

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

    function _logicERC1155MarketTokenToNFTBatch(
        IERC20 tokenIn,
        uint256 amountIn,
        uint256 tokenId,
        uint256 amount,
        address recipient
    ) public view returns (DataType.Logic memory) {
        // Encode data
        uint256[] memory tokenIds = new uint256[](1);
        uint256[] memory amounts = new uint256[](1);
        tokenIds[0] = tokenId;
        amounts[0] = amount;
        bytes memory data = abi.encodeWithSelector(market.tokenToNftBatch.selector, tokenIds, amounts, recipient);

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

    function _logicERC1155MarketNFTToToken(
        uint256 tokenId,
        uint256 amount
    ) public view returns (DataType.Logic memory) {
        // Encode data

        bytes memory data = abi.encodeWithSelector(market.nftToToken.selector, tokenId, amount);
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

    function _logicERC1155MarketNFTBatchToToken(
        uint256 tokenId,
        uint256 amount
    ) public view returns (DataType.Logic memory) {
        // Encode data
        uint256[] memory tokenIds = new uint256[](1);
        uint256[] memory amounts = new uint256[](1);
        tokenIds[0] = tokenId;
        amounts[0] = amount;
        bytes memory data = abi.encodeWithSelector(market.nftBatchToToken.selector, tokenIds, amounts);
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
