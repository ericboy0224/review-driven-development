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

## 4. Handoff

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
