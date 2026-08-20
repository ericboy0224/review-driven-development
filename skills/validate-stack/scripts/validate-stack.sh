#!/usr/bin/env bash
# Structural validation for a stacked-PR ladder. Reports anomalies only.
#
#   validate-stack.sh [--pr N | --branch NAME] --trunk REF [--full]
#                     [--equals REF] [--marker-prefix TODO(pacer:]
#                     [--repo OWNER/NAME]
#
# --trunk is what the bottom rung lands on. Without it the walk keeps going
# down through any PR the trunk itself has open, and reports on rungs that are
# not yours.
#
# Exit codes: 0 clean, 1 anomalies found, 2 usage/setup error.

set -o pipefail

PR=""; BRANCH=""; FULL=0; EQUALS=""; MARKER="TODO(pacer:"; REPO=""; TRUNK_ARG=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --pr) PR="$2"; shift 2 ;;
    --branch) BRANCH="$2"; shift 2 ;;
    --trunk) TRUNK_ARG="$2"; shift 2 ;;
    --full) FULL=1; shift ;;
    --equals) EQUALS="$2"; shift 2 ;;
    --marker-prefix) MARKER="$2"; shift 2 ;;
    --repo) REPO="$2"; shift 2 ;;
    -h|--help) sed -n '2,9p' "$0"; exit 0 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

command -v gh >/dev/null || { echo "gh not found" >&2; exit 2; }
git rev-parse --git-dir >/dev/null 2>&1 || { echo "not a git repository" >&2; exit 2; }
GHR_FLAG=${REPO:+--repo $REPO}

ISSUES=0
note() { printf '  %s\n' "$1"; }
fail() { ISSUES=$((ISSUES + 1)); printf '✗ %s\n' "$1"; }
warn() { printf '! %s\n' "$1"; }

# ── Discover the ladder, top-down, by walking base refs ──────────────────────
[[ -z "$PR" && -z "$BRANCH" ]] && BRANCH="$(git rev-parse --abbrev-ref HEAD)"
if [[ -z "$PR" ]]; then
  PR="$(gh pr list $GHR_FLAG --head "$BRANCH" --state open --json number \
        --jq '.[0].number // empty')"
  [[ -z "$PR" ]] && { echo "no open PR for branch $BRANCH" >&2; exit 2; }
fi

declare -a NUMS=() HEADS=() BASES=() TITLES=()
cur="$PR"
while [[ -n "$cur" ]]; do
  read -r n h b t < <(gh pr view "$cur" $GHR_FLAG \
    --json number,headRefName,baseRefName,title \
    --jq '[.number, .headRefName, .baseRefName, .title] | @tsv' 2>/dev/null) || break
  [[ -z "${n:-}" ]] && break
  NUMS=("$n" "${NUMS[@]}"); HEADS=("$h" "${HEADS[@]}")
  BASES=("$b" "${BASES[@]}"); TITLES=("$t" "${TITLES[@]}")
  [[ -n "$TRUNK_ARG" && "$b" == "$TRUNK_ARG" ]] && break
  cur="$(gh pr list $GHR_FLAG --head "$b" --state open --json number \
         --jq '.[0].number // empty')"
done

COUNT=${#NUMS[@]}
[[ $COUNT -eq 0 ]] && { echo "could not resolve a ladder from #$PR" >&2; exit 2; }
TRUNK="${BASES[0]}"
echo "ladder: ${COUNT} rungs on ${TRUNK}"

git fetch -q origin 2>/dev/null

# ── 1. Base chain ────────────────────────────────────────────────────────────
for ((i = 1; i < COUNT; i++)); do
  [[ "${BASES[$i]}" == "${HEADS[$((i - 1))]}" ]] || \
    fail "chain: #${NUMS[$i]} targets ${BASES[$i]}, expected ${HEADS[$((i - 1))]}"
done

# ── 2. Stack membership ──────────────────────────────────────────────────────
# `gh stack view` reads local tracking, not the PR: a stack created with
# `gh stack link` is invisible to it. Only a positive answer is trustworthy.
if gh stack --help >/dev/null 2>&1; then
  linked="$(gh stack view $GHR_FLAG 2>/dev/null | grep -cE '#[0-9]+' || true)"
  if [[ "${linked:-0}" -eq 0 ]]; then
    warn "membership: unverifiable from here (gh stack view needs local tracking) — confirm the ⧉ badge on #${NUMS[0]}"
  elif [[ "$linked" -ne "$COUNT" ]]; then
    warn "membership: stack lists $linked PRs, ladder has $COUNT"
  fi
else
  warn "membership: gh-stack extension not installed, link state unchecked"
fi

# ── 3. Sizes — information only, never a failure ─────────────────────────────
# Readability decides boundaries; line count is a symptom (see SKILL.md and the
# README field notes — the old <100/400 bands are retired).
sizes=""
for ((i = 0; i < COUNT; i++)); do
  base="origin/${BASES[$i]}"; head="origin/${HEADS[$i]}"
  git rev-parse -q --verify "$base" >/dev/null || continue
  git rev-parse -q --verify "$head" >/dev/null || continue
  n=$(git diff --numstat "$base...$head" | awk '{a+=$1; d+=$2} END {print a+d+0}')
  sizes="$sizes #${NUMS[$i]}:$n"
done
[[ -n "$sizes" ]] && note "sizes (lines):$sizes"

# ── 4. Marker census ─────────────────────────────────────────────────────────
if [[ -n "$MARKER" ]]; then
  prev=-1; declare -a SEEN_TAGS=()
  for ((i = 0; i < COUNT; i++)); do
    head="origin/${HEADS[$i]}"
    git rev-parse -q --verify "$head" >/dev/null || continue
    tags="$(git grep -h -oF "$MARKER" "$head" -- . 2>/dev/null | wc -l | tr -d ' ')"
    # The skeleton introduces the markers; only rungs above it must decrease.
    if [[ $prev -gt 0 && $tags -gt $prev ]]; then
      fail "markers: #${NUMS[$i]} has $tags markers, more than the rung below ($prev)"
    fi
    prev=$tags
    while IFS= read -r tag; do
      [[ -n "$tag" ]] && SEEN_TAGS+=("$tag")
    done < <(git grep -h -oE "${MARKER//[()]/.}[A-Za-z0-9]+" "$head" -- . 2>/dev/null | sort -u)
  done
  top="origin/${HEADS[$((COUNT - 1))]}"
  if git rev-parse -q --verify "$top" >/dev/null; then
    left="$(git grep -h -oF "$MARKER" "$top" -- . 2>/dev/null | wc -l | tr -d ' ')"
    [[ "$left" -gt 0 ]] && fail "markers: $left left at the top of the stack"
  fi
  # every referenced rung label must match a live PR title
  for tag in $(printf '%s\n' "${SEEN_TAGS[@]:-}" | sort -u); do
    label="${tag##*:}"; label="${label%%)*}"
    [[ -z "$label" ]] && continue
    hit=0
    for t in "${TITLES[@]}"; do [[ "$t" == *"$label"* ]] && hit=1; done
    [[ $hit -eq 0 ]] && fail "markers: $label is referenced but no rung is titled for it"
  done
fi

# ── 5. Bodies referencing folded / closed PRs ────────────────────────────────
for ((i = 0; i < COUNT; i++)); do
  body="$(gh pr view "${NUMS[$i]}" $GHR_FLAG --json body --jq '.body' 2>/dev/null)"
  for ref in $(printf '%s' "$body" | grep -oE '#[0-9]{2,}' | tr -d '#' | sort -u); do
    state="$(gh pr view "$ref" $GHR_FLAG --json state --jq '.state' 2>/dev/null)"
    [[ "$state" == "CLOSED" ]] && \
      fail "body: #${NUMS[$i]} links #$ref, which is closed"
  done
done

# ── 6. Equivalence (retro splits) ────────────────────────────────────────────
if [[ -n "$EQUALS" ]]; then
  top="origin/${HEADS[$((COUNT - 1))]}"
  if git rev-parse -q --verify "$EQUALS" >/dev/null; then
    d=$(git diff "$EQUALS" "$top" -- . | wc -l | tr -d ' ')
    [[ "$d" -ne 0 ]] && fail "equivalence: top of stack differs from $EQUALS ($d diff lines)"
  else
    warn "equivalence: $EQUALS not found locally"
  fi
fi

# ── 7. Per-rung build (full mode) ────────────────────────────────────────────
if [[ $FULL -eq 1 ]]; then
  if [[ -n "$(git status --porcelain)" ]]; then
    warn "build: working tree is dirty, skipping per-rung build"
  else
    restore="$(git rev-parse --abbrev-ref HEAD)"
    tc="$(node -e 'try{const s=require("./package.json").scripts||{};process.stdout.write(s["type-check"]?"type-check":(s.typecheck?"typecheck":(s.tsc?"tsc":"")))}catch(e){}' 2>/dev/null)"
    if [[ -z "$tc" ]]; then
      warn "build: no type-check script found in package.json"
    else
      for ((i = 0; i < COUNT; i++)); do
        git checkout -q "origin/${HEADS[$i]}" 2>/dev/null || continue
        if ! npm run --silent "$tc" >/dev/null 2>&1 && ! pnpm run --silent "$tc" >/dev/null 2>&1; then
          fail "build: #${NUMS[$i]} (${HEADS[$i]}) fails $tc on its own"
        fi
      done
      git checkout -q "$restore"
    fi
  fi
fi

# ── Summary ──────────────────────────────────────────────────────────────────
if [[ $ISSUES -eq 0 ]]; then
  echo "✓ ${COUNT} rungs, all structural checks pass"
  exit 0
fi
echo "${ISSUES} issue(s) found"
exit 1
