// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {SafeERC20, IERC20} from 'openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol';
import {IAgent} from 'src/interfaces/IAgent.sol';
import {Router, IRouter} from 'src/Router.sol';
import {IParam} from 'src/interfaces/IParam.sol';
import {IAaveV3Provider} from 'src/interfaces/aaveV3/IAaveV3Provider.sol';
import {AaveV3FlashLoanCallback, IAaveV3FlashLoanCallback} from 'src/callbacks/AaveV3FlashLoanCallback.sol';

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

contract AaveV3IntegrationTest is Test {
    using SafeERC20 for IERC20;

    enum InterestRateMode {
        NONE,
        STABLE,
        VARIABLE
    }

    uint16 internal constant _REFERRAL_CODE = 56;
    uint256 public constant SIGNER_REFERRAL = 1;
    IAaveV3Provider public constant AAVE_V3_PROVIDER = IAaveV3Provider(0x2f39d218133AFaB8F2B819B1066c7E434Ad94E9e);
    IERC20 public constant USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    address public constant AUSDC_V3 = 0x98C23E9d8f34FEFb1B7BD6a91B7FF122F4e16F5c;
    IDebtToken public constant AUSDC_V3_DEBT_VARIABLE = IDebtToken(0x72E95b8931767C79bA4EeE721354d6E99a61D004);

    address public user;
    IRouter public router;
    IAgent public agent;
    IAaveV3FlashLoanCallback public flashLoanCallback;
    IAaveV3Pool pool = IAaveV3Pool(IAaveV3Provider(AAVE_V3_PROVIDER).getPool());

    // Empty arrays
    address[] public tokensReturnEmpty;
    IParam.Input[] public inputsEmpty;
    bytes[] public permit2DatasEmpty;

    function setUp() external {
        user = makeAddr('User');
        router = new Router(
            makeAddr('WrappedNative'),
            makeAddr('Permit2'),
            address(this),
            makeAddr('Pauser'),
            makeAddr('FeeCollector')
        );
        vm.prank(user);
        agent = IAgent(router.newAgent());
        flashLoanCallback = new AaveV3FlashLoanCallback(address(router), address(AAVE_V3_PROVIDER), 0);

        // User approved agent aave v3 delegation
        vm.startPrank(user);
        AUSDC_V3_DEBT_VARIABLE.approveDelegation(address(agent), type(uint256).max);
        vm.stopPrank();

        vm.label(address(router), 'Router');
        vm.label(address(agent), 'Agent');
        vm.label(address(AAVE_V3_PROVIDER), 'AaveV3Provider');
        vm.label(address(pool), 'AaveV3Pool');
        vm.label(address(USDC), 'USDC');
        vm.label(address(AUSDC_V3), 'aUSDC');
        vm.label(address(AUSDC_V3_DEBT_VARIABLE), 'variableDebtUSDC');
    }

    function testExecuteAaveV3Borrow(uint256 borrowedAmount) external {
        IDebtToken debtToken = AUSDC_V3_DEBT_VARIABLE;
        IERC20 borrowedToken = IERC20(debtToken.UNDERLYING_ASSET_ADDRESS());
        IERC20 collateralToken = borrowedToken;
        borrowedAmount = bound(borrowedAmount, 1e8, debtToken.totalSupply());
        vm.label(address(borrowedToken), 'Borrowed Token');

        // Setup collateral
        vm.startPrank(user);
        uint256 collateralAmount = borrowedAmount * 3;
        deal(address(collateralToken), user, collateralAmount);
        collateralToken.safeApprove(address(pool), collateralAmount);
        pool.supply(address(collateralToken), collateralAmount, user, 0);
        vm.stopPrank();

        // Encode logics
        IParam.Logic[] memory logics = new IParam.Logic[](1);
        logics[0] = _logicAaveV3Borrow(borrowedToken, borrowedAmount, uint256(InterestRateMode.VARIABLE));

        // Execute
        address[] memory tokensReturn = new address[](1);
        tokensReturn[0] = address(borrowedToken);
        vm.prank(user);
        router.execute(permit2DatasEmpty, logics, tokensReturn, SIGNER_REFERRAL);

        assertEq(borrowedToken.balanceOf(address(router)), 0);
        assertEq(borrowedToken.balanceOf(address(agent)), 0);
        assertEq(borrowedToken.balanceOf(user), borrowedAmount);
    }

    function testExecuteAaveV3FlashLoan(uint256 amount) external {
        IERC20 borrowedToken = USDC;
        address flashloanPool = AUSDC_V3;
        amount = bound(amount, 1e6, borrowedToken.balanceOf(flashloanPool));
        vm.label(address(borrowedToken), 'Borrowed Token');

        address[] memory tokens = new address[](1);
        tokens[0] = address(borrowedToken);

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;

        uint256[] memory modes = new uint256[](1);
        modes[0] = uint256(InterestRateMode.NONE);

        // Encode logics
        IParam.Logic[] memory logics = new IParam.Logic[](1);
        logics[0] = _logicAaveV3FlashLoan(tokens, amounts, modes);

        // Execute
        vm.prank(user);
        router.execute(permit2DatasEmpty, logics, tokensReturnEmpty, SIGNER_REFERRAL);

        assertEq(borrowedToken.balanceOf(address(router)), 0);
        assertEq(borrowedToken.balanceOf(address(agent)), 0);
        assertEq(borrowedToken.balanceOf(address(flashLoanCallback)), 0);
        assertEq(borrowedToken.balanceOf(user), 0);
    }

    function _logicAaveV3Borrow(
        IERC20 token,
        uint256 amount,
        uint256 interestRateMode
    ) public view returns (IParam.Logic memory) {
        return
            IParam.Logic(
                address(pool), // to
                abi.encodeWithSelector(
                    IAaveV3Pool.borrow.selector,
                    token,
                    amount,
                    interestRateMode,
                    _REFERRAL_CODE,
                    user
                ),
                inputsEmpty,
                IParam.WrapMode.NONE,
                address(0), // approveTo
                address(0) // callback
            );
    }

    function _logicAaveV3FlashLoan(
        address[] memory tokens,
        uint256[] memory amounts,
        uint256[] memory modes
    ) public returns (IParam.Logic memory) {
        // Encode logic
        address receiverAddress = address(flashLoanCallback);
        address onBehalfOf = address(0);
        bytes memory params = _encodeExecute(tokens, amounts);
        uint16 referralCode = 0;

        return
            IParam.Logic(
                address(pool), // to
                abi.encodeWithSelector(
                    IAaveV3Pool.flashLoan.selector,
                    receiverAddress,
                    tokens,
                    amounts,
                    modes,
                    onBehalfOf,
                    params,
                    referralCode
                ),
                inputsEmpty,
                IParam.WrapMode.NONE,
                address(0), // approveTo
                address(flashLoanCallback) // callback
            );
    }

    function _encodeExecute(address[] memory tokens, uint256[] memory amounts) public returns (bytes memory) {
        // Encode logics
        IParam.Logic[] memory logics = new IParam.Logic[](tokens.length);
        uint256 percentage = pool.FLASHLOAN_PREMIUM_TOTAL();

        for (uint256 i = 0; i < tokens.length; ++i) {
            // Airdrop fee to Agent
            uint256 fee = _percentMul(amounts[i], percentage);
            deal(address(tokens[i]), address(agent), fee);

            // Encode transfering token + fee to the flash loan callback
            logics[i] = IParam.Logic(
                address(tokens[i]), // to
                abi.encodeWithSelector(IERC20.transfer.selector, address(flashLoanCallback), amounts[i] + fee),
                inputsEmpty,
                IParam.WrapMode.NONE,
                address(0), // approveTo
                address(0) // callback
            );
        }

        // Encode execute data
        return abi.encode(logics);
    }

    function _percentMul(uint256 value, uint256 percentage) internal pure returns (uint256 result) {
        // Fork PercentageMath of AAVEV3.
        // From https://github.com/aave/aave-v3-core/blob/master/contracts/protocol/libraries/math/PercentageMath.sol#L48

        // to avoid overflow, value <= (type(uint256).max - HALF_PERCENTAGE_FACTOR) / percentage
        uint256 PERCENTAGE_FACTOR = 1e4;
        uint256 HALF_PERCENTAGE_FACTOR = 0.5e4;
        assembly {
            if iszero(or(iszero(percentage), iszero(gt(value, div(sub(not(0), HALF_PERCENTAGE_FACTOR), percentage))))) {
                revert(0, 0)
            }

            result := div(add(mul(value, percentage), HALF_PERCENTAGE_FACTOR), PERCENTAGE_FACTOR)
        }
    }
}
