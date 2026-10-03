import { describe, it, expect } from "vitest";
import { readFeed, client, NETWORKS, erc20Abi } from "./chain";
import artifacts from "./artifacts.json";

describe("live Chainlink + WETH reads", () => {
  it("reads the real mainnet ETH/USD feed", async () => {
    const f = await readFeed("mainnet");
    expect(f.description).toBe("ETH / USD");
    expect(f.decimals).toBe(8);
    expect(f.price).toBeGreaterThan(100);
    expect(f.ageSec).toBeLessThan(86400);
  }, 30000);
  it("reads the real Sepolia ETH/USD feed used by the in-browser deploy", async () => {
    const f = await readFeed("sepolia");
    expect(f.description).toBe("ETH / USD");
    expect(f.price).toBeGreaterThan(100);
  }, 30000);
  it("WETH addresses are real WETH contracts", async () => {
    for (const n of ["mainnet", "sepolia"] as const) {
      const sym = await client(n).readContract({ address: NETWORKS[n].weth, abi: erc20Abi, functionName: "symbol" });
      expect(sym).toBe("WETH");
    }
  }, 30000);
  it("ships deployable vault bytecode from forge build", () => {
    expect(artifacts.UsdSavingsVault.bytecode.length).toBeGreaterThan(2000);
  });
});
