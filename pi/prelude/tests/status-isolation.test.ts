import { readFileSync } from "node:fs";

function assertIncludes(text: string, marker: string, message: string): void {
  if (!text.includes(marker)) throw new Error(message);
}

const srcPath = process.env.STATUS_SOURCE_PATH;
if (!srcPath) throw new Error("STATUS_SOURCE_PATH is required");
const src = readFileSync(srcPath, "utf8");

assertIncludes(src, "fallbackStatus(ctx, used, max, pct)", "status must always set fallback status");
assertIncludes(src, "ctx.ui.setFooter(undefined)", "status must disable footer on failure");
assertIncludes(src, "Cockpit footer disabled:", "status must notify on footer disable");
assertIncludes(src, "try {\n      ctx.ui.setFooter", "status must guard setFooter with try/catch");
assertIncludes(src, "cockpit unavailable, using fallback status", "status render must degrade safely");

console.log("status isolation contract passed");
