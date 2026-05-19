#!/usr/bin/env bash
# =============================================================================
# detect-changes.sh — shared change detection for engine-ci and cli-ci
# =============================================================================
#
# Purpose:
#   Decide whether a given component (engine or cli) should rebuild based on
#   what files changed between two git revisions. Used by both Jenkinsfiles so
#   the logic stays in one place (DRY) and the two pipelines can't drift.
#
# Usage:
#   bash detect-changes.sh <component> [base_sha] [head_sha]
#
#     <component>   "engine" or "cli"
#     base_sha      optional, default HEAD~1
#     head_sha      optional, default HEAD
#
# Exit codes:
#   0  -> relevant files changed; pipeline should REBUILD
#   1  -> no relevant changes; pipeline should SKIP
#   2  -> usage error
#
# The "relevant paths" rules implement the version-coupling contract:
#
#   engine triggers on:  engine/**,  docker/engine.Dockerfile,  VERSION
#   cli    triggers on:  cli/**,     docker/cli.Dockerfile,     VERSION
#
# Note: VERSION is in BOTH lists on purpose. When VERSION changes (whether by
# manual bump or by the engine-CI auto-bumper), both pipelines re-run so that
# the engine and CLI Docker images stay tagged at the same semver.
# =============================================================================

set -euo pipefail

COMPONENT="${1:?Usage: $0 <engine|cli> [base_sha] [head_sha]}"
BASE_SHA="${2:-HEAD~1}"
HEAD_SHA="${3:-HEAD}"

echo "[detect-changes] component=$COMPONENT range=$BASE_SHA..$HEAD_SHA"

# In a fresh shallow clone (typical for first build), HEAD~1 may not exist.
# Fall back to diffing against the empty tree (everything is "new").
if ! git rev-parse --verify --quiet "$BASE_SHA" >/dev/null 2>&1; then
  echo "[detect-changes] $BASE_SHA does not exist (shallow clone?) — treating all files as changed"
  CHANGED=$(git ls-files)
else
  CHANGED=$(git diff --name-only "$BASE_SHA" "$HEAD_SHA")
fi

echo "[detect-changes] Changed files:"
if [[ -z "$CHANGED" ]]; then
  echo "  (none)"
else
  echo "$CHANGED" | sed 's/^/  /'
fi

case "$COMPONENT" in
  engine)
    if echo "$CHANGED" | grep -qE '^(engine/|docker/engine\.Dockerfile$|VERSION$)'; then
      echo "[detect-changes] engine: relevant changes -> REBUILD"
      exit 0
    fi
    echo "[detect-changes] engine: no relevant changes -> SKIP"
    exit 1
    ;;
  cli)
    if echo "$CHANGED" | grep -qE '^(cli/|docker/cli\.Dockerfile$|VERSION$)'; then
      echo "[detect-changes] cli: relevant changes -> REBUILD"
      exit 0
    fi
    echo "[detect-changes] cli: no relevant changes -> SKIP"
    exit 1
    ;;
  *)
    echo "[detect-changes] ERROR: unknown component '$COMPONENT' (expected: engine|cli)" >&2
    exit 2
    ;;
esac
