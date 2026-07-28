# CLAUDE.md — claude-toolkit

This repo is a personal Claude Code toolkit: reusable agents, skills, and templates for Next.js / Supabase / TypeScript projects.

## Structure

```
agents/<name>.md                 # Sub-agents (flat .md files)
skills/<name>/SKILL.md           # Skills (subdirectory with SKILL.md)
templates/                       # Project templates (CLAUDE.md starter)
```

## Frontmatter Conventions

**Agents** (`agents/<name>.md`) use `tools:` to declare allowed tools:
```yaml
---
name: agent-name
description: What the agent does
tools:
  - Glob
  - Grep
  - Read
  - Bash
---
```

**Skills** (`skills/<name>/SKILL.md`) use `allowed-tools:` to declare allowed tools:
```yaml
---
name: skill-name
description: What the skill does
allowed-tools:
  - Bash
  - Read
---
```

These are different fields — `tools:` for agents, `allowed-tools:` for skills. Do not mix them.

## Naming

- Files and directories: `kebab-case`
- Agent/skill names in frontmatter: `kebab-case`

## Adding New Agents

1. Create `agents/<name>.md` with `name`, `description`, and `tools` in frontmatter
2. Write step-by-step instructions in the body
3. Include an output format section
4. Update `README.md` with the new agent

## Adding New Skills

1. Create `skills/<name>/SKILL.md` with `name`, `description`, and `allowed-tools` in frontmatter
2. Write instructions in the body
3. Update `README.md` with the new skill

Skills are installed into projects with [`npx skills`](https://github.com/vercel-labs/skills) (this repo's `skills/` dir is a source), **not** the toolkit CLI — which handles subagents only.

## Testing Changes

Symlink into a test project to verify Claude Code discovers the agents/skills:
```bash
ln -s /path/to/claude-toolkit/agents <project>/.claude/agents
ln -s /path/to/claude-toolkit/skills <project>/.claude/skills
```
