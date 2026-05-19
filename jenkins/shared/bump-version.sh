#!/usr/bin/env bash
# =============================================================================
# bump-version.sh — idempotent, race-safe semver PATCH bumper
# =============================================================================
#
# Called by the engine-ci pipeline at the end of a successful main-branch build.
# Bumps PATCH of VERSION, commits with [skip ci], tags v<X.Y.Z>, and pushes.
#
# Defended failure modes:
#   1. Infinite loop  -> [skip ci] marker in commit message + self-detection
#   2. Double-bump    -> if VERSION was already changed in HEAD commit (manual
#                        bump by a developer), do nothing
#   3. Race condition -> `git pull --rebase` + retry on push (up to 3 times)
#   4. Wrong branch   -> only bumps on main; safe no-op elsewhere
#
# Usage:
#   bash bump-version.sh
#
# Environment overrides:
#   GIT_USER_NAME   default: jenkins-bot
#   GIT_USER_EMAIL  default: jenkins@ayalmauda.dev
#   SKIP_PUSH       default: 0 (set 1 for local dry-run)
#   MAX_RETRIES     default: 3
#
# Exit codes:
#   0  -> success OR intentional skip (no-op)
#   1  -> error (invalid VERSION, missing file, push failed after retries)
# =============================================================================

set -euo pipefail

GIT_USER_NAME="${GIT_USER_NAME:-jenkins-bot}"
GIT_USER_EMAIL="${GIT_USER_EMAIL:-jenkins@ayalmauda.dev}"
SKIP_PUSH="${SKIP_PUSH:-0}"
MAX_RETRIES="${MAX_RETRIES:-3}"

# ---- Pre-flight guards ----

# Guard 1: refuse to bump off main
BRANCH="$(git rev-parse --abbrev-ref HEAD)"
if [[ "$BRANCH" != "main" ]]; then
  echo "[bump-version] not on main (current: $BRANCH) — skipping (this is normal for PRs)"
  exit 0
fi

# Guard 2: VERSION file must exist
if [[ ! -f VERSION ]]; then
  echo "[bump-version] ERROR: VERSION file not found at repo root" >&2
  exit 1
fi

# Guard 3: if the triggering commit ALREADY changed VERSION, the developer
# intentionally set the version. DO NOT clobber their intent.
if git diff HEAD~1 HEAD --name-only 2>/dev/null | grep -qx VERSION; then
  echo "[bump-version] VERSION was already changed in HEAD commit (manual bump detected) — skipping auto-bump"
  exit 0
fi

# Guard 4: if HEAD commit is from us (the bumper itself), abort to break the loop.
LAST_COMMIT_MSG="$(git log -1 --pretty=%B)"
if [[ "$LAST_COMMIT_MSG" == *"[skip ci]"* ]] || [[ "$LAST_COMMIT_MSG" == *"ci: bump version"* ]]; then
  echo "[bump-version] HEAD is a bumper commit — skipping to avoid infinite loop"
  exit 0
fi

# ---- Compute new version ----

CURRENT="$(tr -d '[:space:]' < VERSION)"
if ! [[ "$CURRENT" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
  echo "[bump-version] ERROR: VERSION '$CURRENT' is not valid semver MAJOR.MINOR.PATCH" >&2
  exit 1
fi

MAJOR="${BASH_REMATCH[1]}"
MINOR="${BASH_REMATCH[2]}"
PATCH="${BASH_REMATCH[3]}"
NEW_PATCH=$((PATCH + 1))
NEW_VERSION="${MAJOR}.${MINOR}.${NEW_PATCH}"

echo "[bump-version] $CURRENT -> $NEW_VERSION"

if [[ "$SKIP_PUSH" == "1" ]]; then
  echo "[bump-version] SKIP_PUSH=1 — dry-run, not committing"
  exit 0
fi

# ---- Commit + tag + push (with rebase+retry) ----

git config user.name  "$GIT_USER_NAME"
git config user.email "$GIT_USER_EMAIL"

echo "$NEW_VERSION" > VERSION
git add VERSION
git commit -m "ci: bump version to $NEW_VERSION [skip ci]"
git tag "v$NEW_VERSION"

attempt=1
while [[ $attempt -le $MAX_RETRIES ]]; do
  echo "[bump-version] push attempt $attempt of $MAX_RETRIES"
  if git pull --rebase --autostash origin main && git push origin HEAD:main --follow-tags; then
    echo "[bump-version] SUCCESS: pushed v$NEW_VERSION to origin"
    exit 0
  fi
  echo "[bump-version] push failed; backing off..."
  sleep $((attempt * 2))
  attempt=$((attempt + 1))
done

echo "[bump-version] ERROR: failed to push after $MAX_RETRIES retries" >&2
exit 1
