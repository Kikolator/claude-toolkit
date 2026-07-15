# gh cookbook

Exact commands for fetching issues (step 2) and, only after approval, mirroring the plan into GitHub (step 8). Assumes `gh` is authed. Verify with `gh auth status` first; if it fails, fall back to `gh api` with `GITHUB_TOKEN` or ask the user.

All commands run from inside the local clone, so `gh` resolves the repo from the git remote automatically. To target another repo, add `--repo owner/name`.

---

## Read: fetch open issues

Pull open issues as JSON with the fields the analysis needs. This excludes pull requests automatically (`gh issue list` only returns issues).

```bash
gh issue list --state open --limit 100 \
  --json number,title,body,labels,assignees,milestone,comments,createdAt,updatedAt
```

Filter when there are too many:

```bash
# by label
gh issue list --state open --label bug --json number,title,body,labels

# by search query (e.g., only unassigned)
gh issue search "is:open no:assignee" --json number,title,labels
```

Read a single issue in full, including its comment thread, when the body references discussion:

```bash
gh issue view <number> --comments
```

## Read: current version and tags

```bash
git tag --sort=-v:refname | head -5        # latest semver tags
gh release list --limit 5                   # published releases
node -p "require('./package.json').version" 2>/dev/null   # if Node project
```

---

## Write (approval required)

Everything below modifies the user's repo. Do not run any of it until you have shown the full set of intended changes and the user has explicitly said yes. Present it as a concrete list ("create 3 milestones, 3 labels, assign 12 issues") plus the commands, then wait.

### Create one milestone per proposed release

There is no `gh milestone` porcelain command; use the API:

```bash
gh api repos/{owner}/{repo}/milestones \
  -f title="v1.4.1" \
  -f state="open" \
  -f description="Patch release"
```

Keep the description short (the release type is enough). Do not list the issue numbers in the description free-text: milestone membership already tracks exactly which issues belong, and a hand-typed list is a second source of truth that drifts out of sync with the assignment commands the moment anything changes. If the user wants the issue list visible, point them at the milestone view, which is always accurate.

Milestone numbers are returned in the response; capture them to assign issues, or fetch existing ones:

```bash
gh api repos/{owner}/{repo}/milestones --jq '.[] | {number, title}'
```

### Create semver and group labels

```bash
gh label create "semver:patch" --color 0E8A16 --description "Backwards-compatible fix" --force
gh label create "semver:minor" --color FBCA04 --description "Backwards-compatible feature" --force
gh label create "semver:major" --color D93F0B --description "Breaking change" --force
gh label create "group:auth"   --color 5319E7 --description "Batched: auth module" --force
```

`--force` updates the label if it already exists instead of erroring.

### Assign issues to milestones and labels

Label each issue with **its own semver from the analysis table, not the release's bump.** A release's bump is the highest bump among its issues, but the issues inside it are mixed: a patch release routinely carries `none`-classified work (CI fixes, verification chores, investigations) alongside the actual patches. Tagging every issue in a patch milestone `semver:patch` is wrong and will mislabel that `none` work. So drive the label from the table's Semver column per issue:
- patch issue → `--add-label "semver:patch"`
- minor issue → `--add-label "semver:minor"`
- major issue → `--add-label "semver:major"`
- **none issue → no `semver:*` label at all** (assign the milestone and any group label, but leave semver off). Only add a `semver:none` label if the user specifically wants every issue tagged.

```bash
gh issue edit <number> --milestone "v1.4.1" --add-label "semver:patch,group:auth"
```

Batch by semver tier, not by milestone, so each loop applies the right label:

```bash
# patch-classified issues going into v1.4.1
for n in 12 15 18; do
  gh issue edit "$n" --milestone "v1.4.1" --add-label "semver:patch"
done
# none-classified issues also shipping in v1.4.1 — milestone only, no semver label
for n in 21 22; do
  gh issue edit "$n" --milestone "v1.4.1"
done
```

**One issue, one milestone.** GitHub lets an issue belong to a single milestone. When an issue's work is split across releases (a sub-fix now, the rest of it later, as with a bug whose full resolution needs a pending product decision), assign it to the **earlier** milestone where the first piece ships, and tell the user it stays **open** after that release, since the remaining work continues. Don't imply the release closes it.

---

## Safety reminders

- Reads are safe and can run freely. Writes (`milestones` POST, `label create`, `issue edit`) need explicit per-session approval.
- Never delete or close issues, never delete labels or milestones, as part of this workflow. If cleanup is wanted, that's a separate, explicitly-confirmed request.
- If a write command fails on auth or permissions, surface the error and the failing command to the user rather than retrying blindly.
