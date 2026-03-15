---
name: commit-push-pr
description: Commits staged changes, pushes to remote, and creates a GitHub PR with a structured description. Runs in the main conversation context.
allowed-tools:
  - Bash
  - Read
  - Glob
  - Grep
---

# Commit, Push & Create PR

When the user invokes this skill, perform the following steps:

## Step 1: Assess Changes

Run these commands to understand the current state:
- `git status` — see staged/unstaged changes
- `git diff --cached` — review what will be committed
- `git log --oneline -5` — check recent commit style

If nothing is staged, ask the user what to stage or suggest staging all modified files (excluding secrets/env files).

## Step 2: Commit

1. Analyze the staged diff to understand the nature of the changes.
2. Draft a commit message following the project's existing style (check recent `git log`).
3. Use conventional commit format if the project uses it, otherwise match existing style.
4. Create the commit.

## Step 3: Push

1. Check if the current branch tracks a remote: `git rev-parse --abbrev-ref --symbolic-full-name @{upstream}`
2. If no upstream, push with `-u`: `git push -u origin <branch>`
3. If upstream exists, push: `git push`

## Step 4: Create PR

1. Check if a PR already exists: `gh pr view --json number 2>/dev/null`
2. If no PR exists, create one:
   - Title: concise summary under 70 characters
   - Body: structured with Summary, Test Plan, and any relevant context
   - Use `gh pr create`
3. If a PR exists, inform the user and show the PR URL.

## Guards

- Never force push
- Never push to main/master directly — warn the user and suggest creating a branch
- Never commit files matching: `.env*`, `*.pem`, `*credentials*`, `*secret*`
- Always show the commit message and PR body for user approval before executing

## TODO
- [ ] Add support for draft PRs (--draft flag)
- [ ] Add auto-labeling based on changed file paths
- [ ] Add reviewer assignment from CODEOWNERS
- [ ] Add linked issue detection from branch name
