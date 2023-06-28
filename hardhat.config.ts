import { HardhatUserConfig } from 'hardhat/config';

import '@matterlabs/hardhat-zksync-deploy';
import '@matterlabs/hardhat-zksync-solc';
import '@matterlabs/hardhat-zksync-verify';

const config: HardhatUserConfig = {
  zksolc: {
    version: '1.3.11',
    compilerSource: 'binary',
    settings: {},
  },
  defaultNetwork: 'zkSyncLocal',
  networks: {
    hardhat: {
      zksync: false,
    },
    zkSyncLocal: {
      url: 'http://localhost:3050',
      ethNetwork: 'http://localhost:8545',
      zksync: true,
    },
    zkSyncTestnet: {
      url: 'https://zksync2-testnet.zksync.dev',
      ethNetwork: 'goerli',
      zksync: true,
      verifyURL: 'https://zksync2-testnet-explorer.zksync.dev/contract_verification',
    },
    zkSyncMainnet: {
      url: 'https://mainnet.era.zksync.io',
      ethNetwork: 'mainnet',
      zksync: true,
    },
  },
  solidity: {
    version: '0.8.18',
  },
};

export default config;
