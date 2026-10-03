// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {UsdSavingsVault} from "../src/UsdSavingsVault.sol";

interface IWETH9 is IERC20Metadata {
    function deposit() external payable;
}

/// @notice Runs against a live Ethereum mainnet fork: real WETH9 and the real Chainlink ETH/USD feed. No mocks.
contract UsdSavingsVaultForkTest is Test {
    IWETH9 constant WETH = IWETH9(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    AggregatorV3Interface constant ETH_USD = AggregatorV3Interface(0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419);

    UsdSavingsVault vault;
    address admin = makeAddr("admin");
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    address treasury = makeAddr("treasury");

    function setUp() public {
        vm.createSelectFork(vm.envOr("MAINNET_RPC_URL", string("https://ethereum-rpc.publicnode.com")));
        vault = new UsdSavingsVault(WETH, ETH_USD, "USD Savings WETH", "usWETH", admin, 0, 1 days);
        _fund(alice, 10 ether);
        _fund(bob, 10 ether);
    }

    function _fund(address who, uint256 amt) internal {
        vm.deal(who, amt);
        vm.startPrank(who);
        WETH.deposit{value: amt}();
        WETH.approve(address(vault), type(uint256).max);
        vm.stopPrank();
    }

    function _feedPrice18() internal view returns (uint256) {
        (, int256 answer,,,) = ETH_USD.latestRoundData();
        return uint256(answer) * 10 ** (18 - ETH_USD.decimals());
    }

    function test_PriceComesFromLiveChainlinkFeed() public view {
        uint256 p = vault.assetPriceUsd();
        assertEq(p, _feedPrice18());
        assertGt(p, 100e18, "ETH above $100");
        assertLt(p, 100_000e18, "ETH below $100k");
    }

    function test_DepositAndUsdValuation() public {
        vm.prank(alice);
        uint256 shares = vault.deposit(2 ether, alice);
        assertEq(vault.balanceOf(alice), shares);
        assertEq(vault.totalAssets(), 2 ether);
        assertEq(vault.totalAssetsUsd(), 2 * _feedPrice18());
        assertApproxEqAbs(vault.balanceOfUsd(alice), 2 * _feedPrice18(), 1e12);
    }

    function test_RedeemReturnsAssets() public {
        vm.startPrank(alice);
        uint256 shares = vault.deposit(3 ether, alice);
        uint256 out = vault.redeem(shares, alice, alice);
        vm.stopPrank();
        assertApproxEqAbs(out, 3 ether, 1);
        assertApproxEqAbs(WETH.balanceOf(alice), 10 ether, 1);
    }

    function test_EntryFeeGoesToTreasury() public {
        vm.prank(admin);
        vault.setEntryFee(50, treasury); // 0.5%
        uint256 expectedShares = vault.previewDeposit(1 ether);
        vm.prank(alice);
        uint256 shares = vault.deposit(1 ether, alice);
        assertEq(shares, expectedShares);
        uint256 fee = WETH.balanceOf(treasury);
        assertApproxEqAbs(fee, uint256(1 ether) * 50 / 10_050, 1);
        assertEq(vault.totalAssets() + fee, 1 ether);
        // mint path charges the same fee on top
        uint256 cost = vault.previewMint(shares);
        vm.prank(bob);
        uint256 paid = vault.mint(shares, bob);
        assertEq(paid, cost);
        assertApproxEqAbs(paid, 1 ether, 2);
    }

    function test_UsdDepositCap() public {
        uint256 price = _feedPrice18();
        vm.prank(admin);
        vault.setDepositCapUsd(1_000e18); // $1,000
        uint256 maxIn = vault.maxDeposit(alice);
        assertApproxEqAbs(maxIn, uint256(1_000e18) * 1e18 / price, 1);
        vm.prank(alice);
        vault.deposit(maxIn, alice);
        assertApproxEqAbs(vault.totalAssetsUsd(), 1_000e18, 1e10);
        assertLe(vault.maxDeposit(bob), 1);
        vm.prank(bob);
        vm.expectRevert();
        vault.deposit(0.01 ether, bob);
    }

    function test_StaleOracleBlocksDeposits() public {
        vm.prank(admin);
        vault.setDepositCapUsd(1_000_000e18);
        (,,, uint256 updatedAt,) = ETH_USD.latestRoundData();
        vm.warp(updatedAt + 1 days + 1);
        assertEq(vault.maxDeposit(alice), 0);
        vm.expectRevert(abi.encodeWithSelector(UsdSavingsVault.StalePrice.selector, updatedAt, 1 days));
        vault.assetPriceUsd();
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(ERC4626.ERC4626ExceededMaxDeposit.selector, alice, 1 ether, 0));
        vault.deposit(1 ether, alice);
    }

    function test_OnlyRiskManagerCanConfigure() public {
        bytes32 role = vault.RISK_MANAGER_ROLE();
        vm.startPrank(alice);
        vm.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, alice, role));
        vault.setDepositCapUsd(1);
        vm.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, alice, role));
        vault.setEntryFee(10, alice);
        vm.stopPrank();
        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(UsdSavingsVault.FeeTooHigh.selector, 501));
        vault.setEntryFee(501, treasury);
        // admin can delegate the role
        vm.prank(admin);
        vault.grantRole(role, bob);
        vm.prank(bob);
        vault.setDepositCapUsd(5e18);
        assertEq(vault.depositCapUsd(), 5e18);
    }

    function test_InflationAttackIsUnprofitable() public {
        // attacker deposits 1 wei then donates 5 WETH to inflate share price
        vm.startPrank(bob);
        vault.deposit(1, bob);
        WETH.transfer(address(vault), 5 ether);
        vm.stopPrank();
        vm.prank(alice);
        uint256 shares = vault.deposit(1 ether, alice);
        assertGt(shares, 0);
        vm.prank(alice);
        uint256 back = vault.redeem(shares, alice, alice);
        assertGt(back, 0.99 ether, "victim keeps >99%");
    }

    function testFuzz_DepositRedeemRoundTrip(uint96 amount) public {
        uint256 amt = bound(uint256(amount), 1e6, 10 ether);
        vm.startPrank(alice);
        uint256 shares = vault.deposit(amt, alice);
        uint256 out = vault.redeem(shares, alice, alice);
        vm.stopPrank();
        assertLe(out, amt);
        assertApproxEqAbs(out, amt, 1);
    }
}
