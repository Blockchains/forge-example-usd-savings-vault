// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {UsdSavingsVault} from "../src/UsdSavingsVault.sol";

/// @notice Deploys the vault. Defaults: Ethereum mainnet WETH9 + Chainlink ETH/USD.
///         Sepolia: ASSET=0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9 FEED=0x694AA1769357215DE4FAC081bf1f309aDC325306
/// forge script script/Deploy.s.sol --rpc-url $RPC_URL --account <keystore> --broadcast
contract Deploy is Script {
    function run() external returns (UsdSavingsVault vault) {
        address asset = vm.envOr("ASSET", address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2));
        address feed = vm.envOr("FEED", address(0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419));
        uint256 capUsd = vm.envOr("CAP_USD", uint256(100_000e18));
        uint256 maxAge = vm.envOr("MAX_PRICE_AGE", uint256(1 days));
        vm.startBroadcast();
        address admin = vm.envOr("ADMIN", msg.sender);
        vault = new UsdSavingsVault(
            IERC20Metadata(asset), AggregatorV3Interface(feed), "USD Savings Vault", "usVAULT", admin, capUsd, maxAge
        );
        vm.stopBroadcast();
        console2.log("UsdSavingsVault", address(vault));
        console2.log("price (USD, 1e18)", vault.assetPriceUsd());
    }
}
