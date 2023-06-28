import { Wallet, utils } from 'zksync-web3';
import * as ethers from 'ethers';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { Deployer } from '@matterlabs/hardhat-zksync-deploy';

import { bytecode as agentBytecode } from '../artifacts-zk/contracts/Agent.sol/Agent.json';

// load env file
import dotenv from 'dotenv';
dotenv.config();

// load wallet private key from env file
const PRIVATE_KEY = process.env.WALLET_PRIVATE_KEY || '';

if (!PRIVATE_KEY) throw '⛔️ Private key not detected! Add it to the .env file!';

export default async function (hre: HardhatRuntimeEnvironment) {
  console.log(`Running deploy script for the Router contract`);

  const WRAPPED_NATIVE = '0x5AEa5775959fBC2557Cc8789bC1bf90A239D9a91';
  const OWNER = '0xa3C1C91403F0026b9dd086882aDbC8Cdbc3b3cfB';
  const PAUSER = '0xa3C1C91403F0026b9dd086882aDbC8Cdbc3b3cfB';
  const FEE_COLLECTOR = '0xa3C1C91403F0026b9dd086882aDbC8Cdbc3b3cfB';
  const AGENT_BYTECODE_HASH = await utils.hashBytecode(agentBytecode);

  // Initialize the wallet.
  const wallet = new Wallet(PRIVATE_KEY);

  // Create deployer object and load the artifact of the contract you want to deploy.
  const deployer = new Deployer(hre, wallet);
  const artifact = await deployer.loadArtifact('Router');

  // Estimate contract deployment fee
  const deploymentFee = await deployer.estimateDeployFee(artifact, [
    WRAPPED_NATIVE,
    OWNER,
    PAUSER,
    FEE_COLLECTOR,
    AGENT_BYTECODE_HASH,
  ]);

  // Deploy this contract. The returned object will be of a `Contract` type, similarly to ones in `ethers`.
  const parsedFee = ethers.utils.formatEther(deploymentFee.toString());
  console.log(`The deployment is estimated to cost ${parsedFee} ETH`);

  const deployedContract = await deployer.deploy(artifact, [
    WRAPPED_NATIVE,
    OWNER,
    PAUSER,
    FEE_COLLECTOR,
    AGENT_BYTECODE_HASH,
  ]);

  //obtain the Constructor Arguments
  const constructorArguments = deployedContract.interface.encodeDeploy([
    WRAPPED_NATIVE,
    OWNER,
    PAUSER,
    FEE_COLLECTOR,
    AGENT_BYTECODE_HASH,
  ]);
  console.log('constructor args:' + constructorArguments);

  // Show the contract info.
  const deployedAddress = deployedContract.address;
  const contractName = artifact.contractName;
  console.log(`${contractName} was deployed to ${deployedAddress}`);

  // Verify contract
  // const verificationId = await hre.run('verify:verify', {
  //   address: deployedAddress,
  //   contract: contractName,
  //   constructorArguments: constructorArguments,
  // });
  // console.log(`${contractName} was verified with id ${verificationId}`);
}
