// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {IERC20} from 'openzeppelin-contracts/contracts/token/ERC20/IERC20.sol';
import {Router, IRouter} from 'src/Router.sol';
import {MakerDrawFeeCalculator} from 'src/fees/MakerDrawFeeCalculator.sol';
import {IParam} from 'src/interfaces/IParam.sol';
import {IAgent} from 'src/interfaces/IAgent.sol';
import {IFeeCalculator} from 'src/interfaces/IFeeCalculator.sol';
import {IDSProxy} from 'src/interfaces/maker/IDSProxy.sol';
import {FeeCalculatorUtils, IFeeBase} from 'test/utils/FeeCalculatorUtils.sol';
import {MakerCommonUtils, IDSProxyRegistry} from 'test/utils/MakerCommonUtils.sol';

contract MakerDrawFeeCalculatorTest is Test, FeeCalculatorUtils, MakerCommonUtils {
    address public constant NATIVE = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address public constant DUMMY_TO_ADDRESS = address(0);
    bytes4 public constant DSPROXY_EXECUTE_SELECTOR = bytes4(keccak256(bytes('execute(address,bytes)')));
    uint256 public constant ETH_LOCK_AMOUNT = 2000 ether;
    uint256 public constant DRAW_DAI_AMOUNT = 20000 ether;
    uint256 public constant DRAW_DATA_START_INDEX = 104;
    uint256 public constant DRAW_DATA_END_INDEX = 264;
    uint256 public constant SIGNER_REFERRAL = 1;

    address public user;
    address public userDSProxy;
    address public feeCollector;
    IRouter public router;
    IAgent public userAgent;
    address public userAgentDSProxy;
    IFeeCalculator public makerDrawFeeCalculator;
    uint256 public ethCdp;

    // Empty arrays
    address[] public tokensReturnEmpty;
    IParam.Input[] public inputsEmpty;
    IParam.Fee[] public feesEmpty;

    function setUp() external {
        user = makeAddr('User');
        feeCollector = makeAddr('FeeCollector');
        address pauser = makeAddr('Pauser');

        // Depoly contracts
        router = new Router(makeAddr('WrappedNative'), pauser, feeCollector);
        vm.prank(user);
        userAgent = IAgent(router.newAgent());
        makerDrawFeeCalculator = new MakerDrawFeeCalculator(address(router), ZERO_FEE_RATE, DAI_TOKEN);

        // Setup maker vault
        vm.startPrank(user);
        userDSProxy = IDSProxyRegistry(PROXY_REGISTRY).build();

        // Open ETH Vault
        deal(user, ETH_LOCK_AMOUNT);
        bytes32 ret = IDSProxy(userDSProxy).execute{value: ETH_LOCK_AMOUNT}(
            PROXY_ACTIONS,
            abi.encodeWithSelector(
                0xe685cc04, // selector of "openLockETHAndDraw(address,address,address,address,bytes32,uint256)"
                CDP_MANAGER,
                JUG,
                ETH_JOIN_A,
                DAI_JOIN,
                bytes32(bytes(ETH_JOIN_NAME)),
                DRAW_DAI_AMOUNT
            )
        );
        ethCdp = uint256(ret);
        assertEq(IERC20(DAI_TOKEN).balanceOf(user), DRAW_DAI_AMOUNT);

        // Build user agent's DSProxy
        router.execute(_logicBuildDSProxy(), feesEmpty, new address[](0), SIGNER_REFERRAL);
        userAgentDSProxy = IDSProxyRegistry(PROXY_REGISTRY).proxies(address(userAgent));

        vm.stopPrank();

        // Setup fee calculator
        IParam.FeeCalculator[] memory feeCalculators = new IParam.FeeCalculator[](1);
        feeCalculators[0] = IParam.FeeCalculator({
            selector: DSPROXY_EXECUTE_SELECTOR,
            to: address(DUMMY_TO_ADDRESS),
            calculator: address(makerDrawFeeCalculator)
        });
        router.setFeeCalculators(feeCalculators);

        _allowCdp(user, userDSProxy, ethCdp, userAgentDSProxy);

        vm.label(address(router), 'Router');
        vm.label(address(userAgent), 'UserAgent');
        vm.label(feeCollector, 'FeeCollector');
        vm.label(address(makerDrawFeeCalculator), 'MakerDrawFeeCalculator');

        _makerCommonSetUp();
    }

    function testChargeZeroDrawFee(uint256 amount) external {
        // ETH_LOCK_AMOUNT * price(assume ETH price is 1000) * 60%(LTV)
        uint256 estimateDaiDrawMaxAmount = (ETH_LOCK_AMOUNT * 1000 * 60) / 100;
        amount = bound(amount, 1, estimateDaiDrawMaxAmount);
        uint256 feeRate = 0;

        _executeAndVerify(amount, feeRate);
    }

    function testChargeDrawFee(uint256 amount, uint256 feeRate) external {
        // ETH_LOCK_AMOUNT * price(assume ETH price is 1000) * 60%(LTV)
        uint256 estimateDaiDrawMaxAmount = (ETH_LOCK_AMOUNT * 1000 * 60) / 100;
        amount = bound(amount, 1, estimateDaiDrawMaxAmount);
        feeRate = bound(feeRate, 1, BPS_BASE - 1);

        // Set fee rate
        IFeeBase(address(makerDrawFeeCalculator)).setFeeRate(feeRate);

        _executeAndVerify(amount, feeRate);
    }

    // Should be no impact on other maker action
    function testOtherAction() external {
        // Setup
        uint256 freeETHAmount = 1 ether;
        uint256 userEthBalanceBefore = user.balance;
        uint256 feeCollectorEthBalanceBefore = feeCollector.balance;

        // Encode logic
        IParam.Logic[] memory logics = new IParam.Logic[](1);
        logics[0] = _logicFreeETH(userAgentDSProxy, ethCdp, freeETHAmount);

        // Get new logics
        IParam.Fee[] memory fees;
        (logics, fees, ) = router.getLogicsAndFees(logics, 0);

        // Execute
        address[] memory tokensReturns = new address[](1);
        tokensReturns[0] = address(NATIVE);
        vm.prank(user);
        router.execute(logics, fees, tokensReturns, SIGNER_REFERRAL);

        assertEq(address(router).balance, 0);
        assertEq(address(userAgent).balance, 0);
        assertEq(user.balance - userEthBalanceBefore, freeETHAmount);
        assertEq(feeCollector.balance - feeCollectorEthBalanceBefore, 0);
    }

    function decodeDrawAmount(IParam.Logic calldata logic) external pure returns (uint256) {
        bytes calldata data = logic.data;
        (, , , , uint256 amount) = abi.decode(
            data[DRAW_DATA_START_INDEX:DRAW_DATA_END_INDEX],
            (address, address, address, uint256, uint256)
        );

        return amount;
    }

    function _executeAndVerify(uint256 amount, uint256 feeRate) internal {
        // Encode logic
        IParam.Logic[] memory logics = new IParam.Logic[](1);
        logics[0] = _logicDraw(ethCdp, amount);

        // Get new logics
        IParam.Fee[] memory fees;
        (logics, fees, ) = router.getLogicsAndFees(logics, 0);

        // Prepare assert data
        uint256 expectedNewAmount = _calculateAmountWithFee(amount, feeRate);
        uint256 expectedFee = _calculateFee(expectedNewAmount, feeRate);
        uint256 newAmount = this.decodeDrawAmount(logics[0]);
        uint256 userDaiBalanceBefore = IERC20(DAI_TOKEN).balanceOf(user);
        uint256 feeCollectorBalanceBefore = IERC20(DAI_TOKEN).balanceOf(feeCollector);

        // Execute
        address[] memory tokensReturn = new address[](1);
        tokensReturn[0] = address(DAI_TOKEN);
        vm.prank(user);
        router.execute(logics, fees, tokensReturn, SIGNER_REFERRAL);

        assertEq(IERC20(DAI_TOKEN).balanceOf(address(router)), 0);
        assertEq(IERC20(DAI_TOKEN).balanceOf(address(userAgent)), 0);
        assertEq(IERC20(DAI_TOKEN).balanceOf(feeCollector) - feeCollectorBalanceBefore, expectedFee);
        assertEq(IERC20(DAI_TOKEN).balanceOf(user) - userDaiBalanceBefore, amount);
        assertEq(newAmount, expectedNewAmount);
    }

    function _logicBuildDSProxy() internal view returns (IParam.Logic[] memory) {
        IParam.Logic[] memory logics = new IParam.Logic[](1);
        logics[0] = IParam.Logic(
            PROXY_REGISTRY,
            abi.encodeWithSelector(IDSProxyRegistry.build.selector),
            inputsEmpty,
            IParam.WrapMode.NONE,
            address(0),
            address(0)
        );

        return logics;
    }

    function _logicDraw(uint256 cdp, uint256 amount) internal view returns (IParam.Logic memory) {
        // Prepare datas
        bytes memory data = abi.encodeWithSelector(
            IDSProxy.execute.selector,
            PROXY_ACTIONS,
            abi.encodeWithSelector(
                0x9f6f3d5b, // selector of "draw(address,address,address,uint256,uint256)"
                CDP_MANAGER,
                JUG,
                DAI_JOIN,
                cdp,
                amount
            )
        );

        return
            IParam.Logic(
                userAgentDSProxy,
                data,
                inputsEmpty,
                IParam.WrapMode.NONE,
                address(0), // approveTo
                address(0) // callback
            );
    }

    function _logicFreeETH(address dsProxy, uint256 cdp, uint256 amount) internal view returns (IParam.Logic memory) {
        // Prepare data
        bytes memory data = abi.encodeWithSelector(
            IDSProxy.execute.selector,
            PROXY_ACTIONS,
            abi.encodeWithSelector(
                0x7b5a3b43, // selector of "freeETH(address,address,uint256,uint256)"
                CDP_MANAGER,
                ETH_JOIN_A,
                cdp,
                amount
            )
        );

        return
            IParam.Logic(
                dsProxy,
                data,
                inputsEmpty,
                IParam.WrapMode.NONE,
                address(0), // approveTo
                address(0) // callback
            );
    }
}
