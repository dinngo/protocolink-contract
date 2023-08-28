import {Test} from 'forge-std/Test.sol';
import {SafeERC20, IERC20} from 'openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol';
import {SafeCast160} from 'permit2/libraries/SafeCast160.sol';
import {IAgent} from 'src/interfaces/IAgent.sol';
import {Router, IRouter} from 'src/Router.sol';
import {IParam} from 'src/interfaces/IParam.sol';
import {IComet} from 'src/interfaces/compoundV3/IComet.sol';
import {ERC20Permit2Utils} from '../utils/ERC20Permit2Utils.sol';

import {console2} from 'forge-std/console2.sol';

contract CompoundV3Test is Test, ERC20Permit2Utils {
    using SafeERC20 for IERC20;
    using SafeCast160 for uint256;

    IComet public constant COMET_V3_USDC = IComet(0xF25212E676D1F7F89Cd72fFEe66158f541246445);
    IERC20 public constant USDC = IERC20(0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174);
    IERC20 public constant CUSDC_V3 = IERC20(address(COMET_V3_USDC));

    uint256 public constant BPS_BASE = 10_000;
    uint256 public constant BPS_NOT_USED = 0;

    address public user;
    uint256 public userPrivateKey;
    IRouter public router;
    IAgent public agent;
    IComet public pool = COMET_V3_USDC;

    function setUp() external {
        (user, userPrivateKey) = makeAddrAndKey('User');
        router = new Router(makeAddr('WrappedNative'), address(this), makeAddr('Pauser'), makeAddr('FeeCollector'));
        vm.prank(user);
        agent = IAgent(router.newAgent());

        // User permit token
        erc20Permit2UtilsSetUp(user, userPrivateKey, address(agent));
        permitToken(USDC);
        permitToken(CUSDC_V3);

        vm.label(address(router), 'Router');
        vm.label(address(agent), 'Agent');
        vm.label(address(COMET_V3_USDC), 'cUSDCV3');
        vm.label(address(USDC), 'USDC');
    }

    function testExecuteCompoundV3Withdraw(uint256 amountIn) external {
        // TLDR: cToken would be 4 wei short
        IERC20 token = USDC;
        IERC20 cToken = CUSDC_V3;
        uint256 weiShort = 4;
        amountIn = bound(amountIn, weiShort, token.totalSupply()); // at least 4 wei because cannot burn zero amount
        uint256 amountMin = amountIn - 2; // would get 2 wei less cToken

        // Setup supplied base token
        deal(address(token), user, amountIn);
        vm.startPrank(user);
        token.safeApprove(address(pool), amountIn);
        pool.supply(address(token), amountIn); // would get 2 wei less cToken
        vm.stopPrank();

        // Encode logics
        IParam.Logic[] memory logics = new IParam.Logic[](2);
        logics[0] = logicERC20Permit2PullToken(cToken, amountMin.toUint160()); // would get 2 wei less cToken
        logics[1] = _logicCompoundV3Withdraw(
            address(token),
            BPS_NOT_USED,
            amountMin - 2 // cannot use amountIn because cToken amount would be 2 wei less
        );

        address[] memory tokensReturn = new address[](2);
        tokensReturn[0] = address(token);
        tokensReturn[1] = address(cToken);

        // Execute
        vm.prank(user);
        router.execute(logics, tokensReturn, SIGNER_REFERRAL);

        assertEq(token.balanceOf(address(router)), 0);
        assertEq(token.balanceOf(address(agent)), 0);
        assertEq(token.balanceOf(user), amountIn - weiShort); // would get 4 wei less underlying token

        assertEq(cToken.balanceOf(address(router)), 0);
        assertEq(cToken.balanceOf(address(agent)), 0);
        assertLe(cToken.balanceOf(user), weiShort); // would burn 4 wei less cToken and leave 4 wei in user balance
    }

    function _logicCompoundV3Withdraw(
        address token,
        uint256 balanceBps,
        uint256 amountOrOffset
    ) public view returns (IParam.Logic memory) {
        // Encode logic
        bytes memory data = abi.encodeWithSelector(
            IComet.withdraw.selector,
            token,
            (balanceBps == BPS_NOT_USED) ? amountOrOffset : 0 // 0 is the amount which will be replaced
        );

        // Encode inputs
        IParam.Input[] memory inputs = new IParam.Input[](1);
        inputs[0].token = token;
        inputs[0].balanceBps = balanceBps;
        inputs[0].amountOrOffset = amountOrOffset;

        return
            IParam.Logic(
                address(pool), // to
                data,
                inputs,
                IParam.WrapMode.NONE,
                address(0), // approveTo
                address(0) // callback
            );
    }
}
