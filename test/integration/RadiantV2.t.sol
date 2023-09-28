// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {SafeERC20, IERC20} from 'lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol';
import {IAgent} from 'src/interfaces/IAgent.sol';
import {Router, IRouter} from 'src/Router.sol';
import {DataType} from 'src/libraries/DataType.sol';
import {IAaveV2Provider} from 'src/interfaces/aaveV2/IAaveV2Provider.sol';
import {IAaveV2FlashLoanCallback} from 'src/callbacks/AaveV2FlashLoanCallback.sol';
import {RadiantV2FlashLoanCallback} from 'src/callbacks/RadiantV2FlashLoanCallback.sol';

interface IRadiantV2Pool {
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

contract RadiantV2IntegrationTest is Test {
    using SafeERC20 for IERC20;

    enum InterestRateMode {
        NONE,
        STABLE,
        VARIABLE
    }

    IAaveV2Provider public constant RADIANT_V2_PROVIDER = IAaveV2Provider(0x091d52CacE1edc5527C99cDCFA6937C1635330E4);
    IERC20 public constant USDC = IERC20(0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8);
    address public constant RUSDC_V2 = 0x48a29E756CC1C097388f3B2f3b570ED270423b3d;
    address internal constant permit2Addr = address(0x000000000022D473030F116dDEE9F6B43aC78BA3);

    address public user;
    IRouter public router;
    IAgent public agent;
    IAaveV2FlashLoanCallback public flashLoanCallback;
    IRadiantV2Pool public pool;

    // Empty arrays
    address[] public tokensReturnEmpty;
    DataType.Input[] public inputsEmpty;
    bytes[] public permit2DatasEmpty;

    function setUp() external {
        vm.createSelectFork(vm.rpcUrl('arbitrum'));

        user = makeAddr('User');
        router = new Router(makeAddr('WrappedNative'), permit2Addr, address(this));
        vm.prank(user);
        agent = IAgent(router.newAgent());
        flashLoanCallback = new RadiantV2FlashLoanCallback(address(router), address(RADIANT_V2_PROVIDER), 0);
        pool = IRadiantV2Pool(IAaveV2Provider(RADIANT_V2_PROVIDER).getLendingPool());

        vm.label(address(router), 'Router');
        vm.label(address(agent), 'Agent');
        vm.label(address(RADIANT_V2_PROVIDER), 'RadiantV2Provider');
        vm.label(address(pool), 'RadiantV2Pool');
        vm.label(address(USDC), 'USDC');
        vm.label(address(RUSDC_V2), 'rUSDC');
    }

    function testExecuteRadiantV2FlashLoan(uint256 amount) external {
        IERC20 borrowedToken = USDC;
        address flashloanPool = RUSDC_V2;
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
        logics[0] = _logicRadiantV2FlashLoan(tokens, amounts, modes);

        // Execute
        vm.prank(user);
        router.execute(permit2DatasEmpty, logics, tokensReturnEmpty);

        assertEq(borrowedToken.balanceOf(address(router)), 0);
        assertEq(borrowedToken.balanceOf(address(agent)), 0);
        assertEq(borrowedToken.balanceOf(address(flashLoanCallback)), 0);
        assertEq(borrowedToken.balanceOf(user), 0);
    }

    function _logicRadiantV2FlashLoan(
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
                    IRadiantV2Pool.flashLoan.selector,
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
        for (uint256 i = 0; i < tokens.length; ++i) {
            // Airdrop fee to Agent
            uint256 fee = (amounts[i] * 9) / 10000;
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
}
