# Classification, grouping, and sequencing

The decision framework behind the plan. Read this during steps 4 and 5 of the workflow.

## Contents
1. Semver classification
2. App vs library (what "breaking" means)
3. Pre-1.0 relaxation
4. Effort and risk scoring
5. Grouping heuristics
6. Sequencing heuristics

---

## 1. Semver classification

Classify by the effect on whatever consumes the released thing (an API client, an importer of the package, a deployed environment), not by how the change feels to write.

**PATCH** (vX.Y.Z+1) — backwards compatible, nothing a consumer must change:
- Bug fix that restores intended behavior
- Security fix that doesn't alter a public contract
- Internal refactor with identical external behavior
- Docs, tests, tooling, non-breaking dependency bumps
- Performance improvement with unchanged inputs/outputs

**MINOR** (vX.Y+1.0) — backwards compatible additions:
- New feature, endpoint, component, CLI flag, or config option with a safe default
- New optional parameter (existing calls still work)
- Additive schema change: new table, new nullable column, new index
- Deprecating something (warning only, still works)

**MAJOR** (vX+1.0.0) — breaks an existing consumer contract:
- Removing or renaming a public API, route, export, config key, or env var
- Changing a function signature or a required parameter
- Changing default behavior so existing usage produces different results
- Destructive or non-reversible DB migration (drop/rename column, incompatible type change, backfill that requires downtime)
- Dropping support (Node version, runtime, browser, integration)
- Changing auth, session, or permission semantics that existing clients rely on

**NONE** — doesn't move the version on its own:
- Spikes and investigations (produce a decision, not a shippable change)
- Meta-issues ("audit the codebase for X") that should spawn concrete tickets rather than be worked directly
- Pure CI/ops fixes (pipeline config, cron cleanup) with no user-facing or contract effect
- Verification chores ("confirm feature Y on staging")
- Decision records ("decide product policy for Z")

These still get analyzed and sequenced (a CI fix that's masking real failures can be high priority), and they can ride along inside a release, but they don't drive the bump. Route them to the plan's "Not release-scheduled" bucket, or note them as non-version-affecting within the release they accompany.

**The classic mistake:** a "small" change that alters output or removes a field feels like a patch but breaks a consumer. When output shape or a contract changes, it is major regardless of diff size. If unsure, classify as major and name the specific contract at risk in the notes column.

---

## 2. App vs library

The semver bar depends on who consumes the artifact.

**Library / package / public API** — strict semver. Any change to the public surface others import or call is governed by the rules above. The "consumer" is external code.

**Application (e.g., a Next.js app, an internal service)** — no one imports it, so "breaking" shifts to *external* contracts and user-visible guarantees. Treat as major only when a change:
- Breaks an API, webhook payload, or public URL that another service or the mobile client consumes
- Changes auth/session behavior in a way that logs users out or invalidates existing tokens
- Reinterprets or discards existing user data in a way users would notice (not an internal-only representation change)

For apps, a purely internal feature that ships cleanly is minor; a bug fix is patch.

**Deploy complexity is not the same as a breaking change.** This is the most common app-side misclassification, so be deliberate about it. A destructive database migration, a required env var, a data backfill, or an ordered deploy makes the *deploy* complex, but the app's external contract can be entirely intact through all of it. The internal schema is not a public contract when nothing external reads it. So a destructive migration with a same-window coordinated deploy is minor (pre-1.0: patch or minor per the relaxation), not major. Capture the operational need as a **Deploy note** on the release, separately from the version bump. Reserve major for actual external-contract or user-visible breakage.

**The repo's own convention wins.** Before applying the rules above, look at how the repo has actually versioned comparable changes (its tags, CHANGELOG, and prior release plans). If past destructive migrations or schema reworks shipped as minor releases with a migration note, that is the established house rule, and it is more authoritative than this default. Follow it and cite the precedent in the plan (for example: "v0.24.0 shipped the members/memberships split, a destructive migration, as a minor; this plan follows that precedent"). Only depart from a demonstrated convention if the user asks you to, and say so explicitly when you do.

---

## 3. Pre-1.0 relaxation

Below 1.0.0, the public contract is explicitly unstable, so the convention shifts down one level:
- Breaking changes → **minor** bump (0.Y+1.0)
- Features and fixes → **patch** bump (0.Y.Z+1)

State in the plan that the project is pre-1.0 and that bumps follow this relaxed convention. If the user wants to treat 0.x strictly (breaking = 0.Y+1.0, feature = separate), that's a valid house rule; ask if it matters to them.

---

## 4. Effort and risk scoring

**Effort (XS / S / M / L / XL)** — from what the code actually looks like, not the issue's framing. Use a range (e.g. S–M) when the code genuinely spans two sizes or hinges on an open scoping question; a forced single letter would be false precision.
- XS: a line or two, copy change, single obvious edit.
- S: localized change, one file or one function, obvious fix.
- M: touches a few files or needs a new small module; some test updates.
- L: crosses module boundaries, needs design decisions, migration, or broad test changes.
- XL: large multi-module rework, new subsystem, or wide blast radius (many files, new schema plus RPC plus UI). Flag XL items as candidates to split into smaller shippable pieces.

**Risk (low / med / high)** — likelihood of regressing something:
- low: isolated, well-tested code, easy to verify.
- med: central code path, partial test coverage, or touches shared state.
- high: touches auth, payments, data integrity, migrations, or code with no tests.

Risk drives sequencing and review scope more than effort does. A small-effort, high-risk change (one-line auth tweak) still deserves isolation and careful review.

---

## 5. Grouping heuristics

Decide, per issue, whether it batches with others or stands alone.

**Group together when:**
- They touch the same files or module. Doing them in one PR shares context and avoids the two-PRs-one-file merge conflict.
- They share a root cause. Fix the cause once; the issues close together.
- They're the same low-risk semver tier and naturally form one reviewable unit.

**Keep separate when:**
- They're unrelated features large enough that a reviewer can't hold both in their head. Separate PRs mean cleaner review and independent rollback.
- One is high-risk. Isolate it so a revert doesn't drag unrelated work with it.

**Always isolate breaking changes.** Each breaking change should be its own PR and land only in a major release. The reason is release integrity: if a breaking change shares a branch with patches, you can't ship the patches without the break, which defeats the point of a patch release. Batch multiple breaking changes into the *same major* deliberately if they're related, but never let one leak into a minor or patch.

---

## 6. Sequencing heuristics

"What to work on first" is severity and leverage, not smallness. Default order:

1. **Security, data-loss, and production-breaking bugs.** Ship as a patch ASAP, ahead of everything.
2. **Unblockers.** Issues that other issues depend on. Doing these first removes serial waiting.
3. **Quick-win patches.** Low effort, real user value, low risk. Batch into the next patch release.
4. **Features (minor).** Grouped by module per the grouping rules. Sequence by value and by shared code (do same-module features adjacently).
5. **Breaking changes (major).** Last, isolated, batched into the next major with migration notes. They're the most disruptive and benefit from being planned deliberately rather than reactively.

Within a tier, break ties by: dependency order first, then risk (get scary things in early with runway to fix regressions), then value, then effort.

Tie the sequence back to the release train: everything in tiers 1–3 usually maps to the next patch, tier 4 to the next minor, tier 5 to the next major, unless dependencies force a different grouping. State any such exception explicitly in the plan.
