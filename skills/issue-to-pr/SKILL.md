---
name: issue-to-pr
description: >-
  Take a GitHub issue all the way from "here's the issue" to a reviewed,
  updated pull request, autonomously: spin up a worktree, plan and implement the
  fix, open the PR, get a fresh independent agent to review the diff, act on the
  findings, work the PR's test plan locally or on staging while ticking off the
  checklist, and notify the user at the terminal when it needs them. Use this
  whenever the user points at a GitHub issue and wants it handled,
  fixed, implemented, or shipped: "take issue #42", "fix #17 and open a PR",
  "work through these issues", "implement the top item from the release plan",
  "handle this bug end to end", "close out #58". Also trigger when they hand over
  an issue URL with little or no instruction, or when they ask for a PR for work
  that has an issue behind it, even if they never say the words "worktree" or
  "review". This is the execution layer above worktree-setup (which only creates
  the branch) and downstream of issue-release-planner (which decides the order).
---

# Issue to PR

One issue in, one reviewed PR out. The agent runs the whole loop without asking
permission at each step: worktree, plan, implement, PR, independent review, fix,
test plan, notify.

Autonomy is the point, so the value lives in two places: doing the boring parts
correctly every time (conventional branch and commit names, `Closes #N`, green
checks and an honestly-ticked test plan before the user is pinged), and knowing
exactly when to stop and ring the bell instead of guessing. An agent that quietly
invents requirements costs more than one that pauses.

## Prerequisites

- `gh` authenticated (`gh auth status`) with push rights on the repo.
- Run from inside the target repo's working tree.
- The `worktree-setup` skill for stage 1. If it is unavailable, fall back to
  creating the worktree manually with the same branch conventions.
- A subagent / Task capability for stage 4. If there is none, see "No subagent
  available" under stage 4.

## Autonomy contract

Do without asking: create the worktree, plan, write code, run tests and lint,
commit, push, open the PR, request the review, apply review findings, push
follow-ups, run the PR's test plan locally or against staging, edit the PR
description to update the checklist, comment on the PR.

Never do without asking: merge the PR, close the issue by hand, force-push a
branch anyone else has touched, rewrite `dev`/`main`, delete branches or
worktrees, change CI config or repo settings, commit anything that looks like a
credential, or `gh pr merge --auto`.

Stop and notify (do not improvise) when:

- the issue is ambiguous enough that two reasonable implementations differ in
  observable behaviour,
- the fix demands a schema migration, a dependency upgrade, or an API contract
  change that the issue never mentioned,
- tests were already failing on the base branch before any edits,
- three attempts at a failing test or build have not produced green,
- the change would touch secrets, auth, billing, or anything with a blast radius
  beyond the issue's stated scope.

Stopping is a success state, not a failure. Ring the bell (stage 6), say what is
blocked and what the options are, and leave the branch in a clean, committed
state so the user can pick it up.

## Workflow

### 1. Resolve the issue and open a worktree

Pull the real issue, never work from the user's paraphrase alone:

```bash
gh issue view <number> --json number,title,body,labels,milestone,assignees,comments
```

Read the comments. Requirements drift into them constantly, and the last comment
frequently contradicts the original body. If the user named a release plan item
instead of a number, resolve it to an issue first.

Then hand off to `worktree-setup` with that scope. It derives `<type>/<issue>-<slug>`,
forks from the freshest origin base, and copies `.env*` files across. Honour what
it reports back: if the freshness line says `STALE` or `UNKNOWN`, sync before
writing code rather than building on old state. Everything after this point
happens inside the worktree path, not the original checkout.

Read the repo's `CLAUDE.md` now if there is one. Its conventions outrank
everything in this skill.

### 2. Plan, then implement

Write a short plan before touching code: the acceptance criteria restated in your
own words, the files you expect to change, and how the change will be verified.
Keep it in the reply, not in a file the PR would carry.

Check the plan against the "stop and notify" list above. This is the cheapest
moment to discover the issue is underspecified, and by far the most expensive one
to skip.

Then implement:

- Smallest change that satisfies the acceptance criteria. Resist adjacent
  cleanups; they make the review harder and dilute the PR's story. Note them for
  a follow-up issue instead.
- Add or update tests where the repo has a test suite. A bug fix without a
  regression test invites the bug back.
- Run the repo's own gates before committing, discovered from `package.json`
  scripts or the equivalent: typecheck, lint, test, build. Green locally is the
  price of admission for stage 3.

### 3. Commit, push, open the PR

Conventional commits, scoped, with the issue number in the body rather than the
subject:

```
fix(booking): stop duplicate confirmation emails on retry

Refs #42
```

Push and open the PR against the repo's base branch (`dev` on cowork-platform,
not `main`, unless `CLAUDE.md` says otherwise):

```bash
gh pr create --base <base> --title "<type>(<scope>): <summary>" --body-file <path>
```

PR body template:

```markdown
Closes #<issue>

## What
One paragraph on the change, in behaviour terms.

## Why
The problem from the issue, restated.

## How
Notable implementation decisions, and anything a reviewer would otherwise have
to reverse-engineer from the diff.

## Test plan
- [ ] Step a reviewer (or you, at stage 6) can execute verbatim, with the
      expected result stated.
- [ ] One box per criterion in the issue, plus regression checks.
- [ ] Note against any box that can only be run on staging.

## Out of scope
Adjacent problems noticed and deliberately left alone.
```

Write the test plan as executable instructions, not as a summary of what you
already ran. It is the artifact stage 6 works through and the thing a human uses
to re-verify after merge, so "ran the tests" is useless and "POST /bookings twice
with the same idempotency key, expect one confirmation email" is not.

`Closes #<issue>` matters: it is what links the PR to the issue and closes it on
merge. Use `Refs #<issue>` instead when the PR is only part of the fix.

### 4. Independent review by a fresh agent

Spawn a subagent that has not seen the implementation reasoning. Its
independence is the entire value here: an agent that watched the code being
written will rationalise the same blind spots. Give it the issue, the diff, and
the repo conventions, and nothing about why the choices were made.

```bash
git diff <base>...HEAD
```

Pass the reviewer the brief in `references/reviewer-brief.md`, along with the
issue body, the full diff, and `CLAUDE.md` if present. It returns findings
graded `blocker`, `should-fix`, or `nit`.

**No subagent available:** review the diff yourself in a deliberately separate
pass. Re-read the diff cold against the issue's acceptance criteria and the
reviewer brief, and treat your own implementation intent as inadmissible: if the
code only makes sense given knowledge you have and the diff does not carry, that
is a finding. Say in the reply that the review was self-run, since it is weaker
evidence.

### 5. Act on the findings and update the PR

- **blocker**: fix it. Non-negotiable.
- **should-fix**: fix it, unless it expands scope past the issue, in which case
  file a follow-up issue and link it.
- **nit**: apply if it is a one-liner, otherwise skip.

Push follow-up commits (never amend and force-push a PR that is already under
human review), then post one comment on the PR summarising the review round:
what was raised, what was fixed and in which commit, what was consciously not
fixed and why. Reviewers trust a PR that says what it declined to do.

If a fix invalidates part of the PR description, update the description too. A
stale PR body is a bug in the PR.

Re-run the repo's gates after the follow-up commits. Review fixes break builds
more often than original implementations do, because they arrive with less
testing attention.

### 6. Work the test plan and tick the boxes

Execute the Test plan from the PR description for real, top to bottom, and update
the checklist in the PR description as you go:

```bash
gh pr view <n> --json body -q .body > /tmp/pr-body.md
# edit the checklist, then:
gh pr edit <n> --body-file /tmp/pr-body.md
```

Where to run each step:

- **Locally** by default: unit and integration tests, lint, typecheck, build, and
  anything that only needs the dev server plus a local or branch database.
- **On staging** when the step depends on infrastructure the local environment
  fakes or lacks: webhooks from a real provider, scheduled jobs, email delivery,
  auth flows against the real identity provider, anything Vercel-preview or
  Hetzner-specific. Use the PR's deploy preview when the repo produces one.

Marking boxes honestly is the whole point of this stage. Use:

- `- [x]` passed, with the observed result appended if it is not obvious.
- `- [ ]` still unrun, with `(not run: <reason>)` appended. Never tick a box you
  did not execute, and never quietly delete one you could not.
- `- [x] ~~step~~` only when the step turned out not to apply, with the reason.

A failure here is a real finding, not a retry prompt: fix it, push, and re-run
the affected steps. If the failure needs a decision or cannot be reproduced in
three attempts, stop and notify per the autonomy contract, leaving the checklist
showing exactly how far it got.

If checks are still running on CI, say so rather than implying they passed
(`gh pr checks <n>`).

### 7. Notify

Ring the terminal bell and print the summary:

```bash
scripts/notify.sh "PR #<n> ready" "<repo>#<issue>: <title>"
```

Then keep the chat reply short. The user wants the state of the world, not a
retelling of the workflow:

- PR URL and title
- what changed, in one or two lines
- review outcome (counts by severity, and what was left unfixed)
- test plan result: boxes ticked out of total, and any left unrun with the reason
- CI status, if checks have reported
- anything that needs them: a decision, a blocked step, a follow-up issue filed

When the run stopped early, the same bell fires and the summary leads with the
blocker and the options, not with what was completed.

## Multiple issues

If the user hands over several issues, run them one at a time, each in its own
worktree and PR. Do not batch unrelated fixes into a single branch: it makes
review harder, ties unrelated changes to one merge decision, and breaks the
`Closes #N` link for all but one issue. Related issues that genuinely share a
change set can share a PR, with a `Closes #N` line each.

## Notes on judgment

- **The issue is the spec, the comments are the amendments.** When body and
  comments disagree, the newest comment from the issue author wins, and say in
  the PR that you read it that way.
- **A green local build is not a green PR.** CI runs things the local machine
  does not. Check `gh pr checks` before declaring done, and if checks are still
  running, say so rather than implying success.
- **An unticked box is information, a falsely ticked one is damage.** The
  checklist is the only signal the reviewer has about what was actually
  exercised. `(not run: needs real Stripe webhook)` tells them where to look;
  a tick that was never earned sends them into a merge believing it was.
- **Scope creep is the failure mode of autonomous runs.** Every extra file in the
  diff costs reviewer trust. When tempted, file the follow-up issue instead: it is
  faster, and it survives the PR being rejected.
- **Never bury a stop.** A run that stops at stage 2 and says so clearly is worth
  more than one that guesses and produces a plausible-looking PR built on the
  wrong reading of the issue.
