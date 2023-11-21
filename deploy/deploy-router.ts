import BigNumberJS from 'bignumber.js';
import { Deployer } from '@matterlabs/hardhat-zksync-deploy';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { Wallet, utils } from 'zksync-web3';
import { bytecode as agentBytecode } from '../artifacts-zk/src/Agent.sol/Agent.json';
import dotenv from 'dotenv';
import * as ethers from 'ethers';
import { expect } from 'chai';

dotenv.config();

// load wallet private key from env file
const PRIVATE_KEY = process.env.WALLET_PRIVATE_KEY || '';

if (!PRIVATE_KEY) throw '⛔️ Private key not detected! Add it to the .env file!';

export default async function (hre: HardhatRuntimeEnvironment) {
  console.log(`Running deploy script for the Router contract`);

  // Initialize the wallet.
  const wallet = new Wallet(PRIVATE_KEY);

  // Create deployer object and load the artifact of the contract you want to deploy.
  const deployer = new Deployer(hre, wallet);
  const artifact = await deployer.loadArtifact('Router');

  // Fill the constructor parameters
  const WRAPPED_NATIVE = '0x5AEa5775959fBC2557Cc8789bC1bf90A239D9a91';
  const PERMIT2 = '0x87C0878B54c174199f438470FD74B3F7e1Def295';
  const DEPLOYER = deployer.zkWallet.address;
  const AGENT_BYTECODE_HASH = await utils.hashBytecode(agentBytecode);
  const CONSTRUCTOR_PARAMS = [WRAPPED_NATIVE, PERMIT2, DEPLOYER, AGENT_BYTECODE_HASH];

  // Fill the extra parameters
  const OWNER = '0x928e4A0fa142b8c49e8C608a8Fc0946a3946eb62';
  const PAUSER = '0xAE98c5629C7a6840754E2ed9547577D04040e2a7';
  const DEFAULT_FEE_COLLECTOR = '0x33dcA7EF16B6a0893542A1033cB70a24b2208b8F';
  const SIGNER = '0xffFf5a88840FF1f168E163ACD771DFb292164cFA';
  const FEE_RATE = 20;

  // Estimate contract deployment fee
  const deploymentFee = await deployer.estimateDeployFee(artifact, CONSTRUCTOR_PARAMS);

  // Deploy this contract. The returned object will be of a `Contract` type, similarly to ones in `ethers`.
  const parsedFee = ethers.utils.formatEther(deploymentFee.toString());
  console.log(`The deployment is estimated to cost ${parsedFee} ETH`);

  console.log(`Deploying router ...`);
  const router = await deployer.deploy(artifact, CONSTRUCTOR_PARAMS);

  // Set and check pauser
  console.log(`Setting pauser ...`);
  const receiptSetPauser = await router.setPauser(PAUSER);
  await receiptSetPauser.wait();
  expect(await router.pauser()).to.be.eq(PAUSER);

  // Set and check fee collector
  console.log(`Setting fee collector ...`);
  const receiptSetFeeCollector = await router.setFeeCollector(DEFAULT_FEE_COLLECTOR);
  await receiptSetFeeCollector.wait();
  expect(await router.defaultCollector()).to.be.eq(DEFAULT_FEE_COLLECTOR);

  // Set and check signer
  console.log(`Adding signer ...`);
  const receiptAddSigner = await router.addSigner(SIGNER);
  await receiptAddSigner.wait();
  expect(await router.signers(SIGNER)).to.be.true;

  // Set and check fee rate
  console.log(`Setting fee rate ...`);
  if (FEE_RATE > 0) {
    const receiptSetFeeRate = await router.setFeeRate(FEE_RATE);
    await receiptSetFeeRate.wait();
  }
  const routerFeeRate = await router.feeRate();
  expect(new BigNumberJS(routerFeeRate.toString()).toString()).to.be.eq(new BigNumberJS(FEE_RATE).toString());

  // Set and check owner
  console.log(`Checking owner ...`);
  if ((await router.owner()) != OWNER) {
    const receiptTransferOwnership = await router.transferOwnership(OWNER);
    await receiptTransferOwnership.wait();
  }
  expect(await router.owner()).to.be.eq(OWNER);

  // Encode the constructor parameters
  const encodedConstructorArguments = router.interface.encodeDeploy(CONSTRUCTOR_PARAMS);
  console.log('encoded constructor args:' + encodedConstructorArguments);

  // Show the contract info.
  const routerAddress = router.address;
  const contractName = artifact.contractName;
  console.log(`${contractName} was deployed to ${routerAddress}`);
  console.log(`owner address is set to ${OWNER}`);
  console.log(`pauser address is set to ${PAUSER}`);
  console.log(`default fee collector address is set to ${DEFAULT_FEE_COLLECTOR}`);
  console.log(`signer address is set to ${SIGNER}`);
  console.log(`fee rate is set to ${FEE_RATE}`);

  // Verify contract (TODO: not tested yet)
  const fullyQualifiedContractName = `src/${contractName}.sol:${contractName}`;
  const verificationId = await hre.run('verify:verify', {
    address: routerAddress,
    contract: fullyQualifiedContractName,
    constructorArguments: encodedConstructorArguments,
  });
  console.log(`verifying contract with id ${verificationId}`);
}
