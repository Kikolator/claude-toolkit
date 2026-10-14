# CLAUDE.md — claude-toolkit

This repo is a **Claude Code plugin marketplace**: a personal collection of reusable skills,
subagents, and `CLAUDE.md` templates, distributed as installable plugins.

It is not an npm package and has no build step.

## Structure

```
.claude-plugin/marketplace.json            # marketplace manifest — lists every plugin
plugins/<plugin>/.claude-plugin/plugin.json
plugins/<plugin>/skills/<name>/SKILL.md    # skills (subdir with SKILL.md)
plugins/<plugin>/agents/<name>.md          # subagents (flat .md files)
templates/                                 # CLAUDE.md starters (copied by hand, not shipped)
```

A plugin dir may also hold `commands/`, `hooks/`, `scripts/`, `.mcp.json`, and `evals/`.

## Plugins

- **`nic-core`** — stack-agnostic. Assumes only git and `gh`. Workflow skills (worktrees,
  issue-to-PR, release planning, session handoff) and generic review agents.
- **`nic-nextjs-supabase`** — assumes Next.js App Router, Supabase, Vitest, Playwright.
  Scaffolding, E2E, PR test-plan verification, and stack-specific review agents.

Put a new component in `nic-core` only if it would work in a repo with no framework.
Anything that names Next.js, Supabase, Vitest, Playwright, or Stripe goes in the stack plugin.

## Frontmatter Conventions

**Agents** (`agents/<name>.md`) use `tools:`:
```yaml
---
name: agent-name
description: What the agent does
tools: Read, Grep, Glob, Bash
---
```

**Skills** (`skills/<name>/SKILL.md`) use `allowed-tools:`:
```yaml
---
name: skill-name
description: What the skill does and when to trigger it
allowed-tools: Bash, Read
---
```

These are different fields. Do not mix them.

A skill's `description` is what the model matches on, so write it as trigger phrases the user
would actually type, not as a summary. Add `disable-model-invocation: true` for a skill that
should only ever run when invoked explicitly as `/<name>`.

## Naming

- Files and directories: `kebab-case`
- Agent/skill names in frontmatter: `kebab-case`, matching the file or directory name
- Plugin names: `kebab-case`, matching the directory under `plugins/`

## Adding a Skill or Agent

1. Create the file under the right plugin (see **Plugins** above).
2. Write the body: step-by-step instructions, then an output format section.
3. Update that plugin's table in `README.md`.
4. Validate and confirm discovery (see **Testing Changes**).

Adding a whole new plugin also needs an entry in `.claude-plugin/marketplace.json`
with `"source": "./plugins/<name>"`, and its own `.claude-plugin/plugin.json`.

## Testing Changes

Never symlink into a project — load the plugins for one session instead:

```bash
claude --plugin-dir /path/to/claude-toolkit/plugins      # a dir named `plugins` loads every child
```

Then validate and check the component inventory:

```bash
claude plugin validate .                                  # marketplace manifest
claude plugin validate plugins/<plugin>                    # plugin manifest
claude plugin validate plugins/<plugin>/skills             # component frontmatter
claude plugin validate plugins/<plugin>/agents
claude --plugin-dir plugins plugin details <plugin>        # inventory + projected token cost
```

`plugin details` is the real check — it proves Claude Code discovers every component, and shows
the always-on token cost each one adds to every session. Watch that number; a bloated
`description` is paid for in every session whether the skill fires or not.

Skills with an `evals/` suite can be scored with `claude plugin eval <plugin>`.

## Releasing

Pushing to `main` is the release — installed plugins pick it up on
`claude plugin marketplace update claude-toolkit` + `claude plugin update <plugin>`.

Bump `version` in the plugin's `plugin.json` for a meaningful change, then:

```bash
claude plugin tag plugins/<plugin>    # cuts <name>--v<version>, validating manifest agreement
```

## Git

- Work on a feature branch, PR into `main`.
- Conventional commits: `feat:` · `fix:` · `refactor:` · `docs:` · `chore:`
- Scope by plugin or component where it helps: `feat(nic-core): ...`

## Don't

- Don't add a `package.json` or `bin/` CLI back. Distribution is the marketplace.
- Don't commit `*.skill` zip bundles — they were `npx skills` build artifacts.
- Don't tell users to copy or symlink components into a project's `.claude/`.
- Don't put a stack-specific component in `nic-core`.
