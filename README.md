# claude-toolkit

A personal Claude Code toolkit — reusable agents, skills, and templates for Next.js / Supabase / TypeScript projects.

## What's Inside

```
agents/                          # Claude Code sub-agents (.claude/agents/ format)
  accessibility-auditor.md       # Audits TSX components for a11y issues linters miss
  code-reviewer.md               # Reviews code for bugs, security, performance, conventions
  code-simplifier.md             # Simplifies recently modified code for clarity and consistency
  comment-analyzer.md            # Catches comment rot, misleading docs, stale TODOs
  dependency-auditor.md          # Audits deps for vulnerabilities, outdated, unused, licenses
  migration-checker.md           # Reviews Supabase migration SQL for safety and data loss risks
  silent-failure-hunter.md       # Audits error handling for silent failures and hidden bugs
  test-plan-verifier.md          # Verifies PR test plans, runs tests, updates PR checkboxes
  test-writer.md                 # Generates Vitest unit and integration tests
  type-design-analyzer.md        # Evaluates TypeScript type design quality and invariants
  rls-tester.md                  # Tests Supabase Row Level Security policies
  e2e-writer.md                  # Generates Playwright end-to-end tests
  doc-generator.md               # Generates project documentation from code
  verifier.md                    # Runs type check, lint, tests, and build verification

skills/                          # Skills that run in the main conversation context
  commit-push-pr/SKILL.md        # Commits, pushes, and creates a GitHub PR
  e2e/SKILL.md                   # Runs Playwright E2E tests with smart defaults

templates/                       # Project templates
  CLAUDE.md                      # Starter CLAUDE.md for app projects (Next.js + Supabase)
  CLAUDE-marketing.md            # Starter CLAUDE.md for marketing/landing page projects
```

## Agents

Agents are sub-agents that Claude Code can spawn to handle specific tasks autonomously. They run in isolation with their own tool permissions.

| Agent | Description | Invocation |
|-------|-------------|------------|
| **accessibility-auditor** | Audits TSX components for a11y issues linters miss — focus management, ARIA, keyboard nav, screen readers. | `@accessibility-auditor` or via Agent tool |
| **code-reviewer** | Reviews diffs for bugs, security issues, performance problems, and convention violations. Confidence-filtered output (≥80 only). | `@code-reviewer` or via Agent tool |
| **code-simplifier** | Simplifies recently modified code for clarity, consistency, and maintainability while preserving functionality. | `@code-simplifier` or via Agent tool |
| **comment-analyzer** | Catches comment rot, misleading docstrings, stale TODOs, and factually incorrect documentation. | `@comment-analyzer` or via Agent tool |
| **dependency-auditor** | Audits deps for vulnerabilities, outdated majors, unused packages, and license conflicts. | `@dependency-auditor` or via Agent tool |
| **migration-checker** | Reviews Supabase migration SQL for destructive changes, data loss risks, locking, and RLS impact. | `@migration-checker` or via Agent tool |
| **silent-failure-hunter** | Audits error handling for silent failures, empty catch blocks, hidden bugs, and missing error checks. | `@silent-failure-hunter` or via Agent tool |
| **test-plan-verifier** | Reads a PR's test plan checklist, runs the tests, and updates the PR with pass/fail results. | `@test-plan-verifier` or via Agent tool |
| **test-writer** | Generates Vitest tests following existing project patterns. Discovers conventions before writing. | `@test-writer` or via Agent tool |
| **type-design-analyzer** | Evaluates TypeScript type definitions for encapsulation, invariants, and design quality with 1–10 ratings. | `@type-design-analyzer` or via Agent tool |
| **rls-tester** | Tests Supabase RLS policies by simulating queries as different roles (anon, authenticated, service_role). | `@rls-tester` or via Agent tool |
| **e2e-writer** | Generates Playwright E2E tests with stable selectors, proper waits, and CI compatibility. | `@e2e-writer` or via Agent tool |
| **doc-generator** | Generates API docs, component docs, and architecture overviews from code analysis. | `@doc-generator` or via Agent tool |
| **verifier** | Runs a full verification pipeline: tsc, lint, vitest, build, playwright. Reports pass/fail. | `@verifier` or via Agent tool |

### Invocation Examples

```
# In Claude Code conversation:

> Review the changes I just made
  → Claude spawns @code-reviewer

> Audit the login form for accessibility
  → Claude spawns @accessibility-auditor

> Simplify the code I just wrote
  → Claude spawns @code-simplifier

> Check the comments I added are accurate
  → Claude spawns @comment-analyzer

> Audit our dependencies for vulnerabilities
  → Claude spawns @dependency-auditor

> Check this migration before I run it
  → Claude spawns @migration-checker

> Check the error handling in my API routes
  → Claude spawns @silent-failure-hunter

> Review the types I added in this PR
  → Claude spawns @type-design-analyzer

> Verify the test plan on PR #42
  → Claude spawns @test-plan-verifier

> Write tests for src/lib/auth.ts
  → Claude spawns @test-writer

> Check the RLS policies on the profiles table
  → Claude spawns @rls-tester

> Write E2E tests for the login flow
  → Claude spawns @e2e-writer

> Generate API docs for all routes
  → Claude spawns @doc-generator

> Verify everything passes before I merge
  → Claude spawns @verifier
```

## Skills

Skills run in the main conversation context (not as sub-agents) and have access to the full conversation history.

| Skill | Description | Invocation |
|-------|-------------|------------|
| **commit-push-pr** | Stages, commits, pushes, and creates a PR with structured description. | `/commit-push-pr` |
| **e2e** | Runs Playwright tests with smart defaults. | `/e2e`, `/e2e login.spec.ts`, `/e2e "checkout"` |

## Stack Assumptions

This toolkit is built for projects using:

- **Next.js** (App Router) — server components, server actions, API routes
- **Supabase** — PostgreSQL, Auth, RLS, Storage
- **TypeScript** — strict mode
- **Vitest** — unit and integration testing
- **Playwright** — end-to-end testing
- **Stripe** — payment processing (optional)

## Quick Start

### 1. Clone the toolkit

```bash
git clone <this-repo-url> ~/claude-toolkit
```

### 2. Copy agents and skills into your project

```bash
mkdir -p .claude/agents .claude/skills

# Copy agents (pick the ones you need)
cp ~/claude-toolkit/agents/*.md .claude/agents/

# Copy skills (each is a directory)
cp -r ~/claude-toolkit/skills/commit-push-pr .claude/skills/
cp -r ~/claude-toolkit/skills/e2e .claude/skills/
```

> **Important:** Do NOT add `.claude/` to `.gitignore`. Agents and skills must be committed to your repo — they are required for Claude Code web sessions and CI.

### 3. Set up CLAUDE.md

```bash
# For app projects (Next.js + Supabase):
cp ~/claude-toolkit/templates/CLAUDE.md ./CLAUDE.md

# For marketing / landing page projects:
cp ~/claude-toolkit/templates/CLAUDE-marketing.md ./CLAUDE.md

# Edit CLAUDE.md and fill in the TODO sections
```

## Customization

### Extending Agents

Copy an agent into your project and add project-specific rules:

```bash
cp ~/claude-toolkit/agents/code-reviewer.md .claude/agents/code-reviewer.md
# Edit to add your project's rules
```

### Creating New Agents

Agents are flat `.md` files in `.claude/agents/`:
- **Frontmatter:** `name`, `description`, `tools` (list of allowed tools)
- **Instructions:** Step-by-step behavior guide
- **Output format:** Expected output structure

### Creating New Skills

Skills live in subdirectories: `.claude/skills/<name>/SKILL.md`:
- **Frontmatter:** `name`, `description`, `allowed-tools` (note: `allowed-tools`, not `tools`)
- **Instructions:** Step-by-step behavior guide

### Project-Specific Overrides

Override a toolkit agent by creating your own with the same name:

```markdown
---
name: code-reviewer
description: Project-specific code reviewer
tools: [Glob, Grep, Read, Bash]
---

# Code Reviewer

Follow the standard review process, with these additional project rules:

- All API routes must use the `withAuth` middleware
- Components in `components/ui/` must have Storybook stories
- Database queries must use the query builder, not raw SQL
```

## CI / Headless Mode

Claude Code agents can run in CI pipelines for automated code review, test generation, and verification.

```yaml
# .github/workflows/claude-review.yml
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

> See the [official Claude Code documentation](https://docs.anthropic.com/en/docs/claude-code) for CLI installation and headless mode details.

## Project Conventions

These filenames are recognized automatically by toolkit agents:

- `docs/SCHEMA-SPEC.md` — Database schema specification. If present, agents like rls-tester will read it first for context. Recommended for any project with a non-trivial schema.

## Official Docs

- [Claude Code Documentation](https://docs.anthropic.com/en/docs/claude-code)
- [Claude Code Agents](https://docs.anthropic.com/en/docs/claude-code/agents)
- [Claude Code GitHub](https://github.com/anthropics/claude-code)

## TODO

### Agents — New
- [ ] Add pre-commit hook agent for automated review
- [x] Add migration safety checker agent
- [ ] Add bundle analyzer agent
- [x] Add accessibility audit agent

### Agents — Enhancements
- [ ] code-reviewer: Add project-specific lint rule checks
- [ ] code-reviewer: Add Supabase RLS pattern validation
- [ ] code-reviewer: Add Stripe webhook handler pattern checks
- [ ] e2e-writer: Add Supabase auth helper fixtures
- [ ] e2e-writer: Add visual regression testing patterns
- [ ] e2e-writer: Add API mocking patterns with `page.route()`
- [ ] e2e-writer: Add mobile viewport test templates
- [ ] rls-tester: Add support for testing RLS with Supabase local dev (`supabase start`)
- [ ] rls-tester: Add JWT generation helpers for test users
- [ ] rls-tester: Add multi-tenant RLS pattern tests
- [ ] rls-tester: Add policy performance checks (indexes on policy columns)
- [ ] test-writer: Add Stripe webhook handler test templates
- [ ] test-writer: Add Supabase RLS integration test patterns
- [ ] test-writer: Add React component testing patterns with Testing Library
- [ ] verifier: Add bundle size check (compare against baseline)
- [ ] verifier: Add Lighthouse CI score check
- [ ] verifier: Add database migration safety checks
- [ ] verifier: Add environment variable validation
- [ ] doc-generator: Add OpenAPI/Swagger generation from API routes
- [ ] doc-generator: Add Storybook story generation for components
- [ ] doc-generator: Add database ERD diagram generation
- [ ] doc-generator: Add changelog generation from git history

### Infrastructure
- [ ] Add setup script for automated integration
- [ ] Add CI workflow templates (GitHub Actions, GitLab CI)
