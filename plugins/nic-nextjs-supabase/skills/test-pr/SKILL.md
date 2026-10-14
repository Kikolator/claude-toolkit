---
name: test-pr
description: >
  Verifies a PR's test plan end-to-end: extracts the checklist, decides how
  much effort each item needs, runs the verification (from code inspection up
  to a live local-dev browser session), checks off passing items in the PR
  description, and posts or updates a results comment on the PR. On failures
  it flags them on the PR and notifies the user. Use whenever the user wants
  to test, verify, validate, or "run the test plan" of a PR — e.g. "test PR
  486", "verify the test plan", "is this PR ready to merge?", "check off the
  test plan items", or right after a PR was created and its checklist is
  still unchecked.
argument-hint: "[PR number] [low|medium|high] [--dry-run]"
---

# Verify a PR's Test Plan

Take a PR's `## Test plan` checklist, verify each item at the cheapest effort
tier that genuinely proves it, then record the results on the PR. The core
principle: **a checked box is a promise.** Never check an item you didn't
actually verify, and never let a failing item stay quiet — failures go in a PR
comment and a notification so they can't be missed.

Arguments: `$ARGUMENTS` — optional PR number (defaults to the current branch's
PR), optional effort ceiling (`low` / `medium` / `high`), optional `--dry-run`.
**Dry-run applies to every GitHub write in every step** — no description
edits, no comments; print what would have been written to the conversation
instead.

## Step 1: Resolve the PR

```bash
gh pr view --json number,title,body,state,headRefName,headRefOid,url   # current branch's PR
gh pr view <number> --json number,title,body,state,headRefName,headRefOid,url
```

- If no number was given and the current branch has no PR, ask the user for
  the number rather than guessing.
- **The PR must be OPEN.** If it's merged or closed, report that and stop —
  never edit a merged PR's description.
- If the body has no `## Test plan` / `## Test Plan` section: draft one from
  the PR diff (`gh pr diff <n>`), post it as a PR comment suggesting the
  author adopt it, notify the user, and stop there. Don't invent a checklist
  and immediately verify it yourself — the author should confirm it reflects
  what matters first.

## Step 2: Classify each item by effort tier

Read every checklist item and decide what it takes to *prove* it:

| Tier | What it covers | How to verify |
|------|----------------|---------------|
| **static** | "type X removed", "no remaining callers", refactor claims, docs | Read the diff / grep the codebase |
| **automated** | `tsc --noEmit`, `turbo lint`, `vitest`, build | Run the named command |
| **runtime** | UI flows, visual and dark-mode checks, a11y announcements, and anything the plan words as "Staging: …" — webhook fulfilment, checkout, Stripe-driven flows | Local dev server on the PR branch (Step 4) |
| **deferred** | CI-only suites (RLS/RPC and Playwright E2E — no local Docker, per CLAUDE.md), real-device checks, and items needing a fixture that cannot be made in-product | Report CI status from `gh pr checks <n>` |

**"Staging" names the data, not the deployment.** An item written "Staging:
complete a referred checkout …" is a **runtime** item: the local dev server
already runs against the cloud DEV (staging) database, and `stripe listen`
puts the real Stripe test events through the PR's own webhook handlers. Do
not file such items as deferred, and do not ask for `dev.rogueops.app` to be
repointed to the branch — that was a wrong conclusion reached twice before
this was written. Only classify one as deferred once you have actually tried
the Step 4 recipe and hit something it can't reach.

Items **already checked** by the author: trust them, but spot-check cheaply —
re-run automated commands if you're setting up the branch anyway; never boot a
dev server just to re-prove a checked box. If a spot-check *contradicts* an
already-checked item, do not silently uncheck the author's box — flag it
prominently in the Failures section and notify the user.

While classifying, also note **coverage gaps**: behavioral items with no
automated test behind them (search `*.test.ts(x)`, `*.spec.ts(x)`) — error
paths, validation rejections, and business-logic branches especially. These
go in the final report as recommendations (worst first), not as blockers.

### Choosing the effort ceiling

If the user passed `low`/`medium`/`high`, that's the ceiling:

- `low` → static only
- `medium` → static + automated
- `high` → everything including runtime

If no ceiling was given, infer it from the PR: docs/types/pure-refactor PRs
with no behavior change earn `medium`; anything touching UI components, server
actions, migrations, or auth/payment flows earns `high` — those are exactly
the changes a code-read can't prove. When the ceiling excludes items that
would need runtime verification, say so explicitly in the report rather than
silently skipping them.

## Step 3: Get the PR's code (without disturbing the working tree)

If the current branch *is* the PR branch, verify the working tree is clean
and `HEAD` matches the PR's `headRefOid` before verifying in place — evidence
collected against a dirty or stale tree proves nothing. In every other case
(including dirty/stale), **use a worktree — never switch the user's branch:**

```bash
git -C /Users/nicpijpers/Dev/cowork-platform fetch origin "pull/<n>/head:refs/heads/test-pr/<n>"
git -C /Users/nicpijpers/Dev/cowork-platform worktree add \
  /Users/nicpijpers/Dev/cowork-platform.worktrees/test-pr-<n> "test-pr/<n>"
```

(`pull/<n>/head` also works for fork PRs, where the branch doesn't exist on
`origin`; fetching into a named local ref instead of relying on `FETCH_HEAD`
keeps parallel sessions from clobbering each other. If the worktree path
already exists from a prior run, `git worktree remove --force` it first.)

For the automated/runtime tiers the worktree needs dependencies. **Do not run
a fresh `npm install`** (disk pressure) — APFS-clone from the main checkout:

```bash
cp -c -R <main-checkout>/node_modules <worktree>/node_modules
# repeat for nested ones that exist: apps/web/node_modules, packages/*/node_modules …
```

Copy `apps/web/.env.local` across too (the runtime tier needs the cloud DEV
Supabase credentials). Remove the worktree when done.

## Step 4: Verify, tier by tier

Work through unchecked items cheapest-first, recording **evidence** for each:
a command plus its exit status, a file:line, or what you observed in the
browser. An item without evidence stays unchecked.

- **static** — read the diff and the relevant code; note what you inspected.
- **automated** — run the exact command the item names, from the worktree.
  Prefer scoped runs (`--filter=web`, specific test files) over full suites.
- **deferred** — `gh pr checks <n>`; a **passing** required CI check is valid
  evidence (cite the run URL); pending or failing CI stays unchecked.
- **runtime** — the default posture is **run the app locally on the PR
  branch, against whatever Supabase `apps/web/.env.local` points at (normally
  cloud DEV / staging), with the Stripe CLI in front of the webhook route.**
  Only depart from that if the item explicitly says otherwise. No Docker is
  involved; Docker is only for the CI-only suites.
  - If something is already listening on the app's port, it's likely the
    user's own dev session — ask before doing anything runtime; don't start a
    competing server or assume theirs serves the PR branch.
  - Start the app from the worktree (`npm run dev` in `apps/web`, or `turbo
    dev`), using the copied `.env.local`.
  - Drive the flows with the **Playwright MCP**, not the Chrome extension:
    the extension has no site permission for `*.vercel.app` previews,
    `*.dev.rogueops.app`, or `checkout.stripe.com`, and silently reverts the
    navigation instead of erroring.
  - Log in with an existing seeded dev account. Password login works locally
    with `NEXT_PUBLIC_APP_ENV=development`; otherwise mint a magic link with
    the GoTrue admin API (`POST $NEXT_PUBLIC_SUPABASE_URL/auth/v1/admin/generate_link`,
    `{"type":"magiclink","email":…}`) and open
    `/auth/callback?token_hash=<hashed_token>&type=magiclink&space=<slug>`.
    To switch users, clear cookies with Playwright's
    `context.clearCookies()` first — Supabase auth cookies are httpOnly, so
    `document.cookie` cannot remove them and the old session survives.
  - Tenant resolution is subdomain-based (per CLAUDE.md); on hosts without a
    tenant subdomain append `?space=<slug>` and re-append it after redirects
    that drop it.
  - Watch the browser console for errors while you click through.
  - Kill any dev server and `stripe listen` you started when finished.

### Stripe-dependent runtime items

Anything that only happens when a Stripe webhook fires — fulfilment, a grant,
a subscription, a referral completing — is verified by putting the CLI in
front of the local route:

```bash
cd apps/web && set -a && source .env.local && set +a
stripe listen --api-key "$STRIPE_SECRET_KEY" \
  --forward-to         localhost:3000/api/webhooks/stripe \
  --forward-connect-to localhost:3000/api/webhooks/stripe
```

Then put the printed `whsec_…` into **both** `STRIPE_WEBHOOK_SECRET` and
`STRIPE_CONNECT_WEBHOOK_SECRET` in the worktree's `.env.local` and start the
dev server. `route.ts` tries the connect secret first and falls back to the
platform one, so both must be the listener's.

Three things that will otherwise cost you a session:

1. **`--api-key "$STRIPE_SECRET_KEY"` is mandatory.** The CLI's stored login
   is a *different* Stripe account than the app's key. Without the flag the
   CLI silently listens on the wrong account: `stripe webhook_endpoints list`
   returns an empty list and no event ever reaches localhost.
2. **Events are delivered twice.** The registered TEST endpoints stay enabled
   and point at `dev.rogueops.app`, which serves `dev` against the *same*
   cloud DEV database. One event reaches both; `claimWebhookEvent` claims it
   in `payment_events`, so exactly one side processes it. Localhost normally
   wins the race (a local hop beats a Vercel round-trip) — but **prove which
   side won** rather than assuming, by choosing an assertion whose result
   differs between the PR's code and `dev`'s. Never report a pass on evidence
   both versions would produce.
3. **Making it deterministic needs a human.** Disabling the endpoints
   (`stripe webhook_endpoints update <we_id> -d disabled=true`) is refused by
   the auto-mode classifier; read-only `stripe … list/retrieve --api-key` is
   allowed. Hand the user the command to run via `!` rather than retrying
   variations. If they do disable them, **re-enable them before you finish** —
   staging drops every webhook while they're off.

For Stripe-hosted checkout pages, open the card accordion with
`dispatchEvent('click')` on `[data-testid="card-accordion-item-button"]` (an
invisible button intercepts real pointer events), fill `#cardNumber`,
`#cardExpiry`, `#cardCvc`, `#billingName`, and submit
`[data-testid="hosted-payment-submit-button"]`.

**Cloud DEV is shared infrastructure.** Runtime flows hit the team's staging
database, so: prefer read-only flows; when an item requires a write (a
booking, a purchase), use obviously-synthetic data and clean it up — or say
in the report what you left behind. If the PR contains migrations that
aren't applied to cloud DEV, its runtime items are **blocked** — never run
`db:push:dev` (or any schema change) to unblock them.

If the harness itself breaks — dev server won't boot, vitest errors out
before running a single test — that's a **blocked** result, not a failed
item; report it as such and move on to what's still verifiable.

## Step 5: Record results on the PR

1. **Update the description.** Re-fetch the PR at write time (`gh pr view <n>
   --json state,body`) — it must still be open, and the fetch must happen
   immediately before the edit to keep the race window small. Runtime runs
   are long; the author may have edited the plan mid-run. Flip `- [ ]` →
   `- [x]` only on lines that (a) sit between the `## Test plan` heading and
   the next `##` heading, and (b) still exactly match the item text you
   verified — if an item's wording changed, skip it and note the drift in the
   comment. A parent box is checked only when all its nested children are.
   Change nothing else in the body. **Never pass the body inline** (heredocs
   shell-expand backticks and `$(...)`, which PR bodies here are full of):
   write the modified body to a scratchpad file with the Write tool, then
   `gh pr edit <n> --body-file <path>`.

2. **Post or update one results comment.** Find a previous run's comment by
   its marker and update it instead of stacking new ones — same body-file
   rule:

```bash
gh api --paginate "repos/{owner}/{repo}/issues/<n>/comments" \
  --jq '.[] | select(.body | contains("<!-- test-pr:report -->")) | .id'
# update:  gh api -X PATCH "repos/{owner}/{repo}/issues/comments/<id>" -F body=@<path>
# create:  gh pr comment <n> --body-file <path>
```

Comment format:

```markdown
<!-- test-pr:report -->
## 🧪 Test plan verification — <date>, effort ceiling: <level>

| Item | Tier | Result | Evidence |
|------|------|--------|----------|
| `tsc --noEmit` clean | automated | ✅ pass | exit 0 |
| Dark-mode spot-check | runtime | ❌ **fail** | badge unreadable on dark bg — details below |
| RLS suite | deferred | ✅ CI pass | <run URL> |

### ❌ Failures
<per failure: what the item expected, what actually happened, file:line or repro steps>

### ⏭️ Not verified
<items above the effort ceiling or blocked, and what it would take to verify each>

### 📋 Coverage gaps
<test-plan items with no automated test behind them, worst first>
```

3. **If anything failed or was blocked**, the comment must lead with the
   failure, and notify the user — PushNotification if the tool is available;
   otherwise the final conversation message must open with the failure count
   in its first line. A clean run needs no notification.

Finish with a short summary in the conversation either way: counts per
result, failures with evidence, and the top coverage gaps.

## Guards

- Never commit, push, or modify code — this skill only verifies and reports.
- Never check a box without evidence; never check a failing or blocked item.
- Never edit anything in the PR body outside the test plan checkboxes.
- Never run `db:push:dev`, `db:reset:dev`, `seed:dev`, or any other schema or
  data reset against cloud DEV — migration-dependent items are blocked, not
  an excuse.
- Always clean up: remove the worktree and its `test-pr/<n>` branch, kill dev
  servers and `stripe listen` you started, leave the main checkout untouched.
- Never leave shared config changed. If verifying an item meant editing
  tenant/space configuration on cloud DEV (a plan, a program, a feature flag),
  restore the original values and **confirm the restore with a read** before
  reporting. Say in the report what you changed and that it was restored.
- Report Stripe test-mode residue explicitly — live test subscriptions keep
  generating invoices long after the run.
