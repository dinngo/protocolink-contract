// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {SafeERC20, IERC20} from 'openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol';
import {SafeCast160} from 'permit2/libraries/SafeCast160.sol';
import {IAgent2} from 'src/interfaces/IAgent2.sol';
import {Router2, IRouter2} from 'src/Router2.sol';
import {IParam2} from 'src/interfaces/IParam2.sol';
import {ERC20Permit2Utils} from '../utils/ERC20Permit2Utils.sol';
import {IAaveV3Provider} from 'src/interfaces/aaveV3/IAaveV3Provider.sol';
import {AaveV3FlashLoanCallback, IAaveV3FlashLoanCallback} from 'src/callbacks/AaveV3FlashLoanCallback.sol';
import 'forge-std/console.sol';

interface IUniswapV2Factory {
    function getPair(address tokenA, address tokenB) external view returns (address pair);
}

interface IUniswapV2Router02 {
    function factory() external view returns (address);

    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB, uint256 liquidity);

    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB);
}

interface IDebtToken {
    function UNDERLYING_ASSET_ADDRESS() external view returns (address);

    function approveDelegation(address delegatee, uint256 amount) external;

    function totalSupply() external view returns (uint256);
}

interface IAaveV3Pool {
    function FLASHLOAN_PREMIUM_TOTAL() external view returns (uint128);

    function supply(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external;

    function borrow(
        address asset,
        uint256 amount,
        uint256 interestRateMode,
        uint16 referralCode,
        address onBehalfOf
    ) external;

    function flashLoan(
        address receiverAddress,
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata interestRateModes,
        address onBehalfOf,
        bytes calldata params,
        uint16 referralCode
    ) external;
}

interface IYVault {
    function deposit(uint256) external;

    function balanceOf(address) external returns (uint256);
}

// Test Uniswap whose Router2 is not ERC20-compliant token
contract MultiAction2Test is Test, ERC20Permit2Utils {
    using SafeERC20 for IERC20;
    using SafeCast160 for uint256;

    address public constant NATIVE = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    IERC20 public constant WRAPPED_NATIVE = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IERC20 public constant USDT = IERC20(0xdAC17F958D2ee523a2206206994597C13D831ec7);
    IERC20 public constant USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    IUniswapV2Router02 public constant uniswapRouter02 = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
    uint16 public constant BPS_BASE = 10_000;
    uint16 internal constant _BPS_SKIP = 0;
    // uint256 public constant SKIP = 0x8000000000000000000000000000000000000000000000000000000000000000;
    bytes32 internal constant REPLACE_MASK_ = 0x0000000000000000000000000000000000000000000000000000000000000001;

    bytes32 internal constant WRAP_MASK_ = 0x0000000000000000000000000000000000000000000000000000000000000001;
    bytes32 internal constant UNWRAP_MASK_ = 0x0000000000000000000000000000000000000000000000000000000000000002;

    // AaveV3 Setup
    enum InterestRateMode {
        NONE,
        STABLE,
        VARIABLE
    }
    uint16 internal constant _REFERRAL_CODE = 56;
    // uint256 public constant SIGNER_REFERRAL = 1;
    IAaveV3Provider public constant AAVE_V3_PROVIDER = IAaveV3Provider(0x2f39d218133AFaB8F2B819B1066c7E434Ad94E9e);
    address public constant AUSDC_V3 = 0x98C23E9d8f34FEFb1B7BD6a91B7FF122F4e16F5c;
    IERC20 public constant AUSDC = IERC20(AUSDC_V3);
    IDebtToken public constant AUSDC_V3_DEBT_VARIABLE = IDebtToken(0x72E95b8931767C79bA4EeE721354d6E99a61D004);
    IAaveV3FlashLoanCallback public flashLoanCallback;
    IAaveV3Pool public aaveV3pool;

    // Yearn Setup
    IYVault public constant yVault = IYVault(0x2f08119C6f07c006695E079AAFc638b8789FAf18); // yUSDT

    // Global Setup
    address public user;
    uint256 public userPrivateKey;
    IRouter2 public router;
    IAgent2 public agent;

    // Empty arrays
    IParam2.Input[] public inputsEmpty;
    address[] public tokensReturnEmpty;

    function setUp() external {
        (user, userPrivateKey) = makeAddrAndKey('User');
        router = new Router2(address(WRAPPED_NATIVE), address(this), makeAddr('Pauser'), makeAddr('FeeCollector'));
        vm.prank(user);
        agent = IAgent2(router.newAgent());

        // User permit token
        erc20Permit2UtilsSetUp(user, userPrivateKey, address(agent));
        permitToken(USDT);
        permitToken(USDC);

        // AAVE Setup
        flashLoanCallback = new AaveV3FlashLoanCallback(address(router), address(AAVE_V3_PROVIDER));
        vm.startPrank(user);
        AUSDC_V3_DEBT_VARIABLE.approveDelegation(address(agent), type(uint256).max);
        vm.stopPrank();
        aaveV3pool = IAaveV3Pool(IAaveV3Provider(AAVE_V3_PROVIDER).getPool());

        // Empty router the balance
        vm.prank(address(router));
        (bool success, ) = payable(address(0)).call{value: address(router).balance}('');
        assertTrue(success);

        vm.label(address(router), 'Router2');
        vm.label(address(agent), 'Agent');
        vm.label(NATIVE, 'NATIVE');
        vm.label(address(WRAPPED_NATIVE), 'WrappedNative');
        vm.label(address(USDT), 'USDT');
        vm.label(address(USDC), 'USDC');
        vm.label(address(uniswapRouter02), 'uniswapRouter02');
        vm.label(address(AAVE_V3_PROVIDER), 'AaveV3Provider');
        vm.label(address(aaveV3pool), 'AaveV3Pool');
        vm.label(address(AUSDC_V3), 'aUSDC');
        vm.label(address(AUSDC_V3_DEBT_VARIABLE), 'variableDebtUSDC');
    }

    function testExecuteMultiActionNativeToToken(uint256 amountIn) external {
        // 1. UniswapV2 Swap
        // 2. AAVE Supply
        // 3. AAVE Borrow
        // 4. WrappedNative
        // 5. Deposit YearnV2

        IERC20 firstTokenIn = WRAPPED_NATIVE;
        IERC20 firstTokenOut = USDC;
        uint256 firstAmountIn = bound(amountIn, 1e19, 1e22);
        deal(user, firstAmountIn);

        // Encode logics
        IParam2.Logic[] memory logics = new IParam2.Logic[](4);
        logics[0] = _logicUniswapV2Swap(firstTokenIn, firstAmountIn, _BPS_SKIP, firstTokenOut, true); // Fixed amount
        logics[1] = _logicAaveV3Supply(firstTokenOut, BPS_BASE, 32);
        logics[2] = _logicAaveV3Borrow(USDT, 1e10, uint256(InterestRateMode.VARIABLE));
        logics[3] = _logicYearn(USDT, 0, BPS_BASE);

        // Execute
        address[] memory tokensReturn = new address[](1);
        tokensReturn[0] = address(yVault);
        vm.prank(user);
        router.execute{value: firstAmountIn}(logics, tokensReturn, SIGNER_REFERRAL);
        assertGt(yVault.balanceOf(user), 0);
    }

    function _logicUniswapV2Swap(
        IERC20 tokenIn,
        uint256 amountIn,
        uint16 amountBps,
        IERC20 tokenOut,
        bool isWrapMode
    ) public view returns (IParam2.Logic memory) {
        // Encode data
        address[] memory path = new address[](2);
        path[0] = address(tokenIn);
        path[1] = address(tokenOut);
        uint256[] memory amountsOut = uniswapRouter02.getAmountsOut(amountIn, path);
        uint256 amountMin = (amountsOut[1] * 9_900) / BPS_BASE;
        bytes memory data = abi.encodeWithSelector(
            uniswapRouter02.swapExactTokensForTokens.selector,
            (amountBps == _BPS_SKIP) ? amountIn : 0, // 0 is the amount which will be repalced
            amountMin, // amountOutMin
            path, // path
            address(agent), // to
            block.timestamp // deadline
        );

        // Encode inputs
        IParam2.Input[] memory inputs = new IParam2.Input[](1);
        inputs[0] = _buildInput(tokenIn, amountBps, amountIn, false);

        bytes32 metadata = _buildLogicMetadata(address(0), isWrapMode, false);

        return
            IParam2.Logic(
                address(uniswapRouter02), // to
                data,
                inputs,
                address(0), // callback
                metadata
            );
    }

    function _logicAaveV3Supply(
        IERC20 tokenIn,
        uint16 amountBps,
        uint256 amountIn
    ) public view returns (IParam2.Logic memory) {
        // Encode inputs
        IParam2.Input[] memory inputs = new IParam2.Input[](1);
        // inputs[0] = IParam2.Input(address(tokenIn), amountBps, amountIn);

        inputs[0] = _buildInput(tokenIn, amountBps, amountIn, true);
        bytes32 metadata = _buildLogicMetadata(address(0), false, false);

        return
            IParam2.Logic(
                address(aaveV3pool), // to
                abi.encodeWithSelector(
                    IAaveV3Pool.supply.selector,
                    address(tokenIn),
                    amountBps,
                    address(agent),
                    _REFERRAL_CODE
                ),
                inputs,
                address(0), // callback
                metadata
            );
    }

    function _logicAaveV3Borrow(
        IERC20 token,
        uint256 amount,
        uint256 interestRateMode
    ) public view returns (IParam2.Logic memory) {
        bytes32 metadata = _buildLogicMetadata(address(0), false, false);
        return
            IParam2.Logic(
                address(aaveV3pool), // to
                abi.encodeWithSelector(
                    IAaveV3Pool.borrow.selector,
                    token,
                    amount,
                    interestRateMode,
                    _REFERRAL_CODE,
                    address(agent)
                ),
                inputsEmpty,
                address(0), // callback
                metadata
            );
    }

    function _logicYearn(
        IERC20 tokenIn,
        uint256 amountIn,
        uint16 amountBps
    ) public pure returns (IParam2.Logic memory) {
        // Encode inputs
        IParam2.Input[] memory inputs = new IParam2.Input[](1);
        // inputs[0].token = address(tokenIn);
        // inputs[0].amountBps = amountBps;
        // if (inputs[0].amountBps == SKIP) inputs[0].amountOrOffset = amountIn;
        // else inputs[0].amountOrOffset = 0;

        inputs[0] = _buildInput(tokenIn, amountBps, 0, true);
        bytes32 metadata = _buildLogicMetadata(address(0), false, false);

        return
            IParam2.Logic(
                address(yVault), // to
                abi.encodeWithSelector(yVault.deposit.selector, 0), // amount will be replaced with balance
                inputs,
                address(0), // callback
                metadata
            );
    }

    function _buildInput(
        IERC20 tokenIn,
        uint16 amountBps,
        uint256 amountIn,
        bool replaced
    ) public pure returns (IParam2.Input memory) {
        // Encode inputs
        bytes32 tokenMetadata = bytes32(bytes20(address(tokenIn))) | (bytes32(uint256(amountBps) << 80));
        if (replaced) {
            tokenMetadata = tokenMetadata | REPLACE_MASK_;
        }
        return IParam2.Input(tokenMetadata, amountIn);
    }

    function _buildLogicMetadata(address approveTo, bool wrap, bool unWrap) public pure returns (bytes32 metadata) {
        if (approveTo != address(0)) {
            metadata = metadata | bytes32(bytes20(address(approveTo)));
        }

        if (wrap) {
            metadata = metadata | WRAP_MASK_;
        }

        if (unWrap) {
            metadata = metadata | UNWRAP_MASK_;
        }
    }
}
