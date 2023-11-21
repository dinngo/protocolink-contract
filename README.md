# Protocolink Contract on zkSync

[![test](https://github.com/dinngo/protocolink-contract/actions/workflows/test.yml/badge.svg)](https://github.com/dinngo/protocolink-contract/actions/workflows/test.yml)

> This contract is still in the testing phase and has not been audited. Please do not use it in production.

## Overview

- Protocolink is a router system which consolidates protocol interactions within a secure Router/Agent architecture in a single transaction.
- Protocolink is proficient in processing ERC-20, ERC-721, ERC-1155 and lending positions.
- Protocolink is protocol-agnostic. All protocol-related code is defined in the [protocolink-logics](https://github.com/dinngo/protocolink-logics)) repository instead of in the contracts. Protocolink also offers an [API](https://docs.protocolink.com/integrate-api/overview) and an [SDK](https://docs.protocolink.com/integrate-js-sdk/overview) for developers to create transactions.

More details can be found at [Protocolink Overview](https://docs.protocolink.com/).

## Project structure

- `/src`: smart contracts.
- `/deploy`: deployment and contract interaction scripts.
- `/test`: test files
- `hardhat.config.ts`: configuration file.

## Contract

When a user tries to execute a transaction:

1. ERC-20 tokens are transferred through the [Permit2](https://github.com/Uniswap/permit2).
1. The data is passed to an exclusive Agent through the Router.
1. The Agent transfers tokens from the user and executes the data.
1. After the data is executed, the Agent returns tokens back to the user.

Protocolink contracts consist of:

- `Router`: The single entry point for users to interact with. The Router forwards the data to an Agent when executing a transaction.
- `Agent`: The execution unit of user transactions. The Agent executes the data like token transfer, liquidity provision, and yield farming.
- `Callback`: The entry point for protocol callbacks to re-enter the Agent in a transaction.
- `Utility`: The extensions for the Agent to perform extra actions like interacting with specific protocols, calculating token prices, and managing user data.

The details of each component can be found at [Smart Contract Overview](https://docs.protocolink.com/smart-contract/overview).

## Developer Guide

### Prerequisites

The code in this repository is built using the Foundry framework. You can follow [these](https://book.getfoundry.sh/getting-started/installation) setup instructions if you have not set it up yet.

### Init

`git submodule update --init --recursive` updates all the submodules in lib but the paths and the solidity version in lib needs to be changed per file due to hardhat framework.

`yarn install`

### Build

`yarn compile`

### Test

`yarn test`

### Deploy

Fill out parameters in `/deploy/deploy-router.ts`

`yarn run deploy` will execute the deployment script `/deploy/deploy-router.ts`. Requires [environment variable setup](#environment-variables).

### Environment variables

In order to prevent users to leak private keys, this project includes the `dotenv` package which is used to load environment variables. It's used to load the wallet private key, required to run the deploy script.

To use it, rename `.env.example` to `.env` and enter your private key.

```
WALLET_PRIVATE_KEY=123cde574ccff....
```

### Local testing

In order to run test, you need to start the zkSync local environment. Please check [this section of the docs](https://v2-docs.zksync.io/api/hardhat/testing.html#prerequisites) which contains all the details.

If you do not start the zkSync local environment, the tests will fail with error `Error: could not detect network (event="noNetwork", code=NETWORK_ERROR, version=providers/5.7.2)`

## Official Links

- [Website](https://zksync.io/)
- [Documentation](https://v2-docs.zksync.io/dev/)
- [GitHub](https://github.com/matter-labs)
- [Twitter](https://twitter.com/zksync)
- [Discord](https://discord.gg/nMaPGrDDwk)
