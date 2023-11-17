# Protocolink Contract

[![test](https://github.com/dinngo/protocolink-contract/actions/workflows/test.yml/badge.svg)](https://github.com/dinngo/protocolink-contract/actions/workflows/test.yml)

## Overview

- Protocolink is a router system which consolidates protocol interactions within a secure Router/Agent architecture in a single transaction.
- Protocolink is proficient in processing ERC-20, ERC-721, ERC-1155 and lending positions.
- Protocolink is protocol-agnostic. All protocol-related code is defined in the [protocolink-logics](https://github.com/dinngo/protocolink-logics)) repository instead of in the contracts. Protocolink also offers an [API](https://docs.protocolink.com/integrate-api/overview) and an [SDK](https://docs.protocolink.com/integrate-js-sdk/overview) for developers to create transactions.

More details can be found at [Protocolink Overview](https://docs.protocolink.com/).

## Audit

- [PeckShield](./audits/PeckShield-Audit-Report-Protocolink-v1.0.pdf) - November 2023

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

### Build

`forge build`

### Test

`forge test -vvv`

### Coverage

`forge coverage --rpc-url ${FOUNDRY_ETH_RPC_URL} --report summary`

### Deploy Contract(s) and Verify

- Fill out parameters in `script/Deploy<NETWORK>.s.sol`. This script deploys all contracts whose `deployedAddress` equals `UNDEPLOYED`.
- When deploying with `forge`, the default priority gas is set at 3 gwei. This is considered a high priority gas fee on both Ethereum and most L2s. The workaround is to check the appropriate total gas at the time of deployment and use `--legacy` (pre EIP-1559 - Type 1 Transaction) for deployment.

```console
forge script --broadcast \
--rpc-url <RPC-URL> \
--private-key <PRIVATE-KEY> \
--sig 'run()' \
script/Deploy<NETWORK>.s.sol:Deploy<NETWORK> \
--chain-id <CHAIN-ID> \
--etherscan-api-key <ETHERSCAN-API-KEY> \
--verify \
--slow \
--legacy \
--with-gas-price <GAS-IN-WEI>
```
