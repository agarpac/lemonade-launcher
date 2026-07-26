#!/usr/bin/env bash
#
# check-upstream.sh — report what is new in the upstream Arc Launcher repo
# relative to the commit this fork ("Lemonade Launcher") started from.
#
# This script is READ-ONLY with respect to the working tree: it only fetches
# refs from the `upstream` remote and inspects them. It never checks out,
# merges, or modifies any file. It is safe to run with a dirty working tree.
#
# Usage: ./scripts/check-upstream.sh
set -euo pipefail

# ---------------------------------------------------------------------------
# Single source of truth for the baseline. Update this ONE line when the fork
# is rebased onto a newer upstream version.
# ---------------------------------------------------------------------------
readonly BASELINE_TAG="1.0.6"

readonly UPSTREAM_REMOTE="upstream"
readonly DOCS_POINTER="docs/UPSTREAM.md"

# --- sanity checks ----------------------------------------------------------

if ! git remote get-url "${UPSTREAM_REMOTE}" >/dev/null 2>&1; then
  echo "ERROR: git remote '${UPSTREAM_REMOTE}' is not configured." >&2
  echo "Add it with:" >&2
  echo "  git remote add ${UPSTREAM_REMOTE} https://github.com/meddouribadis/arclauncher.git" >&2
  exit 1
fi

if ! git rev-parse "${BASELINE_TAG}" >/dev/null 2>&1; then
  echo "ERROR: baseline tag '${BASELINE_TAG}' was not found locally." >&2
  echo "Fetch tags first with: git fetch ${UPSTREAM_REMOTE} --tags" >&2
  exit 1
fi

# --- fetch (read-only w.r.t. the working tree) ------------------------------

echo "==> Fetching ${UPSTREAM_REMOTE} (tags + refs)..."
git fetch "${UPSTREAM_REMOTE}" --tags --quiet

readonly UPSTREAM_MAIN="${UPSTREAM_REMOTE}/main"
readonly BASELINE_COMMIT="$(git rev-parse "${BASELINE_TAG}^{commit}")"

echo
echo "Baseline: tag ${BASELINE_TAG} (commit ${BASELINE_COMMIT})"
echo "Comparing against: ${UPSTREAM_MAIN}"
echo

# --- (a) release tags newer than the baseline -------------------------------

echo "--- (a) Upstream release tags newer than ${BASELINE_TAG} ---"
newer_tags="$(
  git for-each-ref --sort=-creatordate --format='%(refname:short) %(creatordate:short)' refs/tags |
    awk -v baseline="${BASELINE_TAG}" '$1 == baseline { found=1 } !found { print } $1 == baseline { exit }'
)"
if [ -z "${newer_tags}" ]; then
  echo "(none — ${BASELINE_TAG} is the newest known tag)"
else
  echo "${newer_tags}"
fi
echo

# --- (b) commits since baseline ---------------------------------------------

echo "--- (b) Commits on ${UPSTREAM_MAIN} since ${BASELINE_TAG} ---"
commit_count="$(git rev-list --count "${BASELINE_TAG}..${UPSTREAM_MAIN}")"
echo "Count: ${commit_count}"
if [ "${commit_count}" -gt 0 ]; then
  git log --oneline "${BASELINE_TAG}..${UPSTREAM_MAIN}"
else
  echo "(no new commits)"
fi
echo

# --- (c) files changed since baseline ----------------------------------------

echo "--- (c) Files changed on ${UPSTREAM_MAIN} since ${BASELINE_TAG} ---"
if [ "${commit_count}" -gt 0 ]; then
  changed_files="$(git diff --stat "${BASELINE_TAG}..${UPSTREAM_MAIN}")"
  file_count="$(git diff --name-only "${BASELINE_TAG}..${UPSTREAM_MAIN}" | wc -l | tr -d ' ')"
  echo "Files changed: ${file_count}"
  echo "${changed_files}"
else
  echo "Files changed: 0"
fi
echo

# --- (d) pointer to the evaluation log ---------------------------------------

echo "--- (d) Recording verdicts ---"
echo "Record any adoption decision (Adoptar / Descartar / Pendiente) in ${DOCS_POINTER}."
echo "See docs/UPSTREAM.md for how to inspect a single file (git show <tag>:<path>)"
echo "and how to adopt one change (cherry-pick vs. selective patch)."
