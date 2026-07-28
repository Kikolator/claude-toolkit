#!/usr/bin/env node

import { readdir, readFile, mkdir, copyFile } from "node:fs/promises";
import { join, dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { existsSync } from "node:fs";

const __dirname = dirname(fileURLToPath(import.meta.url));
const TOOLKIT_ROOT = resolve(__dirname, "..");
const AGENTS_DIR = join(TOOLKIT_ROOT, "agents");

const TARGET_AGENTS = join(process.cwd(), ".claude", "agents");

// Skills are NOT managed here. They moved to the vercel-labs `skills` CLI
// (`npx skills`), which supports local/github/well-known sources and a
// skills-lock.json. This CLI distributes subagents only — the one thing
// `npx skills` does not do. Keeping the two concerns in separate tools avoids
// the drift you get when two installers write the same files.

// Colors (no dependencies)
const bold = (s) => `\x1b[1m${s}\x1b[0m`;
const green = (s) => `\x1b[32m${s}\x1b[0m`;
const yellow = (s) => `\x1b[33m${s}\x1b[0m`;
const cyan = (s) => `\x1b[36m${s}\x1b[0m`;
const dim = (s) => `\x1b[2m${s}\x1b[0m`;
const red = (s) => `\x1b[31m${s}\x1b[0m`;

const [, , command, ...args] = process.argv;

const commands = {
  init,
  update,
  add,
  list,
  diff,
  help,
};

if (!command || command === "--help" || command === "-h") {
  help();
} else if (commands[command]) {
  Promise.resolve(commands[command](args)).catch((err) => {
    console.error(red(`Error: ${err.message}`));
    process.exit(1);
  });
} else {
  console.error(red(`Unknown command: ${command}`));
  help();
  process.exit(1);
}

// ── Commands ──────────────────────────────────────────────

async function init(args) {
  const filter = parseFilter(args);
  console.log(bold("\nclaude-toolkit init\n"));

  await mkdir(TARGET_AGENTS, { recursive: true });

  const agents = await getAgents();
  const filtered = filter ? agents.filter((a) => filter.includes(a.name)) : agents;

  let added = 0;
  let skipped = 0;

  for (const agent of filtered) {
    const target = join(TARGET_AGENTS, agent.file);
    if (existsSync(target)) {
      console.log(dim(`  skip  ${agent.file} (already exists)`));
      skipped++;
    } else {
      await copyFile(agent.path, target);
      console.log(green(`  add   ${agent.file}`));
      added++;
    }
  }

  console.log(`\n${green(`${added} added`)}, ${dim(`${skipped} skipped`)}\n`);

  if (added > 0) {
    console.log(dim("Commit .claude/ to your repo for Claude Code Web support."));
    console.log(dim("Run `claude-toolkit update` later to refresh.\n"));
  }

  console.log(dim("Skills are managed separately — see `npx skills`.\n"));
}

async function update() {
  console.log(bold("\nclaude-toolkit update\n"));

  if (!existsSync(join(process.cwd(), ".claude"))) {
    console.error(red("No .claude/ directory found. Run `claude-toolkit init` first."));
    process.exit(1);
  }

  const agents = await getAgents();

  let updated = 0;
  let unchanged = 0;
  let added = 0;

  await mkdir(TARGET_AGENTS, { recursive: true });
  for (const agent of agents) {
    const target = join(TARGET_AGENTS, agent.file);
    if (!existsSync(target)) {
      await copyFile(agent.path, target);
      console.log(green(`  add   ${agent.file}`));
      added++;
    } else {
      const source = await readFile(agent.path, "utf-8");
      const current = await readFile(target, "utf-8");
      if (source !== current) {
        await copyFile(agent.path, target);
        console.log(yellow(`  update ${agent.file}`));
        updated++;
      } else {
        unchanged++;
      }
    }
  }

  console.log(
    `\n${green(`${added} added`)}, ${yellow(`${updated} updated`)}, ${dim(`${unchanged} unchanged`)}\n`
  );

  console.log(dim("Skills are managed separately — run `npx skills update` for those.\n"));
}

async function add(args) {
  if (args.length === 0) {
    console.error(red("Usage: claude-toolkit add <name> [name...]"));
    console.error(dim("Example: claude-toolkit add code-reviewer silent-failure-hunter"));
    process.exit(1);
  }

  console.log(bold("\nclaude-toolkit add\n"));

  await mkdir(TARGET_AGENTS, { recursive: true });
  const agents = await getAgents();

  for (const name of args) {
    const agent = agents.find((a) => a.name === name);
    if (agent) {
      const target = join(TARGET_AGENTS, agent.file);
      await copyFile(agent.path, target);
      console.log(green(`  add   agents/${agent.file}`));
    } else {
      console.error(red(`  not found: ${name}`));
      console.error(dim(`  Run 'claude-toolkit list' to see available agents (skills → npx skills).`));
    }
  }

  console.log();
}

async function diff() {
  console.log(bold("\nclaude-toolkit diff\n"));

  if (!existsSync(join(process.cwd(), ".claude"))) {
    console.error(red("No .claude/ directory found. Run `claude-toolkit init` first."));
    process.exit(1);
  }

  const agents = await getAgents();

  let newer = 0;
  let missing = 0;
  let current = 0;

  for (const agent of agents) {
    const target = join(TARGET_AGENTS, agent.file);
    if (!existsSync(target)) {
      console.log(cyan(`  missing  ${agent.file}`));
      missing++;
    } else {
      const source = await readFile(agent.path, "utf-8");
      const cur = await readFile(target, "utf-8");
      if (source !== cur) {
        console.log(yellow(`  outdated ${agent.file}`));
        newer++;
      } else {
        current++;
      }
    }
  }

  console.log(
    `\n${current} current, ${yellow(`${newer} outdated`)}, ${cyan(`${missing} missing`)}\n`
  );

  if (newer > 0 || missing > 0) {
    console.log(dim("Run `claude-toolkit update` to sync.\n"));
  }
}

async function list() {
  console.log(bold("\nclaude-toolkit — available agents\n"));

  const agents = await getAgents();

  console.log(bold("Agents:"));
  for (const agent of agents) {
    const desc = await getDescription(agent.path);
    const installed = existsSync(join(TARGET_AGENTS, agent.file));
    const marker = installed ? green("✓") : dim("·");
    console.log(`  ${marker} ${bold(agent.name.padEnd(24))} ${dim(desc)}`);
  }

  console.log(dim("\n✓ = installed in current project"));
  console.log(dim("Skills are managed separately — see `npx skills`.\n"));
}

function help() {
  console.log(`
${bold("claude-toolkit")} — subagents for Claude Code

${bold("Usage:")}
  claude-toolkit ${cyan("init")}              Copy all agents into .claude/agents/
  claude-toolkit ${cyan("init")} --only a,b   Copy only specific agents
  claude-toolkit ${cyan("update")}            Refresh installed agents
  claude-toolkit ${cyan("add")} <name...>     Add specific agents
  claude-toolkit ${cyan("diff")}              Show what's outdated or missing
  claude-toolkit ${cyan("list")}              List all available agents
  claude-toolkit ${cyan("help")}              Show this help

${bold("Skills")} are managed separately with ${cyan("npx skills")} (vercel-labs/skills) —
this CLI distributes subagents only.

${bold("Examples:")}
  npx claude-toolkit init
  npx claude-toolkit add code-reviewer silent-failure-hunter
  npx claude-toolkit update
  npx claude-toolkit diff
`);
}

// ── Helpers ───────────────────────────────────────────────

async function getAgents() {
  const files = await readdir(AGENTS_DIR);
  return files
    .filter((f) => f.endsWith(".md"))
    .sort()
    .map((f) => ({
      name: f.replace(".md", ""),
      file: f,
      path: join(AGENTS_DIR, f),
    }));
}

async function getDescription(filePath) {
  try {
    const content = await readFile(filePath, "utf-8");
    const match = content.match(/^---\n[\s\S]*?description:\s*[>|]?\s*\n?([\s\S]*?)\n(?:tools|allowed-tools|model|argument|disable|color|---)/m);
    if (match) {
      return match[1].replace(/\s+/g, " ").trim().slice(0, 80);
    }
    const simple = content.match(/description:\s*["']?(.+?)["']?\s*$/m);
    if (simple) return simple[1].trim().slice(0, 80);
    return "";
  } catch {
    return "";
  }
}

function parseFilter(args) {
  const only = args.find((a) => a.startsWith("--only"));
  if (!only) return null;
  const value = only.includes("=") ? only.split("=")[1] : args[args.indexOf(only) + 1];
  if (!value) return null;
  return value.split(",").map((s) => s.trim());
}
