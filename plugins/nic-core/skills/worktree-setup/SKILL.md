---
name: worktree-setup
description: >-
  Start work on a scope or issue by creating a git worktree on a
  conventionally-named branch, forked from the latest origin default branch, in a
  sibling "reponame.worktrees" directory. Use this whenever the user wants to
  begin implementing something and needs an isolated checkout: "spin up a
  worktree", "start on this issue", "new branch for X", "set up a worktree for the
  next release-plan item", "branch off main for the webhook work", "let's start
  the coworking payments feature". Also trigger when the user points at a
  docs/release-plan-*.md and says to start / pick up / work on an item from it,
  or when they describe a task and clearly intend to open a fresh branch for it,
  even if they don't say the word "worktree". This is the downstream companion to
  issue-release-planner: that skill writes the plan, this one spins up the branch
  to execute an item from it.
---

# Worktree Setup

Turn "I want to start on X" into a ready-to-code isolated worktree: resolve the
scope, name the branch by convention, fork it from the freshest origin state, and
hand back a path the user can `cd` into. The worktree lives in a sibling
`../<repo-name>.worktrees/<branch>` directory so the main checkout stays
untouched and multiple branches can be worked in parallel.

The value is in the setup around the `git worktree add`, not the command itself:
picking the right scope, deriving a defensible branch name, forking from latest
rather than stale local state, honouring repo conventions in `CLAUDE.md`, and
carrying over the gitignored `.env*` files that always break a fresh checkout.

## Prerequisites

- Run from **inside the target repo's working tree** (the script infers the repo
  and default branch from there; the repo name and worktree location are anchored
  on the main worktree, so running from inside another worktree is fine). If the
  user isn't in a repo, ask which one.
- `git` ≥ 2.5 (worktree support). A JS package manager is only needed if the user
  wants dependencies installed.

## Workflow

### 1. Resolve the scope

Figure out *what* is being worked on, in this priority order:

1. **The user named it** — a feature, a fix, an issue number, a description. Use
   that.
2. **A release plan exists** — if `docs/release-plan-*.md` is present (the output
   of `issue-release-planner`), read the newest one and propose the top item from
   its **Work order** section. Confirm before proceeding rather than assuming.
3. **Neither** — ask what they want to start on. One question, don't guess.

Keep this light. The goal is enough to name a branch, not a full spec.

### 2. Read repo conventions

Read `CLAUDE.md` (repo root) if present and honour anything it says about branch
naming, base branch, or worktree location — those overrides win over the defaults
below. If there's no `CLAUDE.md`, use the conventions in this skill and fork from
the latest origin default branch.

### 3. Derive and confirm the branch name

Compose `<type>/<slug>`:

- **type** — pick from the scope's nature: `feat` `fix` `chore` `docs` `test`
  `db` `refactor`. (`db` = schema / migration work; `refactor` = behaviour-
  preserving internal change.)
- **slug** — `<issue-number>-<summary>` when a GitHub issue number is known,
  otherwise just `<summary>`. The summary is short kebab-case: lowercase, words
  joined by hyphens, no punctuation, ~2-4 words.

**Embed the issue number whenever there is one.** If the scope came from a release
plan's Work order, from `gh issue view`, or the user simply said "#42", the number
leads the slug — it makes the branch traceable back to the issue in `git branch`,
PR titles, and the worktree path. Only omit it when no issue exists (ad-hoc chore,
spike, unfiled fix). Never invent a number to fill the slot; if the scope has no
issue, say so and use the bare summary.

**Always show the proposed branch name and get a yes before creating it.** A bad
branch name is cheap to prevent here and annoying to rename later.

**Examples**

Scope: "#31 — add Stripe webhook retry handling"
Branch: `feat/31-stripe-webhook-retries`

Scope: "issue #42 — booking emails send twice"
Branch: `fix/42-duplicate-booking-emails`

Scope: "#58 — add a loyalty_points column and backfill it" (Musa)
Branch: `db/58-musa-loyalty-points`

Scope: "quick cleanup of the eslint config" (no issue filed)
Branch: `chore/eslint-config-cleanup`

### 4. Create the worktree

Run the bundled script from inside the repo:

```bash
scripts/create_worktree.sh <branch-name> [--base <branch>] [--install] [--clone-deps] [--deps-from <path>] [--no-env-copy]
```

- No `--base` → forks from origin's default branch (resolved via
  `origin/HEAD`, falling back to `main`/`master`, then the current branch if there
  is no origin). The script runs `git fetch origin` first so the fork is current.
- Pass `--base <branch>` only if `CLAUDE.md` or the user specifies a non-default
  base (e.g. a long-lived `develop` or release branch).
- Env files: gitignored `.env*` files are copied from the source checkout by
  default — **anywhere in the repo, not just the root**. This matters in
  monorepos, where the real env lives at `apps/web/.env.local` rather than the top
  level; a root-only copy silently copies nothing and the worktree still breaks on
  first run. Discovery uses git itself (`git ls-files --others --ignored
  --exclude-standard --directory`), so it respects `.gitignore` and skips
  build/dependency dirs (`node_modules/`, `.next/`, `dist/`, `build/`, `.turbo/`,
  `coverage/`) rather than resurrecting stray env files from inside them. Relative
  paths are preserved. Pass `--no-env-copy` to skip.
- The summary reports `env copied: none found` when there was nothing to copy —
  if the repo clearly needs env vars and that line says `none found`, tell the
  user, because it means the env lives somewhere the scan didn't reach (e.g. a
  wholly-ignored config dir) and their first run will fail.
- Dependencies: pass `--install` to run the detected package manager
  (`pnpm`/`bun`/`yarn`/`npm`, chosen by lockfile) inside the new worktree. Default
  is off; the script reports the command it *would* run so the user can decide.
- Copy-on-write deps: on a disk-constrained machine, prefer `--clone-deps` over
  `--install`. It clones `node_modules` (the root plus every workspace tree) from
  an existing checkout using APFS clonefile / reflink — near-zero extra disk and
  near-instant, versus ~1 GB+ and a full resolve per worktree. It clones from the
  main worktree by default; use `--deps-from <path>` to point at a specific
  checkout (whose lockfile should match — which holds when both forked from the
  same fresh base). `--clone-deps` supersedes `--install` if both are passed, and
  the summary reports a `deps cloned:` line.
- Placement: the worktree always lands in `<repo>.worktrees/` next to the **main**
  checkout, even when you run the script from inside another worktree — the repo
  name is taken from the main worktree, not the current directory.

The script reuses an existing local or remote branch of the same name instead of
failing, and refuses to clobber an existing worktree path.

### 4a. Never start work on a stale branch

A fresh branch forked from a just-fetched base is fresh by construction. A
**reused** branch is where staleness hides, and building on old code is exactly
the failure this skill exists to prevent. The script reports a `freshness:` line
on every run and handles the cases like this:

- **Behind its upstream, no local commits** → fast-forwarded automatically. This
  is a pure fast-forward: nothing is rewritten, nothing can be lost, so it's safe
  to do without asking.
- **Diverged** (local commits *and* behind upstream) → left completely untouched
  and reported. Never auto-rebase or auto-merge here; the user's local commits are
  theirs to reconcile.
- **Behind the base branch** (e.g. branch cut last week, `main` has moved) →
  reported as `STALE — N commit(s) behind <base>`, with the rebase/merge commands
  printed. Pass `--rebase` to have the script rebase it onto the base, but only
  when the branch isn't shared with anyone, since that rewrites history.
- **Fetch failed** (offline) → freshness is `UNKNOWN`, not silently assumed fine.

If the summary reports `STALE` or `UNKNOWN`, **say so plainly in your reply and
tell the user how to sync** before they start coding. Don't bury it. A worktree
that quietly sits two commits behind `main` produces merge conflicts and
"works-on-my-branch" bugs that cost far more than the ten seconds it takes to
mention it here.

Decide whether to make the worktree runnable based on the user's intent: if they
said "and get it running" or the repo needs deps to do anything useful, pass
`--clone-deps` (copy-on-write clone from the main checkout — cheap enough to be the
default when deps are needed) or `--install` for a clean resolve; if they just want
the branch, skip both and surface the install command in your reply. On a near-full
disk, avoid `--install` — a full `node_modules` per worktree can exhaust it — and
use `--clone-deps`.

### 5. Report

Keep the chat reply short. Give them:
- the branch name and what it forked from,
- the `cd` path to the worktree,
- anything copied (env) or installed, or the install command they still need to run.

Don't recap the whole workflow. They asked for a worktree, hand them the worktree.

## Notes on judgment

- **Fork from latest, always.** The whole point of fetching first is to avoid
  branching off a week-old local `main`. Staleness is silent by nature — git will
  happily let someone spend a day on a branch cut from stale code and only
  surface the cost at merge time. That's why the script measures it on every run
  and why the `freshness:` line gets repeated to the user rather than skipped.
- **Auto-sync only when it cannot lose work.** Fast-forwarding a branch with no
  local commits is safe and should just happen. Rebasing or merging a branch that
  has local commits is a judgment call with a blast radius, so it stays opt-in
  (`--rebase`) and gets reported instead of performed.
- **One worktree = one branch = one folder.** Because the path mirrors the branch
  name (`.worktrees/feat/foo`), `feat/` and `fix/` group naturally on disk and the
  folder maps 1:1 to the branch. Don't reuse a worktree for a second branch.
- **`db/` branches deserve extra care.** Schema and migration work is where blast
  radius bites (Nic's stack is Supabase / SQLite). If the scope is a migration,
  say so in the confirmation and make sure the branch name signals it.
- **Don't invent scope.** If the release plan or user request is ambiguous about
  what to start, ask one question rather than picking an item and running. Spinning
  up a branch for the wrong thing wastes a checkout and a name.
- **Cleanup is out of scope but worth a pointer.** When the user is done, the
  worktree is removed with `git worktree remove <path>` and the branch merged/
  deleted as usual — mention this only if they ask.
