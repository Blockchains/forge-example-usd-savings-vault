import { createPublicClient, http, parseAbi, formatUnits, type Address } from "viem";
import { mainnet, sepolia } from "viem/chains";

export const feedAbi = parseAbi([
  "function latestRoundData() view returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)",
  "function decimals() view returns (uint8)",
  "function description() view returns (string)",
]);
export const erc20Abi = parseAbi(["function symbol() view returns (string)", "function decimals() view returns (uint8)"]);

export const NETWORKS = {
  mainnet: {
    chain: mainnet,
    rpc: "https://ethereum-rpc.publicnode.com",
    weth: "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2" as Address,
    feed: "0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419" as Address,
    explorer: "https://etherscan.io",
  },
  sepolia: {
    chain: sepolia,
    rpc: "https://ethereum-sepolia-rpc.publicnode.com",
    weth: "0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9" as Address,
    feed: "0x694AA1769357215DE4FAC081bf1f309aDC325306" as Address,
    explorer: "https://sepolia.etherscan.io",
  },
} as const;
export type Net = keyof typeof NETWORKS;

export const client = (n: Net) => createPublicClient({ chain: NETWORKS[n].chain, transport: http(NETWORKS[n].rpc) });

export async function readFeed(n: Net) {
  const c = client(n);
  const feed = NETWORKS[n].feed;
  const [round, dec, desc] = await Promise.all([
    c.readContract({ address: feed, abi: feedAbi, functionName: "latestRoundData" }),
    c.readContract({ address: feed, abi: feedAbi, functionName: "decimals" }),
    c.readContract({ address: feed, abi: feedAbi, functionName: "description" }),
  ]);
  const [, answer, , updatedAt] = round;
  return { description: desc, decimals: dec, price: Number(formatUnits(answer, dec)), answer, updatedAt: Number(updatedAt), ageSec: Math.floor(Date.now() / 1000) - Number(updatedAt) };
}

/** USD value of `eth` whole units at the given price, mirroring UsdSavingsVault.assetsToUsd. */
export const usdValue = (eth: number, price: number) => eth * price;
