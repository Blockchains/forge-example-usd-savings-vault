import { createWalletClient, custom, formatUnits, isAddress, parseAbi, type Address, type Hex } from "viem";
import artifacts from "./artifacts.json";
import map from "./component-map.json";
import { NETWORKS, readFeed, client, usdValue, type Net } from "./chain";

const $ = (id: string) => document.getElementById(id)!;
const vaultAbi = parseAbi([
  "function totalAssets() view returns (uint256)",
  "function totalAssetsUsd() view returns (uint256)",
  "function assetPriceUsd() view returns (uint256)",
  "function depositCapUsd() view returns (uint256)",
  "function entryFeeBps() view returns (uint256)",
  "function totalSupply() view returns (uint256)",
]);

$("idea").textContent = map.idea;
$("lic").innerHTML = `Project licence: <b>${map.license.project_license}</b>`;
const tb = $("map").querySelector("tbody")!;
for (const s of map.selected as any[]) {
  const tr = document.createElement("tr");
  tr.innerHTML = `<td>${s.capability}</td><td><a href="https://github.com/${s.fork}/blob/${s.commit}/${s.path}">${s.name}</a><br><span class="mono">${s.path}</span></td><td><a href="https://github.com/${s.fork}">${s.fork}</a><br>upstream ${s.upstream}</td><td>${s.license}</td>`;
  tb.appendChild(tr);
}
$("copied").textContent = `${map.copied_files.length} source files copied unmodified (import closure) - see NOTICE.`;

let mainPrice = 0;
async function refresh() {
  for (const n of ["mainnet", "sepolia"] as Net[]) {
    try {
      const f = await readFeed(n);
      if (n === "mainnet") mainPrice = f.price;
      $(`feed-${n}`).innerHTML = `<b>$${f.price.toLocaleString(undefined, { maximumFractionDigits: 2 })}</b> ${f.description} - updated ${Math.round(f.ageSec / 60)} min ago <a href="${NETWORKS[n].explorer}/address/${NETWORKS[n].feed}">feed</a>`;
    } catch (e: any) { $(`feed-${n}`).textContent = `RPC error: ${e.shortMessage ?? e.message}`; }
  }
  calc();
}
function calc() {
  const v = Number(($("eth") as HTMLInputElement).value || 0);
  const fee = Number(($("fee") as HTMLInputElement).value || 0);
  const net = v * (1 - fee / (10000 + fee));
  $("calc").textContent = mainPrice ? `${v} WETH = $${usdValue(v, mainPrice).toFixed(2)}; after a ${fee} bps entry fee, $${usdValue(net, mainPrice).toFixed(2)} is credited as shares.` : "";
}
$("eth").addEventListener("input", calc); $("fee").addEventListener("input", calc);
refresh(); setInterval(refresh, 60000);

$("lookup").addEventListener("input", async (ev) => {
  const a = (ev.target as HTMLInputElement).value.trim();
  const n = ($("lnet") as HTMLSelectElement).value as Net;
  if (!isAddress(a)) { $("vault").textContent = ""; return; }
  try {
    const c = client(n);
    const r = (fn: any) => c.readContract({ address: a as Address, abi: vaultAbi, functionName: fn }) as Promise<bigint>;
    const [ta, usd, cap, fee, ts] = await Promise.all([r("totalAssets"), r("totalAssetsUsd"), r("depositCapUsd"), r("entryFeeBps"), r("totalSupply")]);
    $("vault").textContent = `assets ${formatUnits(ta, 18)} WETH = $${Number(formatUnits(usd, 18)).toFixed(2)} | cap $${cap === 0n ? "none" : formatUnits(cap, 18)} | fee ${fee} bps | shares ${formatUnits(ts, 24)}`;
  } catch (e: any) { $("vault").textContent = `Not a UsdSavingsVault on ${n}: ${e.shortMessage ?? e.message}`; }
});

$("deploy").addEventListener("click", async () => {
  const log = (m: string) => ($("deploylog").innerHTML += m + "<br>");
  const eth = (window as any).ethereum;
  if (!eth) return log("No injected wallet found.");
  const n: Net = "sepolia";
  const wallet = createWalletClient({ chain: NETWORKS[n].chain, transport: custom(eth) });
  const [account] = await wallet.requestAddresses();
  await wallet.switchChain({ id: NETWORKS[n].chain.id }).catch(() => {});
  const capUsd = BigInt(Math.round(Number(($("cap") as HTMLInputElement).value || 0))) * 10n ** 18n;
  try {
    const a = artifacts.UsdSavingsVault;
    const hash = await wallet.deployContract({ account, abi: a.abi as any, bytecode: a.bytecode as Hex,
      args: [NETWORKS[n].weth, NETWORKS[n].feed, "USD Savings WETH", "usWETH", account, capUsd, 2n * 86400n] as any });
    log(`tx ${hash}`);
    const rc = await client(n).waitForTransactionReceipt({ hash });
    log(`UsdSavingsVault deployed at <a href="${NETWORKS[n].explorer}/address/${rc.contractAddress}">${rc.contractAddress}</a>. Wrap Sepolia ETH to WETH, approve the vault and call deposit().`);
    ($("lookup") as HTMLInputElement).value = rc.contractAddress!; ($("lnet") as HTMLSelectElement).value = n;
    $("lookup").dispatchEvent(new Event("input"));
  } catch (e: any) { log(`Error: ${e.shortMessage ?? e.message}`); }
});
