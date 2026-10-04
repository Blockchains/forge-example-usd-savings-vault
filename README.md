# USD Savings Vault (ERC-4626 + Chainlink)

[![CI](https://github.com/Blockchains/forge-example-usd-savings-vault/actions/workflows/ci.yml/badge.svg)](https://github.com/Blockchains/forge-example-usd-savings-vault/actions/workflows/ci.yml) [![Pages](https://github.com/Blockchains/forge-example-usd-savings-vault/actions/workflows/pages.yml/badge.svg)](https://blockchains.github.io/forge-example-usd-savings-vault/) [![Open in Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/Blockchains/forge-example-usd-savings-vault?quickstart=1)

> **Idea:** A USD-valued savings vault (ERC-4626) where users deposit WETH and receive shares; deposits and total assets are priced in USD with a Chainlink price feed oracle; an admin role manages a USD deposit cap and a management fee (access control).

This repository was composed automatically by **[Blockchain Lab Forge](https://blockchainlab.com/forge)**. Forge parsed the idea into capabilities (`price-oracle`, `vault`, `access-control`), retrieved matching components from the [Blockchains fork index](https://github.com/Blockchains/blockchainlab-index), pinned them to release tags, copied their exact source files (with full import closure) from the Blockchains forks, and added glue code, tests, a deploy script and a web front end.

## What it does
`src/UsdSavingsVault.sol` (glue, MIT) is an ERC-4626 vault over WETH:
- **USD valuation**: `assetPriceUsd()`, `assetsToUsd()`, `totalAssetsUsd()` and `balanceOfUsd()` read the Chainlink ETH/USD feed. Stale (`maxPriceAge`) or non-positive answers revert.
- **USD deposit cap**: `maxDeposit` turns the remaining USD headroom into WETH. It returns 0 (deposits paused) when the oracle can't be used, so it never reverts, as ERC-4626 requires.
- **Entry fee**: bps, capped at 5%, paid to `feeRecipient`. Uses the OpenZeppelin ERC4626Fees pattern, so `preview*` stays exact.
- **Roles**: `DEFAULT_ADMIN_ROLE` and `RISK_MANAGER_ROLE` (OpenZeppelin AccessControl).
- **Inflation-attack hardening**: virtual shares (`_decimalsOffset = 6`).

## Tests (no mocks)
`forge test` forks **Ethereum mainnet** and runs against the real WETH9 and the real Chainlink ETH/USD aggregator. It covers valuation, redeem, fees, the USD cap, stale-oracle shutdown, role checks, an inflation attack and a fuzzed round trip. A second suite deploys and deposits on a **Sepolia** fork with the same arguments the web app uses. RPCs default to publicnode; override them with `MAINNET_RPC_URL` / `SEPOLIA_RPC_URL`.

```bash
git clone --recursive https://github.com/Blockchains/forge-example-usd-savings-vault && cd forge-example-usd-savings-vault
forge test -vv
cd web && npm ci && npm test && npm run dev
```

## Deploy
- **Browser**: the [Pages app](https://blockchains.github.io/forge-example-usd-savings-vault/) shows live feed prices and deploys the vault to Sepolia from your wallet.
- **CLI**: `forge script script/Deploy.s.sol --rpc-url $RPC_URL --account <keystore> --broadcast`. Defaults to mainnet WETH and ETH/USD; set `ASSET`/`FEED` for other chains.


## Component map
| Capability | Component | From | Licence |
|---|---|---|---|
| price-oracle (primary) | [`AggregatorV3Interface`](https://github.com/Blockchains/chainlink-evm/blob/d1ee27b0b5875adb8eca1e0da05926f7eb1f6e1f/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol) | [Blockchains/chainlink-evm](https://github.com/Blockchains/chainlink-evm) (upstream [smartcontractkit/chainlink-evm](https://github.com/smartcontractkit/chainlink-evm)) | MIT |
| vault (primary) | [`ERC4626`](https://github.com/Blockchains/openzeppelin-contracts/blob/cab19933c33c2ad1d4c7a84864a3601dddfd16f3/contracts/token/ERC20/extensions/ERC4626.sol) | [Blockchains/openzeppelin-contracts](https://github.com/Blockchains/openzeppelin-contracts) (upstream [OpenZeppelin/openzeppelin-contracts](https://github.com/OpenZeppelin/openzeppelin-contracts)) | MIT |
| access-control (primary) | [`AccessControl`](https://github.com/Blockchains/openzeppelin-contracts/blob/cab19933c33c2ad1d4c7a84864a3601dddfd16f3/contracts/access/AccessControl.sol) | [Blockchains/openzeppelin-contracts](https://github.com/Blockchains/openzeppelin-contracts) (upstream [OpenZeppelin/openzeppelin-contracts](https://github.com/OpenZeppelin/openzeppelin-contracts)) | MIT |
| access-control (companion) | [`Ownable`](https://github.com/Blockchains/openzeppelin-contracts/blob/cab19933c33c2ad1d4c7a84864a3601dddfd16f3/contracts/access/Ownable.sol) | [Blockchains/openzeppelin-contracts](https://github.com/Blockchains/openzeppelin-contracts) (upstream [OpenZeppelin/openzeppelin-contracts](https://github.com/OpenZeppelin/openzeppelin-contracts)) | MIT |

Copied sources (unmodified, under `lib/<project>/`, listed file by file in [NOTICE](NOTICE)):

| Fork | Pinned | Files |
|---|---|---|
| [Blockchains/openzeppelin-contracts](https://github.com/Blockchains/openzeppelin-contracts/tree/cab19933c33c2ad1d4c7a84864a3601dddfd16f3) | v5.7.0 | 20 |
| [Blockchains/chainlink-evm](https://github.com/Blockchains/chainlink-evm/tree/d1ee27b0b5875adb8eca1e0da05926f7eb1f6e1f) | d1ee27b0b5 | 1 |

Machine-readable: [`component-map.json`](component-map.json) · plan: [`plan.json`](plan.json)

<!-- blocks:start -->
## Use as a building block

> **For AI agents and builders:** read [`AGENTS.md`](AGENTS.md) (setup, commands, structure, rules), [`llms.txt`](llms.txt) (doc map) and the machine-readable [`blocks.json`](blocks.json) ([schema](https://github.com/Blockchains/.github/blob/main/docs/BLOCKS-SCHEMA.md)). How all Blockchains blocks fit together: **[Build with Blocks](https://github.com/Blockchains/.github/blob/main/docs/BUILD-WITH-BLOCKS.md)** · org catalogue: [https://blockchains.github.io/blocks.json](https://blockchains.github.io/blocks.json).

**What it exports**

| Export | Type | Install / access |
|---|---|---|
| `UsdSavingsVault` | solidity | `forge install Blockchains/forge-example-usd-savings-vault` |
| `script/Deploy.s.sol` | file | `forge script script/Deploy.s.sol --rpc-url $SEPOLIA_RPC_URL --account <keystore> --broadcast` |
| `component-map.json, plan.json` | file | `provenance: capability → component → pinned fork commit` |
| `web/` | web | `cd web && npm ci && npm run dev` |

**Minimal example** (from the repo README; CI runs the same)

```bash
git clone --recursive https://github.com/Blockchains/forge-example-usd-savings-vault && cd forge-example-usd-savings-vault
forge test -vv                    # unit tests + Sepolia fork test (set SEPOLIA_RPC_URL)
cd web && npm ci && npm run dev   # viem front end; mainnet/Sepolia WETH + Chainlink ETH/USD addresses in web/src/chain.ts
```

**Inputs → outputs**

- In: `constructor args` (Solidity) UsdSavingsVault(IERC20Metadata asset, AggregatorV3Interface feed, name, symbol, …) (see src/UsdSavingsVault.sol)
- Out: `deployed contracts` (EVM); `events/errors` (ABI) see src/

**Composes with**

- [Blockchains/blockchainlab-index](https://github.com/Blockchains/blockchainlab-index): the composer that generated this repo
- [Blockchains/blockchainlab-index](https://github.com/Blockchains/blockchainlab-index): components were retrieved from the index
- [Blockchains/blockchainlab-sdk](https://github.com/Blockchains/blockchainlab-sdk): yields/stablecoins data next to the vault UI
- [Blockchains/blockchainlab-labs](https://github.com/Blockchains/blockchainlab-labs): L28 invariant-testing lab for vault properties

**Versioning & stability:** `reference`. Reference output of an automated composer; copied components are pinned to fork release tags (see NOTICE / component-map.json). Not audited. Treat as a starting point and review before deploying with value.
<!-- blocks:end -->

## Licence
**MIT**. All copied components are permissively licensed. Every copied file keeps its original SPDX header. Attribution is in [NOTICE](NOTICE).

Not audited. Review the code yourself before you put real value on mainnet.

## Contributing

Issues and pull requests are welcome. Please read the [contributing guide](https://github.com/Blockchains/.github/blob/main/CONTRIBUTING.md), [code of conduct](https://github.com/Blockchains/.github/blob/main/CODE_OF_CONDUCT.md) and [security policy](https://github.com/Blockchains/.github/blob/main/SECURITY.md) first.

---
Built by Blockchain Lab — [blockchainlab.com](https://blockchainlab.com/?utm_source=github&utm_medium=readme&utm_campaign=forge-example-usd-savings-vault)
