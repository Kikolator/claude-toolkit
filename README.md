# claude-toolkit

Reusable subagents and CLAUDE.md templates for Claude Code — built for Next.js, Supabase, and TypeScript projects.

14 subagents. Zero dependencies. (Skills live in `skills/` and are installed with [`npx skills`](https://github.com/vercel-labs/skills), not this CLI.)

## Install

### Option A: From npm (after publishing)

From your **project root**:

```bash
npx claude-toolkit init
```

### Option B: From a local clone (now)

```bash
# Clone once (anywhere on your machine)
git clone https://github.com/Kikolator/claude-toolkit.git ~/claude-toolkit

# From your project root, run the CLI
cd ~/my-project
node ~/claude-toolkit/bin/cli.mjs init
```

Both options copy all subagents into your project's `.claude/agents/`. **Commit the `.claude/` directory** — it's required for Claude Code Web and CI. (Skills are installed separately with [`npx skills`](https://github.com/vercel-labs/skills).)

### Pick specific items

```bash
node ~/claude-toolkit/bin/cli.mjs add code-reviewer silent-failure-hunter test-writer
# or after npm publish:
npx claude-toolkit add code-reviewer silent-failure-hunter test-writer
```

### Keep up to date

```bash
# Pull latest toolkit, then update your project's subagents
cd ~/claude-toolkit && git pull
cd ~/my-project && node ~/claude-toolkit/bin/cli.mjs update

# Other commands
node ~/claude-toolkit/bin/cli.mjs diff     # check what's outdated or missing
node ~/claude-toolkit/bin/cli.mjs list     # see all available agents (✓ = installed)

# Skills are separate — update those with the vercel-labs skills CLI:
npx skills update
```

> **Do NOT add `.claude/` to `.gitignore`.** Subagents (and skills) must be committed for Claude Code Web sessions and CI to work.

### Shell alias (optional)

Add to your `~/.zshrc` to skip the full path:

```bash
alias ctk="node ~/claude-toolkit/bin/cli.mjs"
```

Then: `cd my-project && ctk init`

---

## Agents

Agents are sub-agents Claude Code spawns to handle tasks autonomously. Just ask in natural language — Claude picks the right agent.

| Agent | What it does |
|-------|-------------|
| **code-reviewer** | Reviews diffs for bugs, security, performance, conventions. Confidence-filtered (≥80 only). |
| **code-simplifier** | Simplifies recently modified code for clarity while preserving functionality. |
| **silent-failure-hunter** | Audits error handling for silent failures, empty catch blocks, hidden bugs. |
| **comment-analyzer** | Catches comment rot, misleading docstrings, stale TODOs. |
| **type-design-analyzer** | Evaluates TypeScript type definitions with 1–10 ratings on invariants and encapsulation. |
| **dependency-auditor** | Audits deps for vulnerabilities, outdated majors, unused packages, license conflicts. |
| **accessibility-auditor** | Audits TSX for a11y issues linters miss — focus, ARIA, keyboard nav, screen readers. |
| **migration-checker** | Reviews Supabase migration SQL for destructive changes, data loss, locking, RLS impact. |
| **rls-tester** | Tests Supabase RLS policies by simulating queries as anon, authenticated, service_role. |
| **test-writer** | Generates Vitest tests following existing project patterns. |
| **e2e-writer** | Generates Playwright E2E tests with stable selectors, waits, CI compat. |
| **test-plan-verifier** | Reads a PR's test plan, runs tests, updates PR checkboxes with pass/fail results. |
| **doc-generator** | Generates API docs, component docs, and architecture overviews from code. |
| **verifier** | Full verification pipeline: tsc, lint, vitest, build, playwright. Pass/fail report. |

### Examples

```
> Review the changes I just made           → @code-reviewer
> Check the error handling in my API routes → @silent-failure-hunter
> Audit the login form for accessibility    → @accessibility-auditor
> Check this migration before I run it      → @migration-checker
> Write tests for src/lib/auth.ts           → @test-writer
> Verify everything passes before I merge   → @verifier
```

## Skills

Skills are **not installed by this CLI** — they moved to the [`skills`](https://github.com/vercel-labs/skills) CLI (`npx skills`), which supports local, GitHub, and well-known sources and tracks them in a `skills-lock.json`. This repo's `skills/` directory is a **local source** those installs can point at.

```bash
# From your project root
npx skills add <owner/repo>                              # a GitHub-hosted skill
npx skills add /path/to/claude-toolkit/skills/<name>     # a skill from this repo
npx skills update                                        # refresh installed skills
npx skills list
```

This toolkit's own skills (e.g. `issue-to-pr`, `worktree-setup`, `issue-release-planner`) live under `skills/` and are consumed that way.

---

## Stack

This toolkit is built for:

- **Next.js** (App Router) — server components, server actions, API routes
- **Supabase** — PostgreSQL, Auth, RLS, Storage
- **TypeScript** — strict mode
- **Vitest** — unit and integration testing
- **Playwright** — end-to-end testing
- **Stripe** — payment processing (optional)

## Customization

### Override an agent

Agents installed via `npx claude-toolkit init` are regular files in `.claude/agents/`. Edit them directly to add project-specific rules:

```markdown
---
name: code-reviewer
description: Project-specific code reviewer
tools: [Glob, Grep, Read, Bash]
---

Follow the standard review process, with these additional project rules:

- All API routes must use the `withAuth` middleware
- Components in `components/ui/` must have Storybook stories
- Database queries must use the query builder, not raw SQL
```

Running `npx claude-toolkit update` will overwrite your changes. If you've customized an agent, back it up or skip the update for that file.

### Create new agents

Agents are `.md` files with YAML frontmatter in `.claude/agents/`:

```yaml
---
name: my-agent
description: What this agent does
tools: [Read, Grep, Glob, Bash]
---
```

### Create new skills

Add a `skills/<name>/SKILL.md` to this repo, then install it into a project with [`npx skills`](https://github.com/vercel-labs/skills) (this CLI no longer installs skills):

```yaml
---
name: my-skill
description: What this skill does
allowed-tools: [Bash, Read]   # note: allowed-tools, not tools
---
```

## CLAUDE.md Templates

Starter templates for your project's `CLAUDE.md`:

```bash
# App project (Next.js + Supabase):
cp node_modules/claude-toolkit/templates/CLAUDE.md ./CLAUDE.md

# Marketing / landing page project:
cp node_modules/claude-toolkit/templates/CLAUDE-marketing.md ./CLAUDE.md
```

## Project Conventions

These filenames are recognized automatically by toolkit agents:

- `docs/SCHEMA-SPEC.md` — Database schema spec. Agents like rls-tester and migration-checker read it for context.

## Repository Structure

```
agents/              14 subagent definitions (.md files) — installed by bin/cli.mjs
skills/              skill sources (subdirs with SKILL.md) — installed via `npx skills`
templates/           CLAUDE.md starter templates
bin/cli.mjs          npx CLI for subagents (zero dependencies)
package.json         npm package config
```

## Links

- [Claude Code Documentation](https://docs.anthropic.com/en/docs/claude-code)
- [Claude Code Agents](https://docs.anthropic.com/en/docs/claude-code/agents)
- [Claude Code GitHub](https://github.com/anthropics/claude-code)

## TODO

### Agents — New
- [ ] Pre-commit hook agent for automated review
- [ ] Bundle analyzer agent
- [x] Migration safety checker agent
- [x] Accessibility audit agent

### Agents — Enhancements
- [ ] code-reviewer: Project-specific lint rule checks
- [ ] code-reviewer: Supabase RLS pattern validation
- [ ] code-reviewer: Stripe webhook handler pattern checks
- [ ] e2e-writer: Supabase auth helper fixtures
- [ ] e2e-writer: Visual regression testing patterns
- [ ] e2e-writer: API mocking patterns with `page.route()`
- [ ] e2e-writer: Mobile viewport test templates
- [ ] rls-tester: Testing with Supabase local dev (`supabase start`)
- [ ] rls-tester: JWT generation helpers for test users
- [ ] rls-tester: Multi-tenant RLS pattern tests
- [ ] rls-tester: Policy performance checks (indexes on policy columns)
- [ ] test-writer: Stripe webhook handler test templates
- [ ] test-writer: Supabase RLS integration test patterns
- [ ] test-writer: React component testing patterns with Testing Library
- [ ] verifier: Bundle size check (compare against baseline)
- [ ] verifier: Lighthouse CI score check
- [ ] verifier: Database migration safety checks
- [ ] verifier: Environment variable validation
- [ ] doc-generator: OpenAPI/Swagger generation from API routes
- [ ] doc-generator: Storybook story generation for components
- [ ] doc-generator: Database ERD diagram generation
- [ ] doc-generator: Changelog generation from git history

### Infrastructure
- [x] Setup script for automated integration (`npx claude-toolkit init`)
- [ ] CI workflow templates (GitHub Actions, GitLab CI)
- [ ] Claude Code Plugin for marketplace distribution
