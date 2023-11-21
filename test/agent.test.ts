import { Contract, Provider, Wallet, utils } from 'zksync-web3';
import { Deployer } from '@matterlabs/hardhat-zksync-deploy';
import { bytecode as agentBytecode } from '../artifacts-zk/src/Agent.sol/Agent.json';
import * as ethers from 'ethers';
import { expect } from 'chai';
import * as hre from 'hardhat';

const abi = require('ethereumjs-abi');

const abiCoder = new ethers.utils.AbiCoder();

const { constants, expectRevert } = require('@openzeppelin/test-helpers');

const RICH_WALLET_ADDR_0 = '0x36615Cf349d7F6344891B1e7CA7C72883F5dc049';
const RICH_WALLET_PK_0 = '0x7726827caac94a7f9e1b160f7ea819f172f7b6f9d2a97f992c38edeab82d4110';

const DEPLOYER = RICH_WALLET_ADDR_0;

const BPS_NOT_USED = 0;
const OFFSET_NOT_USED = ethers.BigNumber.from('0x8000000000000000000000000000000000000000000000000000000000000000');
const UINT256_MAX = '0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff';
const WRAP_MODE_NONE = 0;
const WRAP_BEFORE = 1;
const UNWRAP_AFTER = 2;
const ZERO_ADDRESS = constants.ZERO_ADDRESS;
const NATIVE = '0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE';
const BPS_BASE = 10000;

async function deployRouter(deployer: Deployer, wrappedNative, permit2): Promise<Contract> {
  const artifact = await deployer.loadArtifact('Router');
  return await deployer.deploy(artifact, [wrappedNative, permit2, DEPLOYER, await utils.hashBytecode(agentBytecode)]);
}

async function deployAgent(wallet, router) {
  const calldata = abi.simpleEncode('newAgent()');
  const receipt = await wallet.sendTransaction({ to: router.address, data: calldata });
  await receipt.wait();
  return await router.getAgent(wallet.address);
}

async function deployMockWrappedNative(deployer: Deployer): Promise<Contract> {
  const artifact = await deployer.loadArtifact('MockWrappedNative');
  return await deployer.deploy(artifact, []);
}

async function deployMockPermit2(deployer: Deployer): Promise<Contract> {
  const artifact = await deployer.loadArtifact('MockPermit2');
  return await deployer.deploy(artifact, []);
}

async function deployMockERC20(deployer: Deployer): Promise<Contract> {
  const artifact = await deployer.loadArtifact('MockERC20');
  return await deployer.deploy(artifact, ['mockERC20', 'mock']);
}

async function deployMockFallback(deployer: Deployer): Promise<Contract> {
  const artifact = await deployer.loadArtifact('MockFallback');
  return await deployer.deploy(artifact, []);
}

async function deployMockCallback(deployer: Deployer): Promise<Contract> {
  const artifact = await deployer.loadArtifact('MockCallback');
  return await deployer.deploy(artifact, []);
}

describe('Agent', function () {
  const inputsEmpty = [];
  const logicsEmpty = [];
  const permit2DatasEmpty = [];
  const dataEmpty = [];
  const tokensReturnEmpty = [];

  let provider;
  let wallet;
  let deployer;
  let agent;
  let router;
  let mockERC20;
  let mockTo;
  let mockCallback;
  let mockWrappedNative;
  let mockPermit2;

  async function setUpTest() {
    provider = Provider.getDefaultProvider();
    wallet = new Wallet(RICH_WALLET_PK_0, provider);
    deployer = new Deployer(hre, wallet);
    mockWrappedNative = await deployMockWrappedNative(deployer);
    mockPermit2 = await deployMockPermit2(deployer);
    router = await deployRouter(deployer, mockWrappedNative.address, mockPermit2.address);
    agent = await deployAgent(wallet, router);
    mockERC20 = await deployMockERC20(deployer);
    mockTo = await deployMockFallback(deployer);
    mockCallback = await deployMockCallback(deployer);
  }

  before(async function () {});

  beforeEach(async function () {});

  afterEach(async function () {});

  describe('Normal', function () {
    beforeEach(async function () {
      await setUpTest();
    });

    it.skip('router', async function () {});
    it.skip('wrapped native', async function () {});
    it.skip('do Permit2 transfer from', async function () {});
    it.skip('do Permit2 transfer from batch', async function () {});
    it.skip('do Permit2 permit', async function () {});

    it('wrap before fixed amounts', async function () {
      const amount1 = 1;
      const amount2 = 1;
      const amount = amount1 + amount2;
      const input0 = {
        token: mockWrappedNative.address,
        balanceBps: BPS_NOT_USED,
        amountOrOffset: amount1,
      };
      const input1 = {
        token: mockWrappedNative.address,
        balanceBps: BPS_NOT_USED,
        amountOrOffset: amount2,
      };
      const inputs = [input0, input1];

      const logic0 = {
        to: mockTo.address,
        data: abiCoder.encode(['bytes'], ['0x']),
        inputs: inputs,
        wrapMode: WRAP_BEFORE,
        approveTo: ZERO_ADDRESS,
        callback: ZERO_ADDRESS,
      };

      const user = wallet.address;
      const logics = [logic0];
      const receipt = await router.execute(permit2DatasEmpty, logics, tokensReturnEmpty, {
        from: user,
        value: amount,
      });

      await receipt.wait();
      const agent = await router.getAgent(user);
      expect((await mockWrappedNative.balanceOf(agent)).toString()).to.be.eq(amount.toString());
    });

    it('wrap before replaced amounts', async function () {
      const amount = 100000;
      const bps = 10;
      const input0 = {
        token: mockWrappedNative.address,
        balanceBps: bps,
        amountOrOffset: OFFSET_NOT_USED,
      };
      const input1 = {
        token: mockWrappedNative.address,
        balanceBps: BPS_BASE - bps,
        amountOrOffset: OFFSET_NOT_USED,
      };

      const inputs = [input0, input1];
      const logic0 = {
        to: mockTo.address,
        data: abiCoder.encode(['bytes'], ['0x']),
        inputs: inputs,
        wrapMode: WRAP_BEFORE,
        approveTo: ZERO_ADDRESS,
        callback: ZERO_ADDRESS,
      };
      const user = wallet.address;
      const logics = [logic0];
      const receipt = await router.execute(permit2DatasEmpty, logics, tokensReturnEmpty, {
        from: user,
        value: amount,
      });
      await receipt.wait();

      // const agent = await router.getAgent(user);
      expect((await mockWrappedNative.balanceOf(agent)).toString()).to.be.eq(amount.toString());
    });

    it('wrap before with token', async function () {
      const user = wallet.address;
      const amount1 = 100000;
      const amount2 = 100000;

      const receiptMint = await mockERC20.mint(agent, amount2);
      await receiptMint.wait();

      // The inputs contain native and ERC-20
      const input0 = {
        token: mockWrappedNative.address,
        balanceBps: BPS_NOT_USED,
        amountOrOffset: amount1,
      };
      const input1 = {
        token: mockERC20.address,
        balanceBps: BPS_NOT_USED,
        amountOrOffset: amount2,
      };

      const inputs = [input0, input1];
      const logic0 = {
        to: mockTo.address,
        data: [],
        inputs: inputs,
        wrapMode: WRAP_BEFORE,
        approveTo: ZERO_ADDRESS,
        callback: ZERO_ADDRESS,
      };
      const logics = [logic0];
      const receipt = await router.execute(permit2DatasEmpty, logics, tokensReturnEmpty, {
        from: user,
        value: amount1,
      });
      await receipt.wait();

      // const agent = await router.getAgent(user);
      expect((await mockWrappedNative.balanceOf(agent)).toString()).to.be.eq(amount1.toString());
      expect((await mockERC20.balanceOf(agent)).toString()).to.be.eq(amount2.toString());
    });

    it('unwrap after', async function () {
      const user = wallet.address;
      const amount = 100000;
      const amountBefore = 1000;
      const receiptMint = await mockWrappedNative.mint(agent, { from: user, value: amountBefore });
      await receiptMint.wait(); // Ensure agent handles differences

      const input0 = {
        token: NATIVE,
        balanceBps: BPS_NOT_USED,
        amountOrOffset: amount,
      };
      const inputs = [input0];

      const logic0 = {
        to: mockWrappedNative.address,
        data: abi.simpleEncode('deposit()'),
        inputs: inputs,
        wrapMode: UNWRAP_AFTER,
        approveTo: ZERO_ADDRESS,
        callback: ZERO_ADDRESS,
      };
      const logics = [logic0];

      const receipt = await router.execute(permit2DatasEmpty, logics, tokensReturnEmpty, {
        from: user,
        value: amount,
      });
      await receipt.wait();

      expect((await provider.getBalance(agent)).toString()).to.be.eq(amount.toString());
      expect((await mockWrappedNative.balanceOf(agent)).toString()).to.be.eq(amountBefore.toString());
    });

    it('send native', async function () {
      const amountIn = 100000;
      const balanceBps = 10;

      // logicSendNative
      const input0 = {
        token: NATIVE,
        balanceBps: balanceBps,
        amountOrOffset: OFFSET_NOT_USED,
      };
      const inputs = [input0];

      const receiver = Wallet.createRandom();
      const logic0 = {
        to: receiver.address,
        data: [],
        inputs: inputs,
        wrapMode: WRAP_MODE_NONE,
        approveTo: ZERO_ADDRESS,
        callback: ZERO_ADDRESS,
      };

      const user = wallet.address;
      const logics = [logic0];
      const receipt = await router.execute(permit2DatasEmpty, logics, tokensReturnEmpty, {
        from: user,
        value: amountIn,
      });
      await receipt.wait();

      const recipientAmount = (amountIn * balanceBps) / BPS_BASE;
      expect((await provider.getBalance(router.address)).toString()).to.be.eq('0');
      expect((await provider.getBalance(receiver.address)).toString()).to.be.eq(recipientAmount.toString());
      expect((await provider.getBalance(agent)).toString()).to.be.eq((amountIn - recipientAmount).toString());
    });

    it('approve to is default', async function () {
      const amountIn = 100000;

      const input0 = {
        token: mockERC20.address,
        balanceBps: BPS_NOT_USED,
        amountOrOffset: amountIn,
      };
      const inputs = [input0];

      const logic0 = {
        to: mockTo.address,
        data: [],
        inputs: inputs,
        wrapMode: WRAP_MODE_NONE,
        approveTo: ZERO_ADDRESS,
        callback: ZERO_ADDRESS,
      };

      expect((await mockERC20.allowance(agent, mockTo.address)).toString()).to.be.eq('0');

      const user = wallet.address;
      const logics = [logic0];
      const receipt = await router.execute(permit2DatasEmpty, logics, tokensReturnEmpty, {
        from: user,
        value: amountIn,
      });
      await receipt.wait();

      expect((await mockERC20.allowance(agent, mockTo.address)).toHexString()).to.be.eq(UINT256_MAX);
    });

    it('approve to is set', async function () {
      const amountIn = 100000;
      const approveTo = Wallet.createRandom();
      const input0 = {
        token: mockERC20.address,
        balanceBps: BPS_NOT_USED,
        amountOrOffset: amountIn,
      };
      const inputs = [input0];

      const logic0 = {
        to: mockTo.address,
        data: [],
        inputs: inputs,
        wrapMode: WRAP_MODE_NONE,
        approveTo: approveTo.address,
        callback: ZERO_ADDRESS,
      };

      expect((await mockERC20.allowance(agent, approveTo.address)).toString()).to.be.eq('0');

      const user = wallet.address;
      const logics = [logic0];
      const receipt = await router.execute(permit2DatasEmpty, logics, tokensReturnEmpty, {
        from: user,
        value: amountIn,
      });
      await receipt.wait();

      expect((await mockERC20.allowance(agent, approveTo.address)).toHexString()).to.be.eq(UINT256_MAX);
    });

    it('should revert: initialize again', async function () {
      // Initialize again
      const calldata = abi.simpleEncode('initialize()');
      await expectRevert.unspecified(wallet.sendTransaction({ to: agent, data: calldata }));
    });

    // skip: agent.execute is not a function
    it.skip('should revert: execute by non router address', async function () {
      // const user = wallet.address;
      // const agent = await router.agentImplementation();
      // await expectRevert.unspecified(
      //   agent.execute(logicsEmpty, tokensReturnEmpty, {
      //     from: user,
      //   })
      // );
      // await expectRevert.unspecified(wallet.sendTransaction({ to: router.address, data: calldata }));
    });
    it.skip('should revert: do invalid function in Permit2', async function () {});
    it.skip('should revert: execute Permit2 in logic', async function () {});

    // skip: agent.executeByCallback is not a function
    it.skip('should revert: execute by non callback address', async function () {
      const user = wallet.address;
      const agent = await router.agentImplementation();
      await expectRevert.unspecified(
        agent.executeByCallback(logicsEmpty, {
          from: user,
        })
      );
    });

    it('should revert: invalid bps', async function () {
      const user = wallet.address;
      const input0 = {
        token: ZERO_ADDRESS,
        balanceBps: BPS_BASE + 1,
        amountOrOffset: 0,
      };
      const inputs = [input0];

      const logic0 = {
        to: ZERO_ADDRESS,
        data: [],
        inputs: inputs,
        wrapMode: WRAP_MODE_NONE,
        approveTo: ZERO_ADDRESS,
        callback: ZERO_ADDRESS,
      };

      const logics = [logic0];
      await expectRevert.unspecified(
        router.execute(permit2DatasEmpty, logics, tokensReturnEmpty, {
          from: user,
        })
      );
    });

    it('should revert: unreset callback with charge', async function () {
      const user = wallet.address;

      const logic0 = {
        to: mockTo.address,
        data: dataEmpty,
        inputs: inputsEmpty,
        wrapMode: WRAP_MODE_NONE,
        approveTo: ZERO_ADDRESS,
        callback: mockCallback.address,
      };

      const logics = [logic0];
      await expectRevert.unspecified(
        router.execute(permit2DatasEmpty, logics, tokensReturnEmpty, {
          from: user,
        })
      );
    });
  });
});
