# Protocolink Contract

[![test](https://github.com/dinngo/protocolink-contract/actions/workflows/test.yml/badge.svg)](https://github.com/dinngo/protocolink-contract/actions/workflows/test.yml)

> This contract is still in the testing phase and has not been audited. Please do not use it in production.

## Overview

Protocolink is a router system proficient in processing ERC20, NFT, and lending positions, providing users and developers greater flexibility when creating transactions across different protocols.

The flexibility of Protocolink comes from its protocol-agnostic nature, with all protocol-related code defined in the below repos and outside of contracts:

- https://github.com/dinngo/protocolink-logics
- https://github.com/dinngo/protocolink-js-sdk

## Contract

Protocolink contracts consist of the following components:

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

### Deploy Contract(s)

Fill out parameters in `script/Deploy<network>.s.sol`

- This script deploys all contracts whose `deployedAddress` equals `UNDEPLOYED`.

```console
forge script --broadcast \
--rpc-url <RPC-URL> \
--private-key <PRIVATE-KEY> \
--sig 'run()' \
script/Deploy<network>.s.sol:Deploy<network> \
```

### Deploy and Verify

Fill out parameters in `script/Deploy<network>.s.sol`

```console
forge script --broadcast \
--rpc-url <RPC-URL> \
--private-key <PRIVATE-KEY> \
--sig 'run()' \
script/Deploy<network>.s.sol:Deploy<network> \
--chain-id <CHAIN-ID> \
--etherscan-api-key <ETHERSCAN-API-KEY> \
--verify
```
