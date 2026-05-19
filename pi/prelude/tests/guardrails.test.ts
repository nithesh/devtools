function assert(condition: boolean, message: string): void {
  if (!condition) throw new Error(message);
}

function eq<T>(actual: T, expected: T, message: string): void {
  if (actual !== expected) {
    throw new Error(`${message}\nexpected: ${String(expected)}\nactual: ${String(actual)}`);
  }
}

function normalizeCmd(text: string): string {
  return text.toLowerCase().replace(/\s+/g, " ").trim();
}

function normalizeRel(p: string): string {
  return p.replace(/\\/g, "/").replace(/^\.(\/|$)/, "").replace(/^\/+/, "");
}

function globToRegExp(glob: string): RegExp {
  let s = "";
  for (let i = 0; i < glob.length; i++) {
    const c = glob[i];
    if (c === "*") {
      if (glob[i + 1] === "*") {
        s += ".*";
        i++;
      } else {
        s += "[^/]*";
      }
      continue;
    }
    if (c === "?") {
      s += "[^/]";
      continue;
    }
    if (/[\\^$+?.()|{}\[\]]/.test(c)) {
      s += `\\${c}`;
    } else {
      s += c;
    }
  }
  return new RegExp(`^${s}$`);
}

function patternMatches(relToCwd: string, relToRoot: string, pattern: string): boolean {
  const normalizedPattern = normalizeRel(pattern.trim());
  const anchored = pattern.trim().startsWith("/");
  const target = normalizeRel(anchored ? relToRoot : relToCwd);
  const basePattern = normalizedPattern.endsWith("/") ? `${normalizedPattern}**` : normalizedPattern;
  const rx = globToRegExp(basePattern);

  if (anchored) {
    return rx.test(target);
  }
  if (!normalizedPattern.includes("/")) {
    return target.split("/").some((seg) => rx.test(seg));
  }
  return rx.test(target);
}

function splitCommandSegments(command: string): string[] {
  return command
    .split(/&&|\|\||;|\||\n/g)
    .map((s) => normalizeCmd(s))
    .filter((s) => s.length > 0);
}

function matchesPrefix(segment: string, prefix: string): boolean {
  return segment === prefix || segment.startsWith(`${prefix} `);
}

interface ResolvedRules {
  exact: string[];
  prefix: string[];
}

function matchRule(segment: string, rules: ResolvedRules): string | null {
  const exact = rules.exact.find((r) => segment === normalizeCmd(r));
  if (exact) return exact;

  const pref = rules.prefix.find((r) => matchesPrefix(segment, normalizeCmd(r)));
  if (pref) return pref;

  return null;
}

const rules: ResolvedRules = {
  exact: ["git reset --hard"],
  prefix: ["rm -rf", "sudo"],
};

{
  const segs = splitCommandSegments("echo hi && rm -rf /tmp/x ; sudo ls | cat");
  eq(segs.length, 4, "splitCommandSegments should split by shell operators");
  eq(segs[1], "rm -rf /tmp/x", "segment normalization should preserve command tokens");
}

{
  assert(matchesPrefix("rm -rf /tmp/x", "rm -rf"), "prefix match should accept command with args");
  assert(!matchesPrefix("echo rm -rf /tmp/x", "rm -rf"), "prefix match should require command start");
}

{
  eq(matchRule("git reset --hard", rules), "git reset --hard", "exact rule should match exactly");
  eq(matchRule("rm -rf /tmp/x", rules), "rm -rf", "prefix rule should match start");
  eq(matchRule("sudo apt update", rules), "sudo", "prefix rule should match sudo command");
  eq(matchRule("echo safe", rules), null, "safe command should not match");
}

{
  assert(patternMatches(".env", ".env", "/.env"), "root-anchored /.env should match repo root .env");
  assert(!patternMatches("apps/a/.env", "apps/a/.env", "/.env"), "root-anchored /.env should not match nested .env");
  assert(patternMatches("apps/a/.env", "apps/a/.env", "**/*.env"), "glob pattern should match nested env files");
  assert(patternMatches(".env.example", ".env.example", "/.env.example"), "allow rule can match root env example");
}

console.log("guardrails matcher tests passed");
