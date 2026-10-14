# claude-toolkit

A Claude Code **plugin marketplace** — Nic Pijpers' reusable skills, subagents, and `CLAUDE.md` templates for Next.js / Supabase / TypeScript work.

Two plugins, 8 skills, 14 subagents, zero dependencies.

## Install

Add the marketplace once per machine, then install what you need:

```bash
claude plugin marketplace add Kikolator/claude-toolkit
claude plugin install nic-core@claude-toolkit
claude plugin install nic-nextjs-supabase@claude-toolkit   # only on Next.js + Supabase projects
```

Installs are **user-scoped by default**, so every project on the machine picks them up — no per-repo setup, nothing to commit into `.claude/`. Pass `-s project` instead if you want a plugin pinned to one repo and shared with collaborators.

### Keep up to date

```bash
claude plugin marketplace update claude-toolkit
claude plugin update nic-core
```

A restart applies the update. Pushing to this repo's `main` is the release.

### Other commands

```bash
claude plugin list                  # what's installed
claude plugin details nic-core      # component inventory + projected token cost
claude plugin disable nic-core      # turn off without uninstalling
claude plugin uninstall nic-core
```

### Try before installing

Load a plugin for one session straight from a clone, without touching any config:

```bash
claude --plugin-dir /path/to/claude-toolkit/plugins
```

A directory named `plugins` loads every child, so that picks up both.

---

## Plugins

### `nic-core` — stack-agnostic

Workflow and review tooling that applies to any repo. ~1.6k always-on tokens.

**Skills**

| Skill | What it does |
|-------|-------------|
| **worktree-setup** | Creates a git worktree on a conventionally-named branch off the latest origin default branch, in a sibling `reponame.worktrees/` dir. |
| **issue-to-pr** | Takes a GitHub issue end to end: worktree, implement, open PR, independent review, act on findings, work the test plan, notify you when it needs you. |
| **issue-release-planner** | Turns open GitHub issues into a sequenced implementation and release plan, batched by PR and classified by semver impact. |
| **commit-push-pr** | Commits staged changes, pushes, and opens a PR with a structured description. |
| **wrap-up** | Saves session context to a `WRAP_UP.md` handoff for the next session. |

**Agents**

| Agent | What it does |
|-------|-------------|
| **code-simplifier** | Simplifies recently modified code for clarity while preserving functionality. |
| **comment-analyzer** | Catches comment rot, misleading docstrings, stale TODOs. |
| **type-design-analyzer** | Evaluates TypeScript type definitions with 1–10 ratings on invariants and encapsulation. |
| **dependency-auditor** | Audits deps for vulnerabilities, outdated majors, unused packages, license conflicts. |
| **doc-generator** | Generates API docs, component docs, and architecture overviews from code. |
| **verifier** | Full verification pipeline: tsc, lint, vitest, build, playwright. Pass/fail report. |

### `nic-nextjs-supabase` — stack-specific

Next.js, Supabase, Vitest, and Playwright specifics. ~1.1k always-on tokens.

**Skills**

| Skill | What it does |
|-------|-------------|
| **scaffold** | Generates boilerplate from existing project code as the template: api-route, server-action, component, page, supabase-table, webhook. |
| **e2e** | Runs Playwright E2E tests with smart defaults — all, one file, or a grep pattern. |
| **test-pr** | Verifies a PR's test plan end to end, ticks off passing items in the description, and posts a results comment. |

**Agents**

| Agent | What it does |
|-------|-------------|
| **code-reviewer** | Reviews diffs for bugs, security, performance, conventions. Confidence-filtered (≥80 only). |
| **silent-failure-hunter** | Audits error handling for silent failures, empty catch blocks, hidden bugs. |
| **accessibility-auditor** | Audits TSX for a11y issues linters miss — focus, ARIA, keyboard nav, screen readers. |
| **migration-checker** | Reviews Supabase migration SQL for destructive changes, data loss, locking, RLS impact. |
| **rls-tester** | Tests Supabase RLS policies by simulating queries as anon, authenticated, service_role. |
| **test-writer** | Generates Vitest tests following existing project patterns. |
| **e2e-writer** | Generates Playwright E2E tests with stable selectors, waits, CI compat. |
| **test-plan-verifier** | Reads a PR's test plan, runs tests, updates PR checkboxes with pass/fail results. |

### Examples

Just ask in natural language — Claude picks the right skill or agent.

```
> Spin up a worktree for the webhook work    → worktree-setup
> Take issue #42                             → issue-to-pr
> What should I work on first?               → issue-release-planner
> Review the changes I just made             → code-reviewer
> Check the error handling in my API routes  → silent-failure-hunter
> Check this migration before I run it       → migration-checker
> Write tests for src/lib/auth.ts            → test-writer
> Test PR 486                                → test-pr
> Verify everything passes before I merge    → verifier
```

---

## Stack

The `nic-nextjs-supabase` plugin assumes:

- **Next.js** (App Router) — server components, server actions, API routes
- **Supabase** — PostgreSQL, Auth, RLS, Storage
- **TypeScript** — strict mode
- **Vitest** — unit and integration testing
- **Playwright** — end-to-end testing
- **Stripe** — payment processing (optional)

`nic-core` assumes only git and `gh`.

## Customization

Plugin files are read-only in place — don't edit them under `~/.claude/plugins/`, an update will overwrite them. Two better options:

**Add project rules in `CLAUDE.md`.** A plugin agent still reads the project's `CLAUDE.md`, so repo-specific conventions belong there, not in a forked agent.

**Keep a project-local variant.** For a genuinely different version, put it in the project's own `.claude/skills/` or `.claude/agents/` under a *distinct name* — two components sharing a name is ambiguous, and the local one stops getting updates either way.

To change a component for every project, edit it here and push — that's what the marketplace is for.

### Adding a skill or agent

```
plugins/<plugin>/skills/<name>/SKILL.md     # allowed-tools:
plugins/<plugin>/agents/<name>.md           # tools:
```

Note the frontmatter fields differ — `allowed-tools:` for skills, `tools:` for agents. Then:

```bash
claude plugin validate plugins/<plugin>                 # manifest
claude plugin validate plugins/<plugin>/skills          # frontmatter
claude --plugin-dir plugins plugin details <plugin>     # confirm discovery + token cost
```

A plugin dir can also hold `commands/`, `hooks/`, and an `.mcp.json` if you need them later.

### Releasing

```bash
claude plugin tag plugins/<plugin>    # cuts <name>--v<version>, checks manifest/marketplace agree
```

## CLAUDE.md Templates

Not shipped by a plugin — copy them by hand from a clone:

```bash
cp templates/CLAUDE.md ./CLAUDE.md             # app project (Next.js + Supabase)
cp templates/CLAUDE-marketing.md ./CLAUDE.md   # marketing / landing page
```

## Project Conventions

These filenames are recognized automatically by toolkit agents:

- `docs/SCHEMA-SPEC.md` — database schema spec. `rls-tester` and `migration-checker` read it for context.

## Repository Structure

```
.claude-plugin/marketplace.json        marketplace manifest (lists the plugins)
plugins/<name>/.claude-plugin/plugin.json
plugins/<name>/skills/<skill>/SKILL.md
plugins/<name>/agents/<agent>.md
templates/                             CLAUDE.md starter templates
```

## Links

- [Claude Code Documentation](https://docs.anthropic.com/en/docs/claude-code)
- [Claude Code Plugins](https://docs.anthropic.com/en/docs/claude-code/plugins)
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
- [x] Setup script for automated integration (superseded by plugin install)
- [x] Claude Code Plugin for marketplace distribution
- [ ] CI workflow: validate manifests + components on PR
- [ ] Eval suites (`claude plugin eval`) beyond `test-pr`
