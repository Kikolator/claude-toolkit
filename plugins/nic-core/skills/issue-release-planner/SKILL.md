---
name: issue-release-planner
description: >-
  Turn a repository's open GitHub issues into a sequenced implementation and release plan, saved as a markdown file in docs/. Use this whenever the user wants to triage or prioritize GitHub issues, decide what to work on first, figure out which issues can be batched into the same PR or release versus kept separate, or classify fixes by semver impact (patch / minor / major version bump). Trigger on phrases like "plan my issues", "what should I work on first", "release plan", "group these issues", "which of these is a breaking change", "how should I version this", or any request that mixes GitHub issues with prioritization, batching, or versioning. Also trigger when the user points at a repo and asks for a roadmap, sprint plan, or release strategy derived from its issues, even if they don't say the word "skill".
---

# Issue Release Planner

Read a repo's open issues, cross-reference them against the actual code, then produce a single markdown plan in `docs/` that answers four questions the user cares about: what to work on first, what to batch together, what to keep separate, and what each change costs in semver terms (patch / minor / major). Optionally, mirror that plan into GitHub as milestones and labels, but only after explicit approval.

The value of this skill is judgment, not just listing issues. Anyone can run `gh issue list`. The point is to look at the code each issue touches, reason about blast radius and dependencies, and hand the user a plan they can execute in order without hitting avoidable merge conflicts or shipping a breaking change inside a patch release.

## Access model

Default to the **`gh` CLI against a local clone**. The user runs this from inside a checked-out repo, so:
- Issues come from `gh` (authed already, no token to manage).
- Code analysis reads the working tree directly.
- The output file lands in the repo's `docs/`.

If `gh` is missing or unauthenticated (`gh auth status` fails), fall back to `gh api` with a `GITHUB_TOKEN`, or ask the user how they'd like to authenticate. Don't invent a token.

Exact commands for every step live in `references/gh-cookbook.md`. Read it when fetching issues and again if the user approves GitHub writes.

## Workflow

### 1. Establish context

Before analyzing anything, pin down:
- **Repo**: infer from `git remote get-url origin`; if ambiguous or multiple remotes, ask.
- **Current version**: read `package.json` version, or the latest tag (`git tag --sort=-v:refname | head -1`), or `gh release list`. If there are no tags and no version field, treat the project as pre-1.0 and say so; semver rules relax below 1.0 (see classification reference).
- **App or library?** This changes what "breaking" means (see classification reference). A Next.js app that nobody imports has a different major-bump bar than a published package. If it's not obvious from the repo, ask once.
- **Branch strategy**: a quick look at branches tells you whether they're on trunk-based or release-branch flow. If unclear, assume trunk-based and note the assumption in the plan.
- **Existing plans and release convention**: scan `docs/` for prior release plans, roadmaps, or a `CHANGELOG.md`. If one exists, don't duplicate it: reconcile against it (note in one line what it already covers, and that this plan supersedes or extends it). More importantly, the repo's own history is the source of truth for its versioning convention. If past destructive migrations or schema changes shipped as minor (not major) releases with a migration note, that is the house rule; follow it and cite the precedent rather than imposing a stricter default. Also check `CHANGELOG.md`'s unreleased section, since work already merged but unshipped ships in the very next release regardless of the backlog.

### 2. Fetch issues

Pull open issues with their body, labels, assignees, and comment count (see cookbook for the exact `gh issue list --json` call). Skip pull requests. If there are more than ~40 open issues, tell the user and offer to filter by label, milestone, or a query before proceeding, so the plan stays actionable rather than exhaustive.

### 3. Analyze the code per issue

This is the core step and the reason the plan is worth more than a spreadsheet. For each issue, read enough of the codebase to answer:
- **Which files / modules does this touch?** Grep for the symbols, routes, components, or error strings named in the issue.
- **Blast radius**: is it isolated to one module, or does it cross boundaries (schema, shared util, public API, auth)?
- **Dependencies**: does fixing this require or unblock another issue? Does it sit on top of unmerged work?
- **Effort**: rough t-shirt size (S / M / L) based on what the code actually looks like, not the issue's optimism.
- **Risk**: how likely is this to regress something, based on how central and how well-tested the touched code is?

Don't run heavy static-analysis tooling by default. If the repo already has a linter, typechecker, or test suite and the user wants deeper signal, offer to run it, but reading the code is usually enough to sequence the work.

### 4. Classify each issue

Assign every issue a **semver impact** (major / minor / patch, or **none** for work that doesn't move the version), plus the effort and risk from step 3. The full decision rules, including the app-vs-library nuance and the pre-1.0 relaxation, are in `references/classification.md`. Read that file before classifying so the bumps are defensible. The one-line version:
- **patch**: backwards-compatible bug fix, security fix with no contract change, internal refactor, docs.
- **minor**: backwards-compatible new capability, additive schema change, deprecation-without-removal.
- **major**: breaks an existing *consumer* contract. For a library that's a removed/renamed export or signature change. For an app with no external importers, "consumer" means an external integration (public API, webhook payload, mobile client, auth/session behavior) or a user-visible guarantee, not the internal database. A destructive migration that requires a coordinated deploy is not by itself major; deploy complexity and contract breakage are different axes. Capture the migration/runbook need as a release note, and let the repo's demonstrated convention (step 1) decide the bump when it conflicts with this default.
- **none**: doesn't affect the released version on its own. Spikes/investigations, meta-issues, pure CI/ops fixes, verification chores, and decision records. These still get sequenced and can ride along in a release, but they don't drive the bump. Put them in the plan's "Not release-scheduled" bucket or note them as non-version-affecting.

### 5. Group and sequence

Apply the grouping and sequencing heuristics from `references/classification.md`. In short: group issues that share files or a root cause (fix once, one PR, fewer conflicts); isolate every breaking change so it can't accidentally ride a non-major release; then order the work as security/data-loss fixes → unblockers → quick-win patches → features → batched breaking changes.

### 6. Build the release train

Map the grouped, sequenced work onto concrete versions off the current one. Batch all the ready patches into one patch release, features into a minor, breaking changes into a major, always respecting dependency order. Each proposed version gets its issue list and a one-line rationale. Breaking versions get a migration note.

### 7. Write the plan to `docs/`

Save to `docs/release-plan-<YYYY-MM-DD>.md` (dated so it doesn't clobber history; let the user override the name). Use the template below exactly, because its predictability is what makes the file skimmable next week. Then tell the user the path and give a 3-line TL;DR in chat, no more, they can open the file for detail.

### 8. Offer GitHub sync (only with approval)

After the doc exists, offer to mirror it into GitHub: one milestone per proposed release, `semver:*` labels driven by each issue's own classification (see below), optional `group:<name>` labels, and issue assignments. Creating milestones and labels and editing issues are writes to their repo, so **show the exact commands and the full list of changes, then wait for an explicit yes before running anything**. Never run these as a side effect of generating the doc. If they decline, the doc alone is the deliverable. Commands are in the cookbook.

Label each issue by the Semver value in its own analysis row, not by the release it lands in. Releases hold a mix (a patch release carries `none`-classified CI fixes, chores, and investigations alongside the real patches), and blanket-labeling everything in a milestone with the release's bump mislabels that `none` work. Issues classified `none` get the milestone but no `semver:*` label. The cookbook shows how to batch by tier so this stays correct.

## Output template

Use this structure verbatim (fill the brackets, drop sections only if genuinely empty):

Keep everything above TL;DR to the single status line, so the TL;DR is the first block a reader hits. Reconciliation, pre-1.0 notes, and precedent go in the Context section below it, kept to a few lines each.

```markdown
# Release Plan — <repo> — <YYYY-MM-DD>

**Current version:** vX.Y.Z  |  **Type:** app / library  |  **Branch flow:** <trunk / release-branch>

## TL;DR
- **Start here:** <the 1-3 issues to do first, and why>
- **Release train:** vX.Y.(Z+1) patch → vX.(Y+1).0 minor → v(X+1).0.0 major
- **Watch out:** <the single biggest risk or dependency>

## Context
<Only if relevant, one line each: existing docs this supersedes; the repo's versioning convention and the precedent for it; work already merged-but-unreleased that ships next regardless. Omit entirely if none apply.>

## Issue analysis

| # | Title | Type | Semver | Effort | Risk | Module(s) | Depends on | Notes |
|---|-------|------|--------|--------|------|-----------|-----------|-------|
| 12 | ... | bug | patch | S | low | api/auth | — | ... |
| 30 | ... | spike | none | S | — | — | — | investigation, no bump |

## Work order

1. **#<n> — <title>** — <one line: why it's first>
2. ...

## Grouping

### Group A: <module or root cause> → single PR
- #<n>, #<n> — <why they belong together>

### Standalone
- #<n> — <why it stays separate>

### Isolated breaking changes
- #<n> — <must ship in its own major; why>

## Release strategy

### vX.Y.(Z+1) — Patch
- Issues: #<n>, #<n>
- Rationale: <backwards-compatible fixes, ship first>

### vX.(Y+1).0 — Minor
- Issues: #<n>
- Rationale: <additive features>

### v(X+1).0.0 — Major
- Issues: #<n>
- Rationale: <breaks an external contract or user-visible guarantee>
- **Migration:** <what consumers must do>

<Add a **Deploy note** line under any release, at any level, that needs a coordinated or ordered migration, a new env var, or a manual ops step, even when the bump is only minor or patch. The runbook need is real and worth flagging; it just isn't what decides the version.>

### Not release-scheduled
- #<n> — <spike / meta-issue / CI-only / verification chore / decision record; why it's here and what to do with it (close, spawn tickets, do opportunistically)>

## Open questions / risks
- <anything that blocks the plan or needs a human decision>
```

## Notes on judgment

- If two issues look independent but touch the same file, say so and group them; the merge-conflict cost is real and invisible in the issue tracker.
- A breaking change smuggled into a minor is the most common versioning mistake. When in doubt about whether something breaks a contract, flag it as major and explain the specific contract at risk rather than hand-waving.
- "Work on first" is not the same as "smallest". Lead with severity and unblocking value; a security fix or a dependency that three other issues sit on comes before a quick cosmetic win, even if the cosmetic one is faster.
- Keep the chat reply short. The doc is the artifact; the user asked for a file, not a lecture. A good closing reply is: the file path, a 3-line TL;DR, and the GitHub-sync offer, nothing more.
- Always end by offering the GitHub sync from step 8. It's easy to write the doc and stop, but the sync is where the plan becomes actionable in their tracker. Offer it in one line ("Want me to mirror this into milestones and `semver:*` labels? I'll show the exact commands first"), and only proceed on an explicit yes. If they decline, the doc stands on its own.
