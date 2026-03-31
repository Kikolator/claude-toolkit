# claude-toolkit

Reusable agents, skills, and templates for Claude Code — built for Next.js, Supabase, and TypeScript projects.

14 agents, 4 skills. Zero dependencies.

## Install

Run this in your project directory:

```bash
npx claude-toolkit init
```

That's it. This copies all agents and skills into `.claude/agents/` and `.claude/skills/`. Commit the `.claude/` directory to your repo — it's required for Claude Code Web and CI.

### Pick specific items

```bash
npx claude-toolkit add code-reviewer silent-failure-hunter scaffold
```

### Keep up to date

```bash
npx claude-toolkit update     # refresh all installed items
npx claude-toolkit diff        # check what's outdated or missing
npx claude-toolkit list        # see everything available (✓ = installed)
```

> **Do NOT add `.claude/` to `.gitignore`.** Agents and skills must be committed for Claude Code Web sessions and CI to work.

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

Skills run in the main conversation context with full conversation history.

| Skill | What it does | Invocation |
|-------|-------------|------------|
| **commit-push-pr** | Stages, commits, pushes, creates a PR with structured description. | `/commit-push-pr` |
| **e2e** | Runs Playwright tests with smart defaults. | `/e2e`, `/e2e login.spec.ts` |
| **scaffold** | Generates boilerplate from existing project conventions. | `/scaffold api-route users` |
| **wrap-up** | Saves session context as a handoff file for the next Claude session. | `/wrap-up` |

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

Skills are `SKILL.md` files in subdirectories under `.claude/skills/`:

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
agents/              14 agent definitions (.md files)
skills/              4 skill definitions (subdirs with SKILL.md)
templates/           CLAUDE.md starter templates
bin/cli.mjs          npx CLI (zero dependencies)
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
