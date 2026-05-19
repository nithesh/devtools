import { existsSync, readFileSync, statSync } from "node:fs";
import { join } from "node:path";

function fail(message: string): never {
  console.error(`FAIL: ${message}`);
  process.exit(1);
}

function checkFile(path: string): void {
  if (!existsSync(path)) fail(`missing file: ${path}`);
  if (!statSync(path).isFile()) fail(`not a file: ${path}`);
}

const preludeBin = process.env.PI_PRELUDE_BIN;
const preludeDir = process.env.PI_PRELUDE_PACKAGE_DIR;

if (!preludeBin) fail("PI_PRELUDE_BIN is required");
if (!preludeDir) fail("PI_PRELUDE_PACKAGE_DIR is required");

checkFile(preludeBin);

if (!existsSync(preludeDir) || !statSync(preludeDir).isDirectory()) {
  fail(`prelude package dir missing: ${preludeDir}`);
}

const wrapper = readFileSync(preludeBin, "utf8");
if (!wrapper.includes("--extension")) fail("wrapper missing --extension flag");
if (!wrapper.includes(preludeDir)) fail("wrapper does not reference packaged prelude path");

const requiredFiles = [
  "package.json",
  "extensions/mode.ts",
  "extensions/status.ts",
  "extensions/tools-ask.ts",
  "extensions/tools-todo.ts",
  "extensions/tools-web.ts",
  "extensions/guardrails.ts",
];

for (const rel of requiredFiles) checkFile(join(preludeDir, rel));

const toolsAsk = readFileSync(join(preludeDir, "extensions/tools-ask.ts"), "utf8");
if (!toolsAsk.includes('name: "ask_user"')) fail("tools-ask.ts missing ask_user tool registration");
if (!toolsAsk.includes("requires interactive mode")) fail("tools-ask.ts missing non-interactive error contract");
if (!toolsAsk.includes("partial")) fail("tools-ask.ts missing partial-submit UX contract markers");

const toolsTodo = readFileSync(join(preludeDir, "extensions/tools-todo.ts"), "utf8");
if (!toolsTodo.includes('name: "todo"')) fail("tools-todo.ts missing todo tool registration");
for (const action of ["list", "add", "update", "done", "clear"]) {
  if (!toolsTodo.includes(`"${action}"`)) fail(`tools-todo.ts missing '${action}' action`);
}

const toolsWeb = readFileSync(join(preludeDir, "extensions/tools-web.ts"), "utf8");
if (!toolsWeb.includes('name: "web_search"')) fail("tools-web.ts missing web_search tool registration");
if (!toolsWeb.includes('name: "web_fetch"')) fail("tools-web.ts missing web_fetch tool registration");
if (!toolsWeb.includes("BRAVE_API_KEY")) fail("tools-web.ts missing Brave key integration");
if (!toolsWeb.includes("ddgr")) fail("tools-web.ts missing ddgr fallback contract");
if (!toolsWeb.includes("truncateBytes")) fail("tools-web.ts missing truncation helper contract");

const guardrails = readFileSync(join(preludeDir, "extensions/guardrails.ts"), "utf8");
if (!guardrails.includes('pi.on("tool_call"')) fail("guardrails.ts missing tool_call hook");
if (!guardrails.includes('isToolCallEventType("read"')) fail("guardrails.ts missing read-path protection hook");
for (const marker of [".env", ".git", "node_modules", "rm -rf", "git reset --hard", "ctx.ui.confirm"]) {
  if (!guardrails.includes(marker)) fail(`guardrails.ts missing '${marker}' policy marker`);
}

const mode = readFileSync(join(preludeDir, "extensions/mode.ts"), "utf8");
if (!mode.includes('registerCommand("mode"')) fail("mode.ts missing /mode command registration");
for (const hotkey of ["ctrl+alt+u", "ctrl+alt+p", "ctrl+alt+r", "ctrl+alt+d"]) {
  if (!mode.includes(hotkey)) fail(`mode.ts missing '${hotkey}' hotkey contract`);
}

console.log("pi.prelude contract check passed");
