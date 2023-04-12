# Router Contract

[![test](https://github.com/dinngodev/router-contract/actions/workflows/test.yml/badge.svg)](https://github.com/dinngodev/router-contract/actions/workflows/test.yml)

> This is highly experimental contracts not recommended for production.

## Usage

### Build

`forge build`

### Test

`forge test --fork-url https://rpc.ankr.com/eth -vvv`

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
