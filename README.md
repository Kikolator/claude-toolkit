# claude-toolkit

A personal Claude Code toolkit — reusable agents, skills, and templates for Next.js / Supabase / TypeScript projects.

## What's Inside

```
agents/                          # Claude Code sub-agents (.claude/agents/ format)
  code-reviewer.md               # Reviews code for bugs, security, performance, conventions
  test-writer.md                 # Generates Vitest unit and integration tests
  rls-tester.md                  # Tests Supabase Row Level Security policies
  e2e-writer.md                  # Generates Playwright end-to-end tests
  doc-generator.md               # Generates project documentation from code
  verifier.md                    # Runs type check, lint, tests, and build verification

skills/                          # Skills that run in the main conversation context
  commit-push-pr/SKILL.md        # Commits, pushes, and creates a GitHub PR
  e2e/SKILL.md                   # Runs Playwright E2E tests with smart defaults

templates/                       # Project templates
  CLAUDE.md                      # Starter CLAUDE.md for new projects

docs/                            # Documentation
  integration.md                 # How to integrate the toolkit into your projects
```

## Agents

Agents are sub-agents that Claude Code can spawn to handle specific tasks autonomously. They run in isolation with their own tool permissions.

| Agent | Description | Invocation |
|-------|-------------|------------|
| **code-reviewer** | Reviews diffs for bugs, security issues, performance problems, and convention violations. Confidence-filtered output. | `@code-reviewer` or via Agent tool |
| **test-writer** | Generates Vitest tests following existing project patterns. Discovers conventions before writing. | `@test-writer` or via Agent tool |
| **rls-tester** | Tests Supabase RLS policies by simulating queries as different roles (anon, authenticated, service_role). | `@rls-tester` or via Agent tool |
| **e2e-writer** | Generates Playwright E2E tests with stable selectors, proper waits, and CI compatibility. | `@e2e-writer` or via Agent tool |
| **doc-generator** | Generates API docs, component docs, and architecture overviews from code analysis. | `@doc-generator` or via Agent tool |
| **verifier** | Runs a full verification pipeline: tsc, lint, vitest, build, playwright. Reports pass/fail. | `@verifier` or via Agent tool |

### Invocation Examples

```
# In Claude Code conversation:

> Review the changes I just made
  → Claude spawns @code-reviewer

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

### 2. Integrate into your project

**Copy what you need:**
```bash
mkdir -p .claude/agents .claude/skills
cp ~/claude-toolkit/agents/code-reviewer.md .claude/agents/
cp ~/claude-toolkit/agents/verifier.md .claude/agents/
cp -r ~/claude-toolkit/skills/commit-push-pr .claude/skills/
```

**Or symlink everything:**
```bash
mkdir -p .claude
ln -s ~/claude-toolkit/agents .claude/agents
ln -s ~/claude-toolkit/skills .claude/skills
```

### 3. Set up CLAUDE.md

```bash
cp ~/claude-toolkit/templates/CLAUDE.md ./CLAUDE.md
# Edit CLAUDE.md and fill in the TODO sections
```

See [docs/integration.md](docs/integration.md) for the full integration guide, including git submodule setup, CI configuration, and customization.

## CI / Headless Mode

Claude Code agents can run in CI pipelines (GitHub Actions, GitLab CI, etc.) for automated code review, test generation, and verification.

```yaml
# Example: Run verifier on every PR
# See docs/integration.md for full CI setup
- run: claude --agent verifier --headless
```

> See the [official Claude Code documentation](https://docs.anthropic.com/en/docs/claude-code) for CLI installation and headless mode details.

## Official Docs

- [Claude Code Documentation](https://docs.anthropic.com/en/docs/claude-code)
- [Claude Code Agents](https://docs.anthropic.com/en/docs/claude-code/agents)
- [Claude Code GitHub](https://github.com/anthropics/claude-code)

## Project Conventions

These filenames are recognized automatically by toolkit agents:

- `docs/SCHEMA-SPEC.md` — Database schema specification. If present, agents like rls-tester will read it first for context. Recommended for any project with a non-trivial schema.

## TODO

- [ ] Add pre-commit hook agent for automated review
- [ ] Add migration safety checker agent
- [ ] Add bundle analyzer agent
- [ ] Add accessibility audit agent
- [ ] Add setup script for automated integration
- [ ] Add CI workflow templates (GitHub Actions, GitLab CI)
