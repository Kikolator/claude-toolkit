# Integration Guide

How to use claude-toolkit in your projects.

## Option 1: Copy Files (Simple)

Copy the agents and skills you need into your project's `.claude/` directory.

```bash
# From your project root:
mkdir -p .claude/agents .claude/skills

# Copy specific agents (flat .md files)
cp /path/to/claude-toolkit/agents/code-reviewer.md .claude/agents/
cp /path/to/claude-toolkit/agents/test-writer.md .claude/agents/
cp /path/to/claude-toolkit/agents/verifier.md .claude/agents/

# Copy skills (each skill is a directory containing SKILL.md)
cp -r /path/to/claude-toolkit/skills/commit-push-pr .claude/skills/
cp -r /path/to/claude-toolkit/skills/e2e .claude/skills/

# Copy and customize the CLAUDE.md template
cp /path/to/claude-toolkit/templates/CLAUDE.md ./CLAUDE.md
```

**Pros:** Simple, no external dependencies, files are versioned with your project.
**Cons:** Updates to the toolkit require manual re-copying.

## Option 2: Symlink Agents + Copy Skills (Recommended)

Symlink agents (symlinks work) and copy skills (symlinks are broken for skill discovery).

```bash
# From your project root:
mkdir -p .claude/skills

# Symlink agents — works fine
ln -s /path/to/claude-toolkit/agents .claude/agents

# Copy skills individually — symlinks do NOT work for skills
cp -r /path/to/claude-toolkit/skills/commit-push-pr .claude/skills/commit-push-pr
cp -r /path/to/claude-toolkit/skills/e2e .claude/skills/e2e
```

**Pros:** Agents stay up-to-date automatically.
**Cons:** Skills must be re-copied after toolkit updates.

> **Note:** Add `.claude/agents` to your `.gitignore` if using symlinks. Skills can be committed since they're real files.

## Option 3: Git Submodule

```bash
git submodule add <toolkit-repo-url> .claude/toolkit

# Symlink agents from submodule
ln -s toolkit/agents .claude/agents

# Copy skills from submodule (symlinks don't work for skills)
cp -r .claude/toolkit/skills/commit-push-pr .claude/skills/
cp -r .claude/toolkit/skills/e2e .claude/skills/
```

**Pros:** Versioned, shareable across team.
**Cons:** Submodule management overhead. Skills still need copying.

## Setting Up CLAUDE.md

1. Copy the template: `cp /path/to/claude-toolkit/templates/CLAUDE.md ./CLAUDE.md`
2. Fill in the TODO sections with your project-specific details
3. Commit the CLAUDE.md to your project repo

The CLAUDE.md file is read by Claude Code automatically when it starts a session in your project directory. It provides project context, conventions, and patterns.

## CI / Headless Usage

Claude Code can run in CI environments (GitHub Actions, etc.) in headless mode.

```yaml
# .github/workflows/claude-review.yml
# TODO: Example GitHub Actions workflow for running agents in CI
name: Claude Code Review
on: [pull_request]

jobs:
  review:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      # TODO: Add Claude Code CLI installation step
      # TODO: Add agent invocation step
      # Example:
      # - run: claude --agent code-reviewer --headless
```

> **Note:** Headless mode and CI integration details depend on the Claude Code CLI version. See the [official Claude Code documentation](https://docs.anthropic.com/en/docs/claude-code) for the latest instructions.

## Customization

### Extending Agents

To customize an agent for your project, copy it and modify:

```bash
cp /path/to/claude-toolkit/agents/code-reviewer.md .claude/agents/code-reviewer.md
# Edit .claude/agents/code-reviewer.md to add project-specific rules
```

### Creating New Agents

Use the existing agents as templates. Agents are flat `.md` files in `agents/`:
- **Frontmatter:** `name`, `description`, `tools` (list of allowed tools)
- **Instructions:** Step-by-step behavior guide
- **Output format:** Expected output structure

### Creating New Skills

Skills live in subdirectories: `skills/<name>/SKILL.md`:
- **Frontmatter:** `name`, `description`, `allowed-tools` (note: `allowed-tools`, not `tools`)
- **Instructions:** Step-by-step behavior guide

### Project-Specific Overrides

You can create a `.claude/agents/` file that imports from the toolkit and adds project-specific context:

```markdown
---
name: code-reviewer
description: Project-specific code reviewer
tools: [Glob, Grep, Read, Bash, LS]
---

# Code Reviewer

Follow the standard review process, with these additional project rules:

- All API routes must use the `withAuth` middleware
- Components in `components/ui/` must have Storybook stories
- Database queries must use the query builder, not raw SQL
<!-- ... project-specific rules ... -->
```

## Known Limitations

- **Symlinking `.claude/skills/` is broken** (open bug as of Dec 2025) — Claude Code's skill discovery does not follow symlinks. Skills must be copied into `.claude/skills/`, not symlinked.
- **Agents (`.claude/agents/`) are unaffected** — symlinks work fine for agent discovery.

## TODO
- [ ] Add script to automate toolkit installation
- [ ] Add version pinning support
- [ ] Add team-wide configuration sharing guide
- [ ] Add troubleshooting section
