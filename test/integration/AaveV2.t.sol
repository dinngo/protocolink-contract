// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {SafeERC20, IERC20} from 'openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol';
import {IAgent} from 'src/interfaces/IAgent.sol';
import {Router, IRouter} from 'src/Router.sol';
import {IParam} from 'src/interfaces/IParam.sol';
import {IAaveV2Provider} from 'src/interfaces/aaveV2/IAaveV2Provider.sol';
import {AaveV2FlashLoanCallback, IAaveV2FlashLoanCallback} from 'src/callbacks/AaveV2FlashLoanCallback.sol';

interface IDebtToken {
    function UNDERLYING_ASSET_ADDRESS() external view returns (address);

    function approveDelegation(address delegatee, uint256 amount) external;

    function totalSupply() external view returns (uint256);
}

interface IAaveV2Pool {
    function deposit(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external;

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
        uint256[] calldata modes,
        address onBehalfOf,
        bytes calldata params,
        uint16 referralCode
    ) external;
}

contract AaveV2IntegrationTest is Test {
    using SafeERC20 for IERC20;

    enum InterestRateMode {
        NONE,
        STABLE,
        VARIABLE
    }

    uint16 internal constant _REFERRAL_CODE = 56;
    uint256 public constant SIGNER_REFERRAL = 1;
    IAaveV2Provider public constant AAVE_V2_PROVIDER = IAaveV2Provider(0xB53C1a33016B2DC2fF3653530bfF1848a515c8c5);
    IERC20 public constant USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    address public constant AUSDC_V2 = 0xBcca60bB61934080951369a648Fb03DF4F96263C;
    IDebtToken public constant AUSDC_V2_DEBT_VARIABLE = IDebtToken(0x619beb58998eD2278e08620f97007e1116D5D25b);
    address internal constant permit2Addr = address(0x000000000022D473030F116dDEE9F6B43aC78BA3);

    address public user;
    IRouter public router;
    IAgent public agent;
    IAaveV2FlashLoanCallback public flashLoanCallback;
    IAaveV2Pool pool = IAaveV2Pool(IAaveV2Provider(AAVE_V2_PROVIDER).getLendingPool());

    // Empty arrays
    address[] public tokensReturnEmpty;
    IParam.Input[] public inputsEmpty;
    bytes[] public permit2DatasEmpty;

    function setUp() external {
        user = makeAddr('User');
        router = new Router(
            makeAddr('WrappedNative'),
            permit2Addr,
            address(this),
            makeAddr('Pauser'),
            makeAddr('FeeCollector')
        );
        vm.prank(user);
        agent = IAgent(router.newAgent());
        flashLoanCallback = new AaveV2FlashLoanCallback(address(router), address(AAVE_V2_PROVIDER), 0);

        // User approved agent aave v2 delegation
        vm.startPrank(user);
        AUSDC_V2_DEBT_VARIABLE.approveDelegation(address(agent), type(uint256).max);
        vm.stopPrank();

        vm.label(address(router), 'Router');
        vm.label(address(agent), 'Agent');
        vm.label(address(AAVE_V2_PROVIDER), 'AaveV2Provider');
        vm.label(address(pool), 'AaveV2Pool');
        vm.label(address(USDC), 'USDC');
        vm.label(address(AUSDC_V2), 'aUSDC');
        vm.label(address(AUSDC_V2_DEBT_VARIABLE), 'variableDebtUSDC');
    }

    function testExecuteAaveV2Borrow(uint256 borrowedAmount) external {
        IDebtToken debtToken = AUSDC_V2_DEBT_VARIABLE;
        IERC20 borrowedToken = IERC20(debtToken.UNDERLYING_ASSET_ADDRESS());
        IERC20 collateralToken = borrowedToken;
        borrowedAmount = bound(borrowedAmount, 1e8, debtToken.totalSupply());
        vm.label(address(borrowedToken), 'Borrowed Token');

        // Setup collateral
        vm.startPrank(user);
        uint256 collateralAmount = borrowedAmount * 3;
        deal(address(collateralToken), user, collateralAmount);
        collateralToken.safeApprove(address(pool), collateralAmount);
        pool.deposit(address(collateralToken), collateralAmount, user, 0);
        vm.stopPrank();

        // Encode logics
        IParam.Logic[] memory logics = new IParam.Logic[](1);
        logics[0] = _logicAaveV2Borrow(borrowedToken, borrowedAmount, uint256(InterestRateMode.VARIABLE));

        // Execute
        address[] memory tokensReturn = new address[](1);
        tokensReturn[0] = address(borrowedToken);
        vm.prank(user);
        router.execute(permit2DatasEmpty, logics, tokensReturn, SIGNER_REFERRAL);

        assertEq(borrowedToken.balanceOf(address(router)), 0);
        assertEq(borrowedToken.balanceOf(address(agent)), 0);
        assertEq(borrowedToken.balanceOf(user), borrowedAmount);
    }

    function testExecuteAaveV2FlashLoan(uint256 amount) external {
        IERC20 borrowedToken = USDC;
        address flashloanPool = AUSDC_V2;
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
        logics[0] = _logicAaveV2FlashLoan(tokens, amounts, modes);

        // Execute
        vm.prank(user);
        router.execute(permit2DatasEmpty, logics, tokensReturnEmpty, SIGNER_REFERRAL);

        assertEq(borrowedToken.balanceOf(address(router)), 0);
        assertEq(borrowedToken.balanceOf(address(agent)), 0);
        assertEq(borrowedToken.balanceOf(address(flashLoanCallback)), 0);
        assertEq(borrowedToken.balanceOf(user), 0);
    }

    function _logicAaveV2Borrow(
        IERC20 token,
        uint256 amount,
        uint256 interestRateMode
    ) public view returns (IParam.Logic memory) {
        return
            IParam.Logic(
                address(pool), // to
                abi.encodeWithSelector(
                    IAaveV2Pool.borrow.selector,
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

    function _logicAaveV2FlashLoan(
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
                    IAaveV2Pool.flashLoan.selector,
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
        for (uint256 i = 0; i < tokens.length; ++i) {
            // Airdrop fee to Agent
            uint256 fee = (amounts[i] * 9) / 10000;
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
}
