import { readFileSync } from "node:fs";

function assertIncludes(text: string, marker: string, message: string): void {
  if (!text.includes(marker)) throw new Error(message);
}

const srcPath = process.env.GUARDRAILS_SOURCE_PATH;
if (!srcPath) throw new Error("GUARDRAILS_SOURCE_PATH is required");
const src = readFileSync(srcPath, "utf8");

assertIncludes(src, "try {", "guardrails tool_call handler should be guarded");
assertIncludes(src, "handleError(ctx, err)", "guardrails should report degradation");
assertIncludes(src, "Guardrails degraded:", "guardrails should notify user on degradation");
assertIncludes(src, "Guardrails internal error; command blocked safely.", "guardrails should fail closed on internal errors");

console.log("guardrails isolation contract passed");
