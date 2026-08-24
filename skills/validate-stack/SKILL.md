---
name: validate-stack
description: Check that a stacked-PR ladder is still structurally sound — base chain, stack membership, per-rung build, placeholder-marker census, rung sizes, equivalence with a reference branch, and the stack tables repeated across PR bodies. Use before flipping a stack from draft to ready, after any fold / rebase / trunk move / merge of a lower rung, when picking up someone else's stack, or whenever the user asks to "check the stack", "驗證 stack", "/validate-stack". Reports anomalies only; it does not review code — send that to a code-review skill.
---

# validate-stack — is this ladder still sound?

A stack breaks quietly. Base chains, stack links, placeholder markers and the
tables repeated across PR bodies all fail **without an error message**: the
diffs still render, CI still passes, and the damage only surfaces when a
reviewer is already confused. This skill is the mechanical sweep that catches
those, so the human attention goes to the code instead.

Its value peaks when a stack **changes after it exists** — a folded rung, a
rebase whose conflicts were resolved by hand, a trunk that moved, a lower rung
that merged. On a freshly-created ladder most checks are trivially green; on a
reworked one they are the only thing standing between a hand-resolved conflict
and a silently wrong branch.

**Boundary**: this skill judges the ladder, never the code. Whether the change
is correct, idiomatic, or well-named belongs to a code-review skill; do not
duplicate that here.

Arguments: `[pr-number | branch]` — defaults to the current branch's PR.

## 1. Run the mechanical checks

```bash
${CLAUDE_PLUGIN_ROOT}/skills/validate-stack/scripts/validate-stack.sh \
  --pr <top rung> --trunk <branch the bottom rung lands on> \
  [--equals <reference branch>] [--full]
```

- **`--trunk` is effectively required.** The walk follows base refs downward
  and does not stop on its own — if the trunk itself has an open PR (an
  integration or `[DO NOT MERGE]` branch), the ladder silently grows to
  include rungs that are not yours, and every size and marker check reports
  on them.
- **`--equals <ref>`** turns on the equivalence proof for a retro split: the
  top of the stack must be byte-identical to the branch it replaced. Run it
  after *every* rebase — it is the only thing that proves a hand-resolved
  conflict was resolved correctly.
- **`--full`** adds a per-rung typecheck (each rung checked out and built on
  its own). Budget ~15s per rung; skip it when only PR text changed, always
  run it after a rebase.
- **`--marker-prefix`** defaults to `TODO(pacer:`, the retired pacer skill's
  scaffolding marker (sprint bans placeholders outright, so any hit is a
  defect). Pass the project's own marker if it differs.

What it checks: base chain continuity, stack membership, the marker census,
PR bodies linking closed PRs, equivalence, per-rung build.

**The marker census must be zero on every rung, not merely decreasing.** A
published PR never carries a placeholder, mock value, or TODO that a later PR
removes (see split-pr's completeness rule) — any marker anywhere in the stack
is an anomaly, not a bookkeeping entry. Rung sizes are reported for information
only; there is no band to fail against, because readability decides boundaries
and line count is a symptom.

It prints anomalies only and exits non-zero when it found any. A clean run is
one line — resist the urge to expand it into a checklist of green ticks, or
people stop reading the output.

### Curated single-PR history — `validate-history.sh`

The plugin's preferred outcome is not a stack but one PR with a curated,
commit-by-commit-readable history — and that promise fails silently too: the
equivalence proof guarantees the **end** of a rewrite, not the **path**. One
mid-history commit that references a symbol the next commit introduces still
diffs clean at the top, and quietly destroys both the guided reading and
`git bisect`.

```bash
${CLAUDE_PLUGIN_ROOT}/skills/validate-stack/scripts/validate-history.sh \
  --base <what the branch lands on> [--head <ref>] \
  [--check '<cmd>'] [--equals <pre-rewrite branch>]
```

- Checks that **every commit in `base..head` builds on its own** (default: the
  repo's type-check script; pass `--check 'pnpm type-check && pnpm test'` when
  the tests are cheap enough to pay per commit), that the **marker census is
  zero at every commit** (published history never carries a placeholder), and
  `--equals` proves byte-identity with the branch the rewrite replaced.
- Run it after **every** history re-cut (sprint closeout, split-pr §2) — it is
  the check that makes "each commit is complete" a verified claim instead of a
  stated one.
- It checks out each commit in place (reusing `node_modules`); it needs a
  clean tracked tree and restores your starting point. If the lockfile changes
  inside the range, reinstall and re-run before trusting a failure.

### Known limits — do not report these as failures

- `gh stack view` reads **local branch tracking**, not the PR. A stack created
  with `gh stack link` is invisible to it, so membership comes back
  "unverifiable". Confirm the ⧉ badge on the bottom PR in the browser instead.
- The script sees `origin/*`, so push before validating or you are checking
  yesterday's stack.

## 2. Judgment checks (yours, not the script's)

Report these separately from the mechanical results, and label them as
judgment — they are opinions, and presenting them as findings of fact is how a
validator loses credibility.

- **Single purpose, actually.** Read each rung's stated purpose, then its
  diff. The failure this catches is a rung whose sentence says one thing while
  the diff quietly does two — the sentence passes the no-"and" test only
  because the second thing went unmentioned.
- **The standalone test** (see split-pr §3): could a reviewer judge this rung
  without opening another PR in the stack? A rung that is behaviorally inert
  the day it lands, or whose review question can only be answered by reading
  the rung above it, should be folded. Propose the fold; do not perform it.
- **Is the stack earning its coordination cost?** Count the rungs against what
  the ticket delivers. Many small rungs read fast individually and still cost
  more in total, because the reviewer carries the whole ladder to judge any one
  of them. If curating the commit history into one PR would serve the reader
  better, say so — that is a legitimate finding.
- **Table freshness.** The `## The stack` block repeated across the bodies
  lists exactly the live rungs, with sizes matching the script's numbers.

## 3. Report

Lead with the verdict — sound, or N anomalies. Then the anomalies, each with
the specific fix. Then judgment items, clearly marked as such. Nothing else:
a validation report that restates what passed trains people to skip it.

If anomalies exist, stop there and let the user decide. Fixing a chain,
re-linking a stack, or folding a rung all rewrite branches; that is split-pr's
and stacked-prs' territory, and it needs the user's go-ahead.
