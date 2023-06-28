# Protocolink Contract on zkSync

[![test](https://github.com/dinngo/protocolink-contract/actions/workflows/test.yml/badge.svg)](https://github.com/dinngo/protocolink-contract/actions/workflows/test.yml)

> This contract is still in the testing phase and has not been audited. Please do not use it in production.

## Overview

Protocolink is a router system proficient in processing ERC20, NFT, and lending positions, providing users and developers greater flexibility when creating transactions across different protocols.

The flexibility of Protocolink comes from its protocol-agnostic nature, with all protocol-related code defined in the below repos and outside of contracts:

- https://github.com/dinngo/protocolink-logics
- https://github.com/dinngo/protocolink-js-sdk

## Project structure

- `/contracts`: smart contracts.
- `/deploy`: deployment and contract interaction scripts.
- `/test`: test files
- `hardhat.config.ts`: configuration file.

## Contract

Protocolink contracts consist of the following components:

- `Router`: The single entry point for users to interact with when executing transactions. `Router` forwards user transactions to respective `Agents`.
- `Agent`: The execution unit of user transactions. The token approvals are securely held since one `Agent` is exclusive to one user only.
- `Callback`: One-time address is used for reentering `Agent`. Can only be set during contract execution.
- `Utility`: Can be called by `Agent` to perform additional actions.
- `Fee`: Calculates fees and verifies them based on various fee scenarios.

## Usage

### Build

`yarn compile`

### Test

`yarn test`

### Deploy and Verify

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
