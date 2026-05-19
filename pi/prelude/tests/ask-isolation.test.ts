import { readFileSync } from "node:fs";

function assertIncludes(text: string, marker: string, message: string): void {
  if (!text.includes(marker)) throw new Error(message);
}

const srcPath = process.env.ASK_SOURCE_PATH;
if (!srcPath) throw new Error("ASK_SOURCE_PATH is required");
const src = readFileSync(srcPath, "utf8");

assertIncludes(src, "requires interactive mode", "ask_user should reject non-interactive usage clearly");
assertIncludes(src, "try {", "ask_user execute should be guarded");
assertIncludes(src, "Error: ask_user failed safely.", "ask_user should return safe error on internal failure");
assertIncludes(src, "isError: true", "ask_user internal failure must be marked as error");

console.log("ask isolation contract passed");
