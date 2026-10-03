// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {UsdSavingsVault} from "../src/UsdSavingsVault.sol";

interface IWETH9 is IERC20Metadata {
    function deposit() external payable;
}

/// @notice Same constructor args the web app uses for its in-browser Sepolia deploy, against live Sepolia contracts.
contract SepoliaDeployForkTest is Test {
    IWETH9 constant WETH = IWETH9(0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9);
    AggregatorV3Interface constant ETH_USD = AggregatorV3Interface(0x694AA1769357215DE4FAC081bf1f309aDC325306);

    function test_DeployAndDepositOnSepoliaFork() public {
        vm.createSelectFork(vm.envOr("SEPOLIA_RPC_URL", string("https://ethereum-sepolia-rpc.publicnode.com")));
        address user = makeAddr("user");
        UsdSavingsVault vault = new UsdSavingsVault(WETH, ETH_USD, "USD Savings WETH", "usWETH", user, 10_000e18, 2 days);
        uint256 price = vault.assetPriceUsd();
        assertGt(price, 100e18);
        vm.deal(user, 1 ether);
        vm.startPrank(user);
        WETH.deposit{value: 1 ether}();
        WETH.approve(address(vault), 1 ether);
        vault.deposit(1 ether, user);
        vm.stopPrank();
        assertEq(vault.totalAssetsUsd(), price);
    }
}
