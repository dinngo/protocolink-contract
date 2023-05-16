# Composable Router Contract

[![test](https://github.com/dinngo/composable-router-contract/actions/workflows/test.yml/badge.svg)](https://github.com/dinngo/composable-router-contract/actions/workflows/test.yml)

> This contract is still in the testing phase and has not been audited. Please do not use it in production.

## Overview

Composable Router is a router system proficient in processing ERC20, NFT, and lending positions, providing users and developers greater flexibility when creating transactions across different protocols.

The flexibility of Composable Router comes from its protocol-agnostic nature, with all protocol-related code defined in the below repos and outside of contracts:

- https://github.com/dinngo/composable-router-logics
- https://github.com/dinngo/composable-router-sdk
- https://github.com/dinngo/composable-router-api-sdk

## Contract

Composable Router contracts consist of the following components:

- `Router`: The single entry point for users to interact with when executing transactions. `Router` forwards user transactions to respective `Agents`.
- `Agent`: The execution unit of user transactions. The token approvals are securely held since one `Agent` is exclusive to one user only.
- `Callback`: One-time address is used for reentering `Agent`. Can only be set during contract execution.
- `Utility`: Can be called by `Agent` to perform additional actions.
- `Fee`: Calculates fees and verifies them based on various fee scenarios.

## Usage

### Build

`forge build`

### Test

`forge test --fork-url https://cloudflare-eth.com -vvv`

### Coverage

`forge coverage --rpc-url https://rpc.ankr.com/eth --report summary`

### Deploy All

Fill out parameters in `script/deployParameters/<network>.json`

```console
forge script --broadcast \
--rpc-url <RPC-URL> \
--private-key <PRIVATE-KEY> \
--sig 'run(string)' \
script/DeployAll.s.sol:DeployAll \
<pathToJSON>
```

### Deploy All and Verify All

Fill out parameters in `script/deployParameters/<network>.json`

```console
forge script --broadcast \
--rpc-url <RPC-URL> \
--private-key <PRIVATE-KEY> \
--sig 'run(string)' \
script/DeployAll.s.sol:DeployAll \
<pathToJSON> \
--chain-id <CHAIN-ID> \
--etherscan-api-key <ETHERSCAN-API-KEY> \
--verify
```

#### Deploy Single Contract

Fill out parameters in `scripts/deployParameters/<network>.json`

```console
forge script --broadcast \
--rpc-url <RPC-URL> \
--private-key <PRIVATE-KEY> \
--sig 'run(string)' \
script/Deploy<CONTRACT-NAME>.s.sol:Deploy<CONTRACT-NAME> \
<pathToJSON>
```
