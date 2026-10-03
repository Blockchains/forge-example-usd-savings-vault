// Copies ABI + bytecode from `forge build` output (../out) into src/artifacts.json for in-browser deployment.
import { readFileSync, writeFileSync, existsSync } from "node:fs";
const need = { UsdSavingsVault: "UsdSavingsVault.sol" };
const out = {};
for (const [name, file] of Object.entries(need)) {
  const p = `../out/${file}/${name}.json`;
  if (!existsSync(p)) throw new Error(`missing ${p} - run 'forge build' in the repo root first`);
  const j = JSON.parse(readFileSync(p, "utf8"));
  out[name] = { abi: j.abi, bytecode: j.bytecode.object };
}
writeFileSync("src/artifacts.json", JSON.stringify(out));
writeFileSync("src/component-map.json", readFileSync("../component-map.json", "utf8"));
console.log("artifacts:", Object.keys(out).join(", "));
