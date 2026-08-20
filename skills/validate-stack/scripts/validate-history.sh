#!/usr/bin/env bash
# Per-commit validation for a curated single-branch history. Reports anomalies
# only. The equivalence proof guarantees the END of a rewrite; this guarantees
# the PATH — every commit a reviewer will read builds on its own.
#
#   validate-history.sh --base REF [--head REF] [--check CMD]
#                       [--equals REF] [--marker-prefix "TODO(pacer:"]
#
# --base    what the branch lands on (required), e.g. origin/CR-2533
# --head    the curated head (default: HEAD)
# --check   command run at every commit (default: the package.json
#           type-check/typecheck/tsc script, via pnpm or npm)
# --equals  ref the head must be byte-identical to (the pre-rewrite branch)
#
# Runs in place with detached checkouts so node_modules is reused; requires a
# clean working tree and restores the starting point on exit. Budget roughly
# one type-check per commit. If the lockfile changes across the range, the
# reused node_modules can produce false failures — reinstall and re-run.
#
# Exit codes: 0 clean, 1 anomalies found, 2 usage/setup error.

set -o pipefail

BASE=""; HEAD="HEAD"; CHECK=""; EQUALS=""; MARKER="TODO(pacer:"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --base) BASE="$2"; shift 2 ;;
    --head) HEAD="$2"; shift 2 ;;
    --check) CHECK="$2"; shift 2 ;;
    --equals) EQUALS="$2"; shift 2 ;;
    --marker-prefix) MARKER="$2"; shift 2 ;;
    -h|--help) sed -n '2,19p' "$0"; exit 0 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

[[ -z "$BASE" ]] && { echo "--base is required" >&2; exit 2; }
git rev-parse --git-dir >/dev/null 2>&1 || { echo "not a git repository" >&2; exit 2; }
git rev-parse -q --verify "$BASE^{commit}" >/dev/null || { echo "base $BASE not found" >&2; exit 2; }
git rev-parse -q --verify "$HEAD^{commit}" >/dev/null || { echo "head $HEAD not found" >&2; exit 2; }
[[ -n "$(git status --porcelain --untracked-files=no)" ]] && { echo "working tree has tracked changes — commit or stash first" >&2; exit 2; }

if [[ -z "$CHECK" ]]; then
  tc="$(node -e 'try{const s=require("./package.json").scripts||{};process.stdout.write(s["type-check"]?"type-check":(s.typecheck?"typecheck":(s.tsc?"tsc":"")))}catch(e){}' 2>/dev/null)"
  [[ -z "$tc" ]] && { echo "no type-check script in package.json — pass --check" >&2; exit 2; }
  if command -v pnpm >/dev/null; then CHECK="pnpm run --silent $tc"; else CHECK="npm run --silent $tc"; fi
fi

ISSUES=0
fail() { ISSUES=$((ISSUES + 1)); printf '✗ %s\n' "$1"; }

RESTORE="$(git rev-parse --abbrev-ref HEAD)"
[[ "$RESTORE" == "HEAD" ]] && RESTORE="$(git rev-parse HEAD)"
trap 'git checkout -q "$RESTORE" 2>/dev/null' EXIT

COMMITS=($(git rev-list --reverse "$BASE".."$HEAD"))
COUNT=${#COMMITS[@]}
[[ $COUNT -eq 0 ]] && { echo "no commits in $BASE..$HEAD" >&2; exit 2; }
echo "history: $COUNT commits on $BASE (check: $CHECK)"

# ── 1. Every commit builds on its own ────────────────────────────────────────
for sha in "${COMMITS[@]}"; do
  short="$(git rev-parse --short "$sha")"
  subject="$(git log -1 --format=%s "$sha")"
  git checkout -q --detach "$sha" 2>/dev/null || { fail "checkout: $short"; continue; }
  bash -c "$CHECK" >/dev/null 2>&1 || fail "build: $short \"$subject\" fails on its own"
done

# ── 2. Marker census — zero at EVERY commit, this is published history ───────
if [[ -n "$MARKER" ]]; then
  for sha in "${COMMITS[@]}"; do
    n="$(git grep -c -F "$MARKER" "$sha" -- . 2>/dev/null | awk -F: '{s+=$2} END {print s+0}')"
    [[ "$n" -gt 0 ]] && fail "markers: $n at $(git rev-parse --short "$sha") — placeholders never reach a published commit"
  done
fi

# ── 3. Equivalence with the pre-rewrite branch ───────────────────────────────
if [[ -n "$EQUALS" ]]; then
  if git rev-parse -q --verify "$EQUALS^{commit}" >/dev/null; then
    d=$(git diff "$EQUALS" "$HEAD" -- . | wc -l | tr -d ' ')
    [[ "$d" -ne 0 ]] && fail "equivalence: $HEAD differs from $EQUALS ($d diff lines)"
  else
    fail "equivalence: $EQUALS not found"
  fi
fi

# ── Summary ──────────────────────────────────────────────────────────────────
if [[ $ISSUES -eq 0 ]]; then
  echo "✓ $COUNT commits, each builds alone, no markers$([[ -n "$EQUALS" ]] && echo ', equivalence holds')"
  exit 0
fi
echo "$ISSUES issue(s) found"
exit 1
