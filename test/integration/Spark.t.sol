// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {SafeERC20, IERC20} from 'lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol';
import {IAgent} from 'src/interfaces/IAgent.sol';
import {Router, IRouter} from 'src/Router.sol';
import {DataType} from 'src/libraries/DataType.sol';
import {IAaveV3Provider} from 'src/interfaces/aaveV3/IAaveV3Provider.sol';
import {SparkFlashLoanCallback, IAaveV3FlashLoanCallback} from 'src/callbacks/SparkFlashLoanCallback.sol';

interface ISparkPool {
    function FLASHLOAN_PREMIUM_TOTAL() external view returns (uint128);

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

contract SparkIntegrationTest is Test {
    using SafeERC20 for IERC20;

    enum InterestRateMode {
        NONE,
        STABLE,
        VARIABLE
    }

    IAaveV3Provider public constant SPARK_PROVIDER = IAaveV3Provider(0x02C3eA4e34C0cBd694D2adFa2c690EECbC1793eE);
    IERC20 public constant USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    address public constant AUSDC_V3 = 0x377C3bd93f2a2984E1E7bE6A5C22c525eD4A4815;

    address public user;
    IRouter public router;
    IAgent public agent;
    IAaveV3FlashLoanCallback public flashLoanCallback;
    ISparkPool public pool;

    // Empty arrays
    address[] public tokensReturnEmpty;
    DataType.Input[] public inputsEmpty;
    bytes[] public permit2DatasEmpty;

    function setUp() external {
        vm.createSelectFork(vm.rpcUrl('ethereum'));

        user = makeAddr('User');
        router = new Router(makeAddr('WrappedNative'), makeAddr('Permit2'), address(this));
        vm.prank(user);
        agent = IAgent(router.newAgent());
        flashLoanCallback = new SparkFlashLoanCallback(address(router), address(SPARK_PROVIDER), 0);
        pool = ISparkPool(IAaveV3Provider(SPARK_PROVIDER).getPool());

        vm.label(address(router), 'Router');
        vm.label(address(agent), 'Agent');
        vm.label(address(SPARK_PROVIDER), 'SparkProvider');
        vm.label(address(pool), 'SparkPool');
        vm.label(address(USDC), 'USDC');
        vm.label(address(AUSDC_V3), 'aUSDC');
    }

    function testExecuteSparkFlashLoan(uint256 amount) external {
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
        DataType.Logic[] memory logics = new DataType.Logic[](1);
        logics[0] = _logicSparkFlashLoan(tokens, amounts, modes);

        // Execute
        vm.prank(user);
        router.execute(permit2DatasEmpty, logics, tokensReturnEmpty);

        assertEq(borrowedToken.balanceOf(address(router)), 0);
        assertEq(borrowedToken.balanceOf(address(agent)), 0);
        assertEq(borrowedToken.balanceOf(address(flashLoanCallback)), 0);
        assertEq(borrowedToken.balanceOf(user), 0);
    }

    function _logicSparkFlashLoan(
        address[] memory tokens,
        uint256[] memory amounts,
        uint256[] memory modes
    ) public returns (DataType.Logic memory) {
        // Encode logic
        address receiverAddress = address(flashLoanCallback);
        address onBehalfOf = address(0);
        bytes memory params = _encodeExecute(tokens, amounts);
        uint16 referralCode = 0;

        return
            DataType.Logic(
                address(pool), // to
                abi.encodeWithSelector(
                    ISparkPool.flashLoan.selector,
                    receiverAddress,
                    tokens,
                    amounts,
                    modes,
                    onBehalfOf,
                    params,
                    referralCode
                ),
                inputsEmpty,
                DataType.WrapMode.NONE,
                address(0), // approveTo
                address(flashLoanCallback) // callback
            );
    }

    function _encodeExecute(address[] memory tokens, uint256[] memory amounts) public returns (bytes memory) {
        // Encode logics
        DataType.Logic[] memory logics = new DataType.Logic[](tokens.length);
        uint256 percentage = pool.FLASHLOAN_PREMIUM_TOTAL();

        for (uint256 i = 0; i < tokens.length; ++i) {
            // Airdrop fee to Agent
            uint256 fee = _percentMul(amounts[i], percentage);
            deal(address(tokens[i]), address(agent), fee);

            // Encode transfering token + fee to the flash loan callback
            logics[i] = DataType.Logic(
                address(tokens[i]), // to
                abi.encodeWithSelector(IERC20.transfer.selector, address(flashLoanCallback), amounts[i] + fee),
                inputsEmpty,
                DataType.WrapMode.NONE,
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
