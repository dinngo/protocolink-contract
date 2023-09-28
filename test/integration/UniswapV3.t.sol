// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {SafeERC20, IERC20} from 'lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol';
import {SafeCast160} from 'lib/permit2/src/libraries/SafeCast160.sol';
import {IAgent} from 'src/interfaces/IAgent.sol';
import {Router, IRouter} from 'src/Router.sol';
import {DataType} from 'src/libraries/DataType.sol';
import {ERC20Permit2Utils} from '../utils/ERC20Permit2Utils.sol';
import {ERC721Utils} from '../utils/ERC721Utils.sol';

interface INonfungiblePositionManager {
    function positions(
        uint256 tokenId
    )
        external
        view
        returns (
            uint96 nonce,
            address operator,
            address token0,
            address token1,
            uint24 fee,
            int24 tickLower,
            int24 tickUpper,
            uint128 liquidity,
            uint256 feeGrowthInside0LastX128,
            uint256 feeGrowthInside1LastX128,
            uint128 tokensOwed0,
            uint128 tokensOwed1
        );

    struct MintParams {
        address token0;
        address token1;
        uint24 fee;
        int24 tickLower;
        int24 tickUpper;
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0Min;
        uint256 amount1Min;
        address recipient;
        uint256 deadline;
    }

    function mint(
        MintParams calldata params
    ) external payable returns (uint256 tokenId, uint128 liquidity, uint256 amount0, uint256 amount1);

    struct IncreaseLiquidityParams {
        uint256 tokenId;
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0Min;
        uint256 amount1Min;
        uint256 deadline;
    }

    function increaseLiquidity(
        IncreaseLiquidityParams calldata params
    ) external payable returns (uint128 liquidity, uint256 amount0, uint256 amount1);

    struct DecreaseLiquidityParams {
        uint256 tokenId;
        uint128 liquidity;
        uint256 amount0Min;
        uint256 amount1Min;
        uint256 deadline;
    }

    function decreaseLiquidity(
        DecreaseLiquidityParams calldata params
    ) external payable returns (uint256 amount0, uint256 amount1);

    struct CollectParams {
        uint256 tokenId;
        address recipient;
        uint128 amount0Max;
        uint128 amount1Max;
    }

    function collect(CollectParams calldata params) external payable returns (uint256 amount0, uint256 amount1);

    function ownerOf(uint256 tokenId) external view returns (address owner);

    function setApprovalForAll(address operator, bool _approved) external;
}

contract UniswapV3Test is Test, ERC20Permit2Utils, ERC721Utils {
    using SafeERC20 for IERC20;
    using SafeCast160 for uint256;

    event IncreaseLiquidity(uint256 indexed tokenId, uint128 liquidity, uint256 amount0, uint256 amount1);
    event DecreaseLiquidity(uint256 indexed tokenId, uint128 liquidity, uint256 amount0, uint256 amount1);

    address public constant NATIVE = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    IERC20 public constant USDT = IERC20(0xdAC17F958D2ee523a2206206994597C13D831ec7);
    IERC20 public constant USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    INonfungiblePositionManager public constant NON_FUNGIBLE_POSITION_MANAGER =
        INonfungiblePositionManager(0xC36442b4a4522E871399CD717aBDD847Ab11FE88);
    uint256 public constant BPS_NOT_USED = 0;

    address public user;
    uint256 public userPrivateKey;
    IRouter public router;
    IAgent public agent;

    // Avoid stack too deep
    IERC20 tokenIn0;
    IERC20 tokenIn1;
    uint256 userToken0Before;
    uint256 userToken1Before;
    uint256 tokenId;
    uint128 liquidity;

    // Empty arrays
    address[] public tokensReturnEmpty;
    DataType.Input[] public inputsEmpty;
    bytes[] public permit2DatasEmpty;

    function setUp() external {
        vm.createSelectFork(vm.rpcUrl('ethereum'));

        (user, userPrivateKey) = makeAddrAndKey('User');
        router = new Router(makeAddr('WrappedNative'), permit2Addr, address(this));
        vm.prank(user);
        agent = IAgent(router.newAgent());

        // User permit token
        erc20Permit2UtilsSetUp(user, userPrivateKey, address(agent));
        permitToken(USDT);
        permitToken(USDC);
        erc721UtilsSetUp(user, address(router));
        permitERC721Token(address(NON_FUNGIBLE_POSITION_MANAGER));

        vm.label(address(router), 'Router');
        vm.label(address(agent), 'Agent');
        vm.label(address(USDT), 'USDT');
        vm.label(address(USDC), 'USDC');
        vm.label(address(NON_FUNGIBLE_POSITION_MANAGER), 'NON_FUNGIBLE_POSITION_MANAGER');
    }

    function testExecuteUniswapV3Mint(uint256 amountIn0, uint256 amountIn1) external {
        tokenIn0 = USDC;
        tokenIn1 = USDT;
        amountIn0 = bound(amountIn0, 1e6, 1e10);
        amountIn1 = bound(amountIn1, 1e6, 1e10);
        deal(address(tokenIn0), user, amountIn0);
        deal(address(tokenIn1), user, amountIn1);

        // Prepare execution parameter
        int24 tickLower = -275480; // min price
        int24 tickUpper = -275450; // max price
        INonfungiblePositionManager.MintParams memory mintParams = INonfungiblePositionManager.MintParams({
            token0: address(tokenIn0),
            token1: address(tokenIn1),
            fee: 500,
            tickLower: tickLower,
            tickUpper: tickUpper,
            amount0Desired: amountIn0,
            amount1Desired: amountIn1,
            amount0Min: 0,
            amount1Min: 0,
            recipient: user,
            deadline: block.timestamp
        });

        // Get estimate value
        vm.startPrank(user);
        tokenIn0.safeApprove(address(NON_FUNGIBLE_POSITION_MANAGER), type(uint256).max);
        tokenIn1.safeApprove(address(NON_FUNGIBLE_POSITION_MANAGER), type(uint256).max);
        vm.stopPrank();
        (, bytes memory returnData) = _callStatic(
            user,
            address(NON_FUNGIBLE_POSITION_MANAGER),
            abi.encodeWithSelector(NON_FUNGIBLE_POSITION_MANAGER.mint.selector, mintParams)
        );
        (tokenId, , , ) = abi.decode(returnData, (uint256, uint128, uint256, uint256));

        // Encode permit2Datas
        bytes[] memory datas = new bytes[](2);
        datas[0] = dataERC20Permit2PullToken(tokenIn0, amountIn0.toUint160());
        datas[1] = dataERC20Permit2PullToken(tokenIn1, amountIn1.toUint160());

        // Encode logics
        DataType.Logic[] memory logics = new DataType.Logic[](1);
        logics[0] = _logicUniswapV3MintLiquidityNFT(tokenIn0, tokenIn1, amountIn0, amountIn1, mintParams);

        address[] memory tokensReturn = new address[](2);
        tokensReturn[0] = address(tokenIn0);
        tokensReturn[1] = address(tokenIn1);

        // Execute
        vm.prank(user);
        router.execute(datas, logics, tokensReturn);

        // Verify
        assertEq(tokenIn0.balanceOf(address(router)), 0);
        assertEq(tokenIn0.balanceOf(address(agent)), 0);
        assertEq(tokenIn1.balanceOf(address(router)), 0);
        assertEq(tokenIn1.balanceOf(address(agent)), 0);
        assertEq(NON_FUNGIBLE_POSITION_MANAGER.ownerOf(tokenId), user);
    }

    function testExecuteUniswapV3IncreaseLiquidity(uint256 amountIn0, uint256 amountIn1) external {
        tokenIn0 = USDC;
        tokenIn1 = USDT;
        amountIn0 = bound(amountIn0, 1e6, 1e10);
        amountIn1 = bound(amountIn0, 1e6, 1e10);
        deal(address(tokenIn0), user, amountIn0 * 2);
        deal(address(tokenIn1), user, amountIn1 * 2);

        // mint NFT
        int24 tickLower = -275480; // min price
        int24 tickUpper = -275450; // max price
        INonfungiblePositionManager.MintParams memory mintParams = INonfungiblePositionManager.MintParams({
            token0: address(tokenIn0),
            token1: address(tokenIn1),
            fee: 500,
            tickLower: tickLower,
            tickUpper: tickUpper,
            amount0Desired: amountIn0,
            amount1Desired: amountIn1,
            amount0Min: 0,
            amount1Min: 0,
            recipient: user,
            deadline: block.timestamp
        });

        vm.startPrank(user);
        tokenIn0.safeApprove(address(NON_FUNGIBLE_POSITION_MANAGER), type(uint256).max);
        tokenIn1.safeApprove(address(NON_FUNGIBLE_POSITION_MANAGER), type(uint256).max);
        vm.stopPrank();
        (, bytes memory returnData) = _callStatic(
            user,
            address(NON_FUNGIBLE_POSITION_MANAGER),
            abi.encodeWithSelector(NON_FUNGIBLE_POSITION_MANAGER.mint.selector, mintParams)
        );
        uint256 estimatedAmount0;
        uint256 estimatedAmount1;
        (tokenId, liquidity, estimatedAmount0, estimatedAmount1) = abi.decode(
            returnData,
            (uint256, uint128, uint256, uint256)
        );

        vm.prank(user);
        vm.expectEmit(true, true, true, true, address(NON_FUNGIBLE_POSITION_MANAGER));
        emit IncreaseLiquidity(tokenId, liquidity, estimatedAmount0, estimatedAmount1);
        NON_FUNGIBLE_POSITION_MANAGER.mint(mintParams);

        // Get estimate value
        INonfungiblePositionManager.IncreaseLiquidityParams memory increaseParams = INonfungiblePositionManager
            .IncreaseLiquidityParams({
                tokenId: tokenId,
                amount0Desired: amountIn0,
                amount1Desired: amountIn1,
                amount0Min: 0,
                amount1Min: 0,
                deadline: block.timestamp
            });
        (, returnData) = _callStatic(
            user,
            address(NON_FUNGIBLE_POSITION_MANAGER),
            abi.encodeWithSelector(NON_FUNGIBLE_POSITION_MANAGER.increaseLiquidity.selector, increaseParams)
        );
        uint128 increasedLiquidity;
        (increasedLiquidity, estimatedAmount0, estimatedAmount1) = abi.decode(returnData, (uint128, uint256, uint256));

        // Encode permit2Datas
        bytes[] memory datas = new bytes[](2);
        datas[0] = dataERC20Permit2PullToken(tokenIn0, amountIn0.toUint160());
        datas[1] = dataERC20Permit2PullToken(tokenIn1, amountIn1.toUint160());

        // Encode logics
        DataType.Logic[] memory logics = new DataType.Logic[](1);
        logics[0] = _logicUniswapV3IncreaseLiquidity(tokenIn0, tokenIn1, amountIn0, amountIn1, increaseParams);

        address[] memory tokensReturn = new address[](2);
        tokensReturn[0] = address(tokenIn0);
        tokensReturn[1] = address(tokenIn1);

        // Execute
        vm.prank(user);
        vm.expectEmit(true, true, true, true, address(NON_FUNGIBLE_POSITION_MANAGER));
        emit IncreaseLiquidity(tokenId, increasedLiquidity, estimatedAmount0, estimatedAmount1);
        router.execute(datas, logics, tokensReturn);

        // Verify
        assertEq(tokenIn0.balanceOf(address(router)), 0);
        assertEq(tokenIn0.balanceOf(address(agent)), 0);
        assertEq(tokenIn1.balanceOf(address(router)), 0);
        assertEq(tokenIn1.balanceOf(address(agent)), 0);
    }

    function testExecuteUniswapV3RemoveLiquidityAndCollect(uint256 amountIn0, uint256 amountIn1) external {
        tokenIn0 = USDC;
        tokenIn1 = USDT;
        amountIn0 = bound(amountIn0, 1e6, 1e10);
        amountIn1 = bound(amountIn0, 1e6, 1e10);
        deal(address(tokenIn0), user, amountIn0);
        deal(address(tokenIn1), user, amountIn1);

        // mint NFT
        int24 tickLower = -275480; // min price
        int24 tickUpper = -275450; // max price
        INonfungiblePositionManager.MintParams memory mintParams = INonfungiblePositionManager.MintParams({
            token0: address(tokenIn0),
            token1: address(tokenIn1),
            fee: 500,
            tickLower: tickLower,
            tickUpper: tickUpper,
            amount0Desired: amountIn0,
            amount1Desired: amountIn1,
            amount0Min: 0,
            amount1Min: 0,
            recipient: user,
            deadline: block.timestamp
        });
        vm.startPrank(user);
        tokenIn0.safeApprove(address(NON_FUNGIBLE_POSITION_MANAGER), type(uint256).max);
        tokenIn1.safeApprove(address(NON_FUNGIBLE_POSITION_MANAGER), type(uint256).max);
        vm.stopPrank();
        (, bytes memory returnData) = _callStatic(
            user,
            address(NON_FUNGIBLE_POSITION_MANAGER),
            abi.encodeWithSelector(NON_FUNGIBLE_POSITION_MANAGER.mint.selector, mintParams)
        );
        uint256 estimatedAmount0;
        uint256 estimatedAmount1;
        (tokenId, liquidity, estimatedAmount0, estimatedAmount1) = abi.decode(
            returnData,
            (uint256, uint128, uint256, uint256)
        );
        vm.prank(user);
        vm.expectEmit(true, true, true, true, address(NON_FUNGIBLE_POSITION_MANAGER));
        emit IncreaseLiquidity(tokenId, liquidity, estimatedAmount0, estimatedAmount1);
        NON_FUNGIBLE_POSITION_MANAGER.mint(mintParams);

        // Prepare decreased action parameter
        uint128 decreasedLiquidity = liquidity / 2;
        INonfungiblePositionManager.DecreaseLiquidityParams memory decreaseParams = INonfungiblePositionManager
            .DecreaseLiquidityParams({
                tokenId: tokenId,
                liquidity: decreasedLiquidity,
                amount0Min: 0,
                amount1Min: 0,
                deadline: block.timestamp
            });

        // Approve nft to agent
        vm.prank(user);
        NON_FUNGIBLE_POSITION_MANAGER.setApprovalForAll(address(agent), true);

        // Encode logics
        DataType.Logic[] memory logics = new DataType.Logic[](1);
        logics[0] = _logicUniswapV3DecreaseLiquidity(decreaseParams);

        // Get Estimate result
        (, returnData) = _callStatic(
            user,
            address(NON_FUNGIBLE_POSITION_MANAGER),
            abi.encodeWithSelector(NON_FUNGIBLE_POSITION_MANAGER.decreaseLiquidity.selector, decreaseParams)
        );
        (estimatedAmount0, estimatedAmount1) = abi.decode(returnData, (uint256, uint256));

        // Execute remove liquidity action
        vm.prank(user);
        vm.expectEmit(true, true, true, true, address(NON_FUNGIBLE_POSITION_MANAGER));
        emit DecreaseLiquidity(tokenId, decreasedLiquidity, estimatedAmount0, estimatedAmount1);
        router.execute(permit2DatasEmpty, logics, tokensReturnEmpty);

        // Verify
        assertEq(tokenIn0.balanceOf(address(router)), 0);
        assertEq(tokenIn0.balanceOf(address(agent)), 0);
        assertEq(tokenIn1.balanceOf(address(router)), 0);
        assertEq(tokenIn1.balanceOf(address(agent)), 0);
        assertEq(NON_FUNGIBLE_POSITION_MANAGER.ownerOf(tokenId), user);

        // Get estimated collect amount
        INonfungiblePositionManager.CollectParams memory collectParams = INonfungiblePositionManager.CollectParams({
            tokenId: tokenId,
            recipient: user,
            amount0Max: type(uint128).max,
            amount1Max: type(uint128).max
        });
        (, returnData) = _callStatic(
            user,
            address(NON_FUNGIBLE_POSITION_MANAGER),
            abi.encodeWithSelector(NON_FUNGIBLE_POSITION_MANAGER.collect.selector, collectParams)
        );
        (uint256 collectAmount0, uint256 collectAmount1) = abi.decode(returnData, (uint256, uint256));

        // Prepare collect action
        logics[0] = _logicUniswapV3Collect(collectParams);
        address[] memory tokensReturn = new address[](2);
        tokensReturn[0] = address(tokenIn0);
        tokensReturn[1] = address(tokenIn1);

        // Execute collect action
        userToken0Before = tokenIn0.balanceOf(user);
        userToken1Before = tokenIn1.balanceOf(user);
        vm.prank(user);
        router.execute(permit2DatasEmpty, logics, tokensReturn);

        // Verify result of collect action
        assertEq(tokenIn0.balanceOf(address(router)), 0);
        assertEq(tokenIn0.balanceOf(address(agent)), 0);
        assertEq(tokenIn1.balanceOf(address(router)), 0);
        assertEq(tokenIn1.balanceOf(address(agent)), 0);
        assertEq(NON_FUNGIBLE_POSITION_MANAGER.ownerOf(tokenId), user);
        assertEq(tokenIn0.balanceOf(user) - userToken0Before, collectAmount0);
        assertEq(tokenIn1.balanceOf(user) - userToken1Before, collectAmount1);
    }

    function _logicUniswapV3MintLiquidityNFT(
        IERC20 token0,
        IERC20 token1,
        uint256 amountIn0,
        uint256 amountIn1,
        INonfungiblePositionManager.MintParams memory params
    ) public pure returns (DataType.Logic memory) {
        // Encode data
        bytes memory data = abi.encodeWithSelector(NON_FUNGIBLE_POSITION_MANAGER.mint.selector, params);

        // Encode inputs
        DataType.Input[] memory inputs = new DataType.Input[](2);
        inputs[0].token = address(token0);
        inputs[1].token = address(token1);
        inputs[0].balanceBps = BPS_NOT_USED;
        inputs[1].balanceBps = BPS_NOT_USED;
        inputs[0].amountOrOffset = amountIn0;
        inputs[1].amountOrOffset = amountIn1;

        return
            DataType.Logic(
                address(NON_FUNGIBLE_POSITION_MANAGER), // to
                data,
                inputs,
                DataType.WrapMode.NONE,
                address(0), // approveTo
                address(0) // callback
            );
    }

    function _logicUniswapV3IncreaseLiquidity(
        IERC20 token0,
        IERC20 token1,
        uint256 amountIn0,
        uint256 amountIn1,
        INonfungiblePositionManager.IncreaseLiquidityParams memory params
    ) public pure returns (DataType.Logic memory) {
        // Encode data
        bytes memory data = abi.encodeWithSelector(NON_FUNGIBLE_POSITION_MANAGER.increaseLiquidity.selector, params);

        // Encode inputs
        DataType.Input[] memory inputs = new DataType.Input[](2);
        inputs[0].token = address(token0);
        inputs[1].token = address(token1);
        inputs[0].balanceBps = BPS_NOT_USED;
        inputs[1].balanceBps = BPS_NOT_USED;
        inputs[0].amountOrOffset = amountIn0;
        inputs[1].amountOrOffset = amountIn1;

        return
            DataType.Logic(
                address(NON_FUNGIBLE_POSITION_MANAGER), // to
                data,
                inputs,
                DataType.WrapMode.NONE,
                address(0), // approveTo
                address(0) // callback
            );
    }

    function _logicUniswapV3DecreaseLiquidity(
        INonfungiblePositionManager.DecreaseLiquidityParams memory params
    ) public view returns (DataType.Logic memory) {
        // Encode data
        bytes memory data = abi.encodeWithSelector(NON_FUNGIBLE_POSITION_MANAGER.decreaseLiquidity.selector, params);
        return
            DataType.Logic(
                address(NON_FUNGIBLE_POSITION_MANAGER), // to
                data,
                inputsEmpty,
                DataType.WrapMode.NONE,
                address(0), // approveTo
                address(0) // callback
            );
    }

    function _logicUniswapV3Collect(
        INonfungiblePositionManager.CollectParams memory params
    ) public view returns (DataType.Logic memory) {
        // Encode data
        bytes memory data = abi.encodeWithSelector(NON_FUNGIBLE_POSITION_MANAGER.collect.selector, params);
        return
            DataType.Logic(
                address(NON_FUNGIBLE_POSITION_MANAGER), // to
                data,
                inputsEmpty,
                DataType.WrapMode.NONE,
                address(0), // approveTo
                address(0) // callback
            );
    }

    function _callStatic(
        address executor,
        address to,
        bytes memory data
    ) public returns (bool isSuccess, bytes memory returnData) {
        uint256 id = vm.snapshot();
        vm.prank(executor);
        (isSuccess, returnData) = to.call(data);
        vm.revertTo(id);
    }
}
