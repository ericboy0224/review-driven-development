---
name: split-pr
description: Split a task or an oversized branch into a ladder of single-purpose, review-sized branches — skeleton first, then component by component, complex logic extracted into its own branch. Use right after a spec & plan are generated ("plan 好了，來拆 branch", "/split-pr CR-123", "開工前先拆"), when a PR or branch has grown past review size ("PR 太大", "這筆 947 行怎麼辦", "幫我拆成 stack"), or before starting any feature big enough that one PR would exceed ~400 lines. Produces a Branch Plan for pacer to implement and a stack for stacked-prs to manage. Always plans and discusses first — never touches a branch before the user approves.
---

# split-pr — cut work into review-sized, single-purpose branches

A reviewer's attention is the scarcest resource in the pipeline. Under ~100
changed lines they can hold the whole diff in their head and give precise
feedback in minutes; a self-contained change tops out around 200–400 lines;
past 400 the review degrades into a skim and an LGTM. This skill spends
planning effort to keep every branch inside those bands — and to give each
branch **exactly one purpose**, so its PR title alone tells the reviewer what
to check.

Two modes, one algorithm:

- **Mode A — plan-time split** (the normal path): a spec & plan exist, no code
  yet. Discuss the architecture, then cut the future work into a branch
  ladder before the first line is written.
- **Mode B — retro split**: a branch/PR already exists and is too big.
  Re-derive the structure from the finished code and synthesize the ladder
  after the fact.

**Hard rule for both modes: present the plan, discuss, and get an explicit
"OK" from the user before creating, moving, or linking any branch.** The
deliverable of this skill is an approved plan; execution belongs to pacer
(Mode A) or to a user-approved gh-stack run (Mode B).

Arguments: `[ticket-key | plan-path | branch/PR]`
- Ticket key (e.g. `CR-123`) — resolve `docs/plans/<KEY>/plan.md` and
  `docs/specs/<KEY>/spec.md` (cs-jira convention), or explicit file paths.
- A branch name, PR number, or PR URL — Mode B.
- Nothing — ask which; if the current branch is far ahead of its base,
  suggest Mode B on it.

## 0. Intake

1. Mode A: Read the plan (and spec if present). Mode B: get the real diff —
   `gh pr view` for base/size, `git diff <base>...<head> --stat` for the file
   list, then read the changed files.
2. Identify the trunk the ladder will land on (repo default branch or an
   integration/feature branch). Note the repo's branch-naming convention from
   recent branches — the ladder must follow it.
3. Check `gh stack` is available (`gh extension list`); if not, note it in
   the plan — the stacked-prs skill covers installation.

## 1. Architecture discussion — before any splitting

Do not open with a branch list. Branch boundaries fall out of component
boundaries, and component boundaries are a design decision the user must own.

1. Restate the **business goal** in one or two sentences: what the user of
   the product gets, per the spec's own words. Confirm it.
2. Propose a **component architecture sketch**: the component/module tree
   from the outermost surface (route, page, dialog, CLI entry) down to leaf
   utilities — names, one-line responsibilities, who renders/imports whom,
   and where state lives. Ground it in the plan's steps and the repo's
   existing patterns; flag where the plan is silent or ambiguous.
3. Discuss until the tree is agreed. This is the same "cheapest moment to
   change architecture" that pacer's skeleton tour exploits — here it comes
   even earlier, before the skeleton exists. Ask at most 3 highest-leverage
   questions per round (module boundaries, state ownership, data flow
   direction).

Only an agreed component tree proceeds to step 2.

## 2. Cut the ladder — skeleton first, then top-down recursion

Walk the agreed tree and assign work to branches:

1. **B0 is always the skeleton**: every planned file exists with real
   exported types, real signatures, real wiring (routing, DI, context
   providers, imports) — and placeholder bodies only, tagged
   `TODO(pacer:B<k>)` for the branch that will fill them. B0 must typecheck.
   B0 is the review of the *architecture itself*: a reviewer approving B0 is
   approving the component tree.
2. **Recurse top-down**: from the outermost component inward, each tree node
   gets a branch that fills that node's real body while calls into deeper
   nodes stay placeholders. Never fill deeper than the current node.
3. **Complex-logic extraction**: entering a node, judge whether it contains
   complex logic — an algorithm, a state machine, heavy edge-case handling,
   tricky async orchestration. If so, the node's branch fills only the plain
   structure (layout, prop plumbing, straightforward handlers) and leaves the
   complex part as a placeholder; a dedicated branch directly below it fills
   the complex logic alone. A reviewer of that branch reviews *only* the
   hard part, with the structure already approved around it.
4. **Size bands**: aim under 100 changed lines per branch; hard ceiling 400.
   A node whose fill would exceed the ceiling is split along its internal
   seams (state vs. actions vs. render; parse vs. transform vs. emit) and
   recursed. A leaf utility may ride along with its only consumer if the
   pair stays under ~200 lines; otherwise it gets its own branch.
5. **Single purpose test**: every branch must be describable in one sentence
   with no "and". If the sentence needs an "and", split again.
6. **A function belongs to its caller's rung**, not to its file region's:
   a helper cut away from its only caller leaves an unused symbol behind and
   breaks the rung's typecheck (`noUnusedLocals`). Move `settle()`-like
   helpers with the rung that first calls them, even when the plan filed
   them under "state".
7. **Estimate the skeleton at ~1/3 of the total diff.** Contracts, wiring
   and realistic mocks are thicker than they look (field data: a 947-line PR
   produced a 376-line B0; total placeholder overhead across the ladder ran
   ~7%). Realistic mocks are part of B0's job — an `open()` that seats
   believable state keeps every outer rung runnable and demoable.
8. **Fold a rung that cannot be judged alone.** Splitting has a floor as
   well as a ceiling. Apply both tests to every candidate rung:
   - **Does it change behavior the day it lands?** A rung whose diff
     computes the same values as the rung below it (because the code that
     would exercise it is still a placeholder) is inert — it reads as a
     no-op to whoever reviews it.
   - **Can a reviewer judge it without the next rung's context?** If
     answering its review question means imagining states that only arrive
     later, cause and effect have been split across two PRs.

   Inert **and** unjudgeable → fold it into the rung that gives it meaning,
   even when the merged result is larger. Size is not the test: a 47-line
   rung that isolates a real hazard (an element lifecycle, a retry path) is
   an excellent rung, while an 11-line rung whose value depends entirely on
   the next one is a section of that next one. Prefer folding downstream
   (into the rung that drives it), so the merged PR reads as flow → the
   readings that flow produces.

## 3. Write the Branch Plan and stop

Append to the plan file (Mode A) or write a standalone plan file (Mode B):

```markdown
## Branch Plan
- trunk: <branch the ladder lands on>
- B0 <name>: skeleton — <files> — est ~<n> lines
- B1 <name>: <single-purpose sentence> — <files> — est ~<n>
- B2 <name>: <sentence> — <files> — est ~<n> — extracted from B1 (complex logic: <what>)
...
- open questions: <anything the discussion left undecided>
```

Branch names follow the repo's convention (usually `<KEY>-<slug>`). Present
the ladder with per-branch estimates and **wait for the user's OK**. They may
merge rungs, re-order, or push a boundary — update the plan, not the
conversation memory.

## 4. PR descriptions

Each rung's PR is written in the repo's own description style — read the
repo's recent substantial PRs and follow their pattern, not a generic
template.

**Every PR in the stack carries the orientation itself**, in two fixed
blocks, because a reviewer lands on whichever rung they were assigned and
must not have to hunt for context:

- **`## The stack`** — identical text in all of them: the feature's goal in
  the user's terms, how the ladder is cut and why (skeleton first, hard
  parts extracted), and the rung table with PR links and sizes. Generate it
  once and inject it into each body so the copies cannot drift.
- **`## This rung — B<k>, <name>`** — what this PR alone is responsible
  for, its review question, what stays placeholder, and the ACs it carries.

This is deliberately enough on its own: a guided-reading deck (`pr-deck`) is
an addition for wide or cross-functional audiences, never the thing that
makes the stack reviewable. Treat the deck as optional and the descriptions
as mandatory.

On top of the repo's pattern, a stacked PR states:

- **Stack position and single purpose in the first paragraph** ("Rung B4 of
  the stack rooted at #NNN. One purpose: …").
- **The review-focus question** — the one thing this rung asks the reviewer
  to judge. Small PRs earn this sentence; a 947-line PR never could.
- **What stays placeholder and which rung fills it** — honest
  `TODO(pacer:B<k>)` accounting, so a reviewer never mistakes scaffolding
  for a bug.
- **The maps live once, at the bottom**: the stack table and the
  AC-to-rung table go in B0's PR ("listed so the split is explicit rather
  than implied"); later rungs carry only their own AC lines and link back.
- **Verification claims match what ran**: per-rung typecheck/lint, full
  tests at the top; a retro split states the equivalence proof (top-of-stack
  diff vs. the reference branch is empty), which is what transfers the
  original PR's end-to-end verification to the stack.

## Folding a rung after the ladder is already open

Rungs get folded mid-flight — the floor test (§2.8) usually fails only once
the rung exists and reads as a no-op. The mechanics, in order:

1. **Placeholder markers first.** If the folded rung's tag appears in a
   lower rung (`TODO(pacer:B3)` sitting in B0), fix it there before
   anything else — a marker pointing at a rung that no longer exists is the
   rot this convention exists to prevent. That amendment cascades, so
   rebase the whole ladder from that point up.
2. **Squash, don't replay.** The upper rung's commit was computed against
   the folded one; replaying it alone silently drops the folded work.
   `git reset --soft <rung below>` then re-commit is the safe shape.
3. **Renumber, unless someone is already reviewing.** A gap (B0, B1, B2,
   B4, B5) is internally consistent but reads as a mistake to everyone who
   sees it — the first question is always "where did B3 go?". While the
   stack is still draft, close the gap: renumber the rungs above the fold,
   `sed` the `TODO(pacer:B<k>)` markers in the rungs below, and re-title the
   PRs. Once review has started, the churn costs more than the gap does and
   the labels stay put.
4. **Unstack before retargeting.** GitHub refuses a base change on a linked
   stack member (`Cannot change the base branch because the pull request is
   part of a stack`). Order: `gh stack unstack <n>` → `gh pr edit --base` →
   close the folded PR with `--delete-branch` → `gh stack link` the
   survivors.
5. **Say why on the closed PR**, in its own comment: what made the rung
   inert, and which PR now carries it. A silently closed PR reads as
   abandoned work.
6. **Re-verify by hand.** A fold changes what each rung sees beneath it, and
   its rebases resolve conflicts manually, so re-run the equivalence proof
   (retro splits) and typecheck every rung. The cheapest structural check is
   the marker census — list `TODO(pacer:B<k>)` per rung and confirm it
   decreases monotonically, each rung consuming exactly its own tag and the
   top having none.
7. **Regenerate every downstream artifact in the same pass** — the stack
   table repeated in each PR body, and any deck pages or "slide N covers
   this rung" pointers. A fold that updates the code but not the tables
   leaves the stack contradicting itself.
8. **Close with `/validate-stack`** (`--full --equals <reference>` after a
   retro-split fold). Steps 1–7 are exactly the checks it automates; running
   it is how you find the one you forgot.

Two mechanics that will bite during the rebases:

- **In a git worktree, `.git` is a file, not a directory.** `test -d
  .git/rebase-merge` silently reports "no rebase in progress" while one is
  very much in progress. Use `git rev-parse --git-path rebase-merge`.
- **Pick the rebase boundary as the commit, not the branch.** `--onto <new
  base> <old branch>` re-applies commits that are already upstream and
  conflicts against them; `--onto <new base> <that rung's commit>^` replays
  only the rung's own work.

## 5. Handoff

- **Mode A**: on approval the skill is done. Point the user at
  `/pacer <KEY>` — pacer detects `## Branch Plan` and implements the ladder
  branch by branch, running `gh stack` as it goes (see pacer's own doc).
- **Mode B**: on approval, execute the synthesis (next section), then hand
  the stack to stacked-prs conventions for submit/link.

## Mode B specifics — synthesizing a ladder from finished code

The finished branch's history is usually review-driven, not layer-driven, so
cherry-picking commits into groups produces ugly intermediate states. Instead
**re-derive**: treat the final code as the target, and build each rung as a
checkout of the final content *reduced to that rung's scope* — outer rungs
carry the final files with deeper bodies replaced by placeholders.

- Every rung must typecheck (and lint/test where the repo defines it) — run
  the checks for real on each rung before stacking the next.
- The original branch is never deleted or rewritten; it stays as the
  reference until the whole stack has replaced it and the user says so.
- Say plainly in each PR description that the state is synthesized for
  review, which parts are placeholders, and which rung fills them.
- Existing review threads on the original PR do not transfer. Confirm the
  user accepts orphaning them **before** executing — this is part of the
  plan approval, not an execution-time surprise.

## Rules

- No branch mutation before explicit user approval of the Branch Plan.
- One purpose per branch; the one-sentence-no-"and" test is the gate.
- <100 lines ideal, 400 hard ceiling, split along internal seams when over.
- Skeleton (B0) always exists and always compiles — it is the architecture
  review.
- Complex logic never hides inside a structure branch — extract it.
- Speak the user's language in discussion (中文使用者就用中文討論); the plan
  file, branch names, and PR text stay in English.
