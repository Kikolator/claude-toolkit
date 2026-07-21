#!/usr/bin/env bash
#
# create_worktree.sh — create a git worktree for a named branch, off the latest
# origin default branch, in a sibling <repo-name>.worktrees/ directory.
#
# Usage:
#   create_worktree.sh <branch-name> [--base <branch>] [--install] [--clone-deps]
#                      [--deps-from <path>] [--no-env-copy] [--rebase]
#
#   <branch-name>   Full branch name incl. type prefix, e.g. feat/47-webhook-retries
#   --base <b>      Base branch to fork from (default: origin's default branch)
#   --install       Run the detected package-manager install in the new worktree
#   --clone-deps    Copy-on-write clone node_modules from an existing checkout
#                   (APFS clonefile / reflink) instead of installing — near-zero
#                   extra disk, ideal on disk-constrained machines. Supersedes
#                   --install when both are given.
#   --deps-from <p> Source checkout to clone deps from (default: the main worktree)
#   --no-env-copy   Skip copying gitignored top-level .env* files into the worktree
#   --rebase        Rebase a reused branch onto the base ref (rewrites history;
#                   only do this on a branch that isn't shared/pushed-and-pulled)
#
# Behaviour:
#   - Must be run from inside a git repository working tree.
#   - Fetches origin first so the worktree forks from the latest remote state.
#   - Reuses an existing local/remote branch of the same name instead of failing.
#   - NEVER leaves you silently on a stale branch:
#       * a reused local branch that is merely behind its upstream is
#         fast-forwarded automatically (safe, no history rewrite);
#       * a diverged branch is left alone and reported;
#       * commits-behind-base is always measured and printed;
#       * if the fetch failed, freshness is reported as UNKNOWN, loudly.
#   - Copies gitignored top-level .env* files from the source checkout (they are
#     absent from a fresh worktree, which is the usual first-run breakage).
#   - Places the worktree in <repo>.worktrees/ next to the MAIN checkout even when
#     run from inside another worktree (the repo name is taken from the main
#     worktree, not the current directory).
#   - With --clone-deps, clones node_modules copy-on-write from an existing
#     checkout instead of installing, so a fresh worktree is runnable without
#     spending a full node_modules of disk per branch.
#   - Prints a machine-readable SUMMARY block at the end, incl. a freshness line.

set -euo pipefail

# ---- args -------------------------------------------------------------------
BRANCH=""
BASE=""
DO_INSTALL=0
COPY_ENV=1
DO_REBASE=0
FETCH_OK=0
CLONE_DEPS=0
DEPS_SRC=""

while [ $# -gt 0 ]; do
  case "$1" in
    --base)        BASE="${2:-}"; shift 2 ;;
    --install)     DO_INSTALL=1; shift ;;
    --clone-deps)  CLONE_DEPS=1; shift ;;
    --deps-from)   DEPS_SRC="${2:-}"; shift 2 ;;
    --no-env-copy) COPY_ENV=0; shift ;;
    --rebase)      DO_REBASE=1; shift ;;
    -h|--help)     grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    -*)            echo "error: unknown flag: $1" >&2; exit 2 ;;
    *)             if [ -z "$BRANCH" ]; then BRANCH="$1"; else echo "error: unexpected arg: $1" >&2; exit 2; fi; shift ;;
  esac
done

if [ -z "$BRANCH" ]; then
  echo "error: branch name is required. Usage: create_worktree.sh <branch-name> [--base <b>] [--install] [--no-env-copy]" >&2
  exit 2
fi

# ---- locate repo ------------------------------------------------------------
if ! REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)"; then
  echo "error: not inside a git repository. cd into the repo first." >&2
  exit 1
fi
# Anchor the repo name and the sibling .worktrees/ dir on the MAIN worktree (the
# first entry of `git worktree list`), not the current checkout. Run from inside a
# worktree, `git rev-parse --show-toplevel` returns that worktree, which would nest
# new worktrees under <worktree>.worktrees/ instead of the shared <repo>.worktrees/
# sibling. REPO_ROOT stays the current checkout so env files are still copied from
# where the user is working.
MAIN_ROOT="$(git worktree list --porcelain 2>/dev/null | sed -n 's/^worktree //p' | head -n1)"
[ -n "$MAIN_ROOT" ] || MAIN_ROOT="$REPO_ROOT"
REPO_NAME="$(basename "$MAIN_ROOT")"
PARENT_DIR="$(dirname "$MAIN_ROOT")"
WORKTREES_DIR="${PARENT_DIR}/${REPO_NAME}.worktrees"
WORKTREE_PATH="${WORKTREES_DIR}/${BRANCH}"

if [ -e "$WORKTREE_PATH" ]; then
  echo "error: worktree path already exists: $WORKTREE_PATH" >&2
  echo "       remove it or pick a different branch name." >&2
  exit 1
fi

# ---- origin / base branch ---------------------------------------------------
# Clear admin entries for worktrees whose directories are gone, so a stale
# registration can't block reusing a path/branch name.
git worktree prune 2>/dev/null || true

HAS_ORIGIN=0
if git remote get-url origin >/dev/null 2>&1; then
  HAS_ORIGIN=1
  echo "fetching origin..."
  if git fetch --quiet --prune origin; then
    FETCH_OK=1
  else
    echo "warning: git fetch origin failed (offline?); local refs may be stale" >&2
  fi
fi

if [ -z "$BASE" ]; then
  if [ "$HAS_ORIGIN" -eq 1 ]; then
    # origin/HEAD -> refs/remotes/origin/<default>
    if DEF="$(git symbolic-ref --quiet refs/remotes/origin/HEAD 2>/dev/null)"; then
      BASE="${DEF#refs/remotes/origin/}"
    elif git show-ref --verify --quiet refs/remotes/origin/main; then
      BASE="main"
    elif git show-ref --verify --quiet refs/remotes/origin/master; then
      BASE="master"
    fi
  fi
  # fall back to current branch if still unresolved (e.g. no origin)
  if [ -z "$BASE" ]; then
    BASE="$(git rev-parse --abbrev-ref HEAD)"
  fi
fi

# resolve the ref we actually fork from
if [ "$HAS_ORIGIN" -eq 1 ] && git show-ref --verify --quiet "refs/remotes/origin/${BASE}"; then
  BASE_REF="origin/${BASE}"
else
  BASE_REF="$BASE"
fi

mkdir -p "$WORKTREES_DIR"

# ---- create the worktree ----------------------------------------------------
MODE=""
if git show-ref --verify --quiet "refs/heads/${BRANCH}"; then
  # local branch already exists -> check it out into the worktree
  MODE="existing-local"
  git worktree add "$WORKTREE_PATH" "$BRANCH"
elif [ "$HAS_ORIGIN" -eq 1 ] && git show-ref --verify --quiet "refs/remotes/origin/${BRANCH}"; then
  # remote branch exists -> create a tracking local branch
  MODE="existing-remote"
  git worktree add --track -b "$BRANCH" "$WORKTREE_PATH" "origin/${BRANCH}"
else
  # brand new branch off the base
  MODE="new"
  git worktree add -b "$BRANCH" "$WORKTREE_PATH" "$BASE_REF"
fi

# ---- freshness: never leave the user silently on a stale branch --------------
# A brand-new branch is fresh by construction (forked from the just-fetched base).
# A reused branch may be behind its upstream and/or behind the base.
FRESHNESS=""
SYNC_ACTION="none"
BEHIND_BASE=0

if [ "$FETCH_OK" -eq 0 ] && [ "$HAS_ORIGIN" -eq 1 ]; then
  FRESHNESS="UNKNOWN — fetch failed, base may be behind origin"
elif [ "$HAS_ORIGIN" -eq 0 ]; then
  FRESHNESS="UNKNOWN — no origin remote; forked from local ${BASE_REF}"
elif [ "$MODE" = "new" ] || [ "$MODE" = "existing-remote" ]; then
  FRESHNESS="fresh — forked from just-fetched ${BASE_REF}"
else
  # existing-local: this is where staleness hides.
  UPSTREAM="$(git -C "$WORKTREE_PATH" rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null || true)"

  if [ -n "$UPSTREAM" ]; then
    read -r BEHIND_UP AHEAD_UP <<<"$(git -C "$WORKTREE_PATH" rev-list --left-right --count "${UPSTREAM}...HEAD" 2>/dev/null || echo '0 0')"
    if [ "$BEHIND_UP" -gt 0 ] && [ "$AHEAD_UP" -eq 0 ]; then
      # Pure fast-forward: safe to sync automatically, no history rewritten.
      echo "branch is ${BEHIND_UP} commit(s) behind ${UPSTREAM}; fast-forwarding..."
      if git -C "$WORKTREE_PATH" merge --ff-only "$UPSTREAM" >/dev/null 2>&1; then
        SYNC_ACTION="fast-forwarded to ${UPSTREAM}"
      else
        SYNC_ACTION="fast-forward FAILED — resolve manually"
      fi
    elif [ "$BEHIND_UP" -gt 0 ] && [ "$AHEAD_UP" -gt 0 ]; then
      SYNC_ACTION="DIVERGED from ${UPSTREAM} (${BEHIND_UP} behind, ${AHEAD_UP} ahead) — left untouched"
    fi
  fi

  # How far behind the base branch is this branch, regardless of upstream?
  BEHIND_BASE="$(git -C "$WORKTREE_PATH" rev-list --count "HEAD..${BASE_REF}" 2>/dev/null || echo 0)"
  if [ "$BEHIND_BASE" -gt 0 ]; then
    if [ "$DO_REBASE" -eq 1 ]; then
      echo "rebasing onto ${BASE_REF}..."
      if git -C "$WORKTREE_PATH" rebase "$BASE_REF" >/dev/null 2>&1; then
        SYNC_ACTION="rebased onto ${BASE_REF}"
        BEHIND_BASE=0
        FRESHNESS="fresh — rebased onto ${BASE_REF}"
      else
        git -C "$WORKTREE_PATH" rebase --abort >/dev/null 2>&1 || true
        SYNC_ACTION="rebase onto ${BASE_REF} CONFLICTED — aborted, branch unchanged"
        FRESHNESS="STALE — ${BEHIND_BASE} commit(s) behind ${BASE_REF}; rebase hit conflicts"
      fi
    else
      FRESHNESS="STALE — ${BEHIND_BASE} commit(s) behind ${BASE_REF}"
    fi
  fi
  [ -n "$FRESHNESS" ] || FRESHNESS="fresh — up to date with ${BASE_REF}"
fi

# ---- copy gitignored env files ----------------------------------------------
# Fresh worktrees don't contain gitignored files, and a missing .env is the #1
# cause of a broken first run. Monorepos keep them per-workspace (apps/web/.env.local),
# not just at the root, so ask git for every ignored .env* it knows about.
#
# --directory collapses wholly-ignored dirs (node_modules/, .next/) into a single
# entry instead of enumerating every file inside them, which keeps this fast.
COPIED_ENV=""
ENV_COUNT=0
if [ "$COPY_ENV" -eq 1 ]; then
  while IFS= read -r -d '' rel; do
    case "$rel" in
      */) continue ;;                         # collapsed ignored directory, not a file
    esac
    base="$(basename "$rel")"
    case "$base" in
      .env|.env.*) ;;                          # .env, .env.local, .env.development ...
      *) continue ;;
    esac
    # never resurrect env files from inside build/dependency dirs
    case "/$rel" in
      */node_modules/*|*/.next/*|*/dist/*|*/build/*|*/.turbo/*|*/coverage/*) continue ;;
    esac
    src="${REPO_ROOT}/${rel}"
    [ -f "$src" ] || continue
    dest="${WORKTREE_PATH}/${rel}"
    if [ ! -e "$dest" ]; then
      mkdir -p "$(dirname "$dest")"
      cp "$src" "$dest"
      COPIED_ENV="${COPIED_ENV}${rel} "
      ENV_COUNT=$((ENV_COUNT + 1))
    fi
  done < <(git -C "$REPO_ROOT" ls-files --others --ignored --exclude-standard --directory -z 2>/dev/null || true)
fi

# ---- optional dependency clone (copy-on-write) ------------------------------
# A fresh `npm install` per worktree is slow and costs a full node_modules of disk
# (~1 GB+ in a monorepo); several in parallel on a near-full disk can exhaust it.
# --clone-deps instead clones node_modules from an existing checkout using APFS
# clonefile (macOS) or reflink (Btrfs/XFS) — copy-on-write, so near-zero extra disk
# and near-instant. It clones the root plus every workspace node_modules (apps/*,
# packages/*), since monorepos hold per-workspace installs too. Workspace and .bin
# symlinks are relative, so they resolve inside the new worktree.
CLONED_DEPS="no"
if [ "$CLONE_DEPS" -eq 1 ]; then
  DEPS_SRC="${DEPS_SRC:-$MAIN_ROOT}"
  if [ ! -d "${DEPS_SRC}/node_modules" ]; then
    echo "warning: --clone-deps: no node_modules found at ${DEPS_SRC}; nothing cloned" >&2
    CLONED_DEPS="skipped — no node_modules at ${DEPS_SRC}"
  else
    _n=0
    while IFS= read -r _nm; do
      _rel="${_nm#"${DEPS_SRC}"/}"
      _dst="${WORKTREE_PATH}/${_rel}"
      [ -e "$_dst" ] && continue
      mkdir -p "$(dirname "$_dst")"
      # Prefer copy-on-write; fall back to a plain recursive copy off APFS/reflink.
      if cp -cR "$_nm" "$_dst" 2>/dev/null \
         || cp -R --reflink=auto "$_nm" "$_dst" 2>/dev/null \
         || cp -R "$_nm" "$_dst" 2>/dev/null; then
        _n=$((_n + 1))
      else
        echo "warning: failed to clone ${_rel}" >&2
      fi
    done < <(find "$DEPS_SRC" -maxdepth 3 -type d -name node_modules -not -path '*/node_modules/*' 2>/dev/null)
    CLONED_DEPS="yes — ${_n} tree(s) from ${DEPS_SRC}"
  fi
fi

# ---- optional dependency install --------------------------------------------
INSTALL_CMD=""
if   [ -f "${WORKTREE_PATH}/pnpm-lock.yaml" ];  then INSTALL_CMD="pnpm install"
elif [ -f "${WORKTREE_PATH}/bun.lockb" ] || [ -f "${WORKTREE_PATH}/bun.lock" ]; then INSTALL_CMD="bun install"
elif [ -f "${WORKTREE_PATH}/yarn.lock" ];       then INSTALL_CMD="yarn install"
elif [ -f "${WORKTREE_PATH}/package-lock.json" ]; then INSTALL_CMD="npm install"
fi

INSTALLED="no"
if [ "$DO_INSTALL" -eq 1 ] && [ "$CLONE_DEPS" -eq 1 ]; then
  echo "note: --clone-deps supersedes --install; skipping install" >&2
elif [ "$DO_INSTALL" -eq 1 ] && [ -n "$INSTALL_CMD" ]; then
  echo "installing dependencies: $INSTALL_CMD"
  ( cd "$WORKTREE_PATH" && eval "$INSTALL_CMD" ) && INSTALLED="yes" || echo "warning: install failed" >&2
fi

# ---- summary ----------------------------------------------------------------
cat <<EOF

=== SUMMARY ===
repo:          ${REPO_NAME}
branch:        ${BRANCH}   (${MODE})
base:          ${BASE_REF}
freshness:     ${FRESHNESS}
sync:          ${SYNC_ACTION}
worktree:      ${WORKTREE_PATH}
env copied:    ${COPIED_ENV:-none found}
deps cloned:   ${CLONED_DEPS}
install cmd:   ${INSTALL_CMD:-none detected}
installed:     ${INSTALLED}
cd:            cd "${WORKTREE_PATH}"
===============
EOF

if [ "$BEHIND_BASE" -gt 0 ]; then
  cat >&2 <<EOF
STALE BRANCH: ${BRANCH} is ${BEHIND_BASE} commit(s) behind ${BASE_REF}.
  Sync it before you start, or you'll be building on old code:
    git -C "${WORKTREE_PATH}" rebase ${BASE_REF}     # rewrites history
    git -C "${WORKTREE_PATH}" merge ${BASE_REF}      # preserves history
  Or re-run this script with --rebase.
EOF
fi
