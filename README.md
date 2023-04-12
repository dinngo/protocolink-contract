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

- `Router`: Users interact with the single entry point to execute transactions, and forwards each user's transaction to their respective `Agent`
- `Agent`: Execute user's transaction and securely hold a user's token approvals since only the user can access and utilize their own `Agent`.
- `Callback`: One-time address for reentering `Agent` can only be set during contract execution
- `Utility`: Can be called by `Agent` to perform additional actions.
- `Fee`: Calculates and verifies fees based on various fee scenarios.

## Usage

### Build

`forge build`

### Test

`forge test --fork-url https://rpc.ankr.com/eth -vvv`
