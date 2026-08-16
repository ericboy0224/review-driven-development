---
name: pacer
description: Pair-run (陪跑) the implementation of a spec & plan — top-down, skeleton-first with placeholders, filling layers from outside in, with a discussion checkpoint at every layer boundary and all deviations written back into the plan. Use when the user wants to implement a plan interactively instead of one-shot execution — "陪我實作", "陪跑 CR-123", "/pacer", "implement this plan with me step by step", "骨架先行", or when they distrust a generated plan and want to validate it during implementation rather than on paper. Works with cs-jira convention (docs/specs/<KEY>/spec.md + docs/plans/<KEY>/plan.md) or explicit file paths. When the plan carries a ## Branch Plan (from split-pr), pacer implements it branch by branch as a gh stack.
---

# Pacer — implementation pair-running over a spec & plan

Generated specs and plans are cheap to produce but expensive to review on
paper — nobody has the patience to iterate a document until it's perfect, and
the real problems only become visible in code. This skill inverts the review:
**implementation is the review medium**. Build top-down — skeleton first, all
bodies as placeholders — then fill layers from the outside in. Every layer
boundary is a hard stop where you and the user check whether the plan's
approach still holds now that it can be seen in code, and every deviation is
written back into the plan so the document converges to reality instead of
rotting.

The deliverable is not just working code — it's a validated plan and a user
who understood and shaped every architectural decision at the moment it was
cheapest to change.

Arguments: `[ticket-key | plan-path]`
- Ticket key (e.g. `CR-123`) — resolve via cs-jira convention:
  `docs/plans/<KEY>/plan.md` and `docs/specs/<KEY>/spec.md`.
- Explicit path to a plan file. Spec is optional.
- Nothing — ask what to implement; a verbal plan discussed in-conversation is
  acceptable input (write it down as a minimal plan file first).

## 0. Intake

1. Resolve and Read the plan (and spec if present). If the plan is missing,
   offer: run `/cs-jira:action-plan <KEY>` first, or start from the spec /
   a verbal plan and let pacer's layering step *become* the plan.
2. Safety check: current branch is not `main`/`staging`; warn on uncommitted
   changes. Identify the repo root the plan targets.
3. **Resume check**: if the plan contains a `## Pacer Progress` section,
   report where the last session stopped (current layer, done layers, open
   drift items) and continue from there — do not re-layer.

## 1. Layering — re-slice the plan by depth, not by plan order

**If the plan contains a `## Branch Plan` section (written by split-pr), adopt
it as the layer map — do not re-slice.** Each rung B0..Bn is one layer *and*
one branch: B0 is the skeleton, each later rung fills one component (or one
extracted piece of complex logic). The architecture discussion already
happened in split-pr; confirm the Branch Plan is still current (no drift
since approval) and go straight to section 2, running **stack mode** (see the
layer loop). Placeholder tags use the rung id: `TODO(pacer:B<k>)`.

Otherwise, re-organize the plan's steps into layers yourself:

- **L0 — Skeleton**: file tree, exported types/interfaces, function and
  component signatures, routing/DI/module wiring. Everything compiles; every
  body is a placeholder. No logic.
- **L1 — Outermost behavior**: the surfaces callers/users touch — routes, API
  handlers, UI containers, CLI entry points — implemented against
  still-placeholder inner calls.
- **L2..Ln-1 — Inward**: services, state management, data access — one ring
  at a time.
- **Ln — Core**: innermost algorithms, edge cases, error paths.

For each layer record: which plan steps it covers, the files it touches, and
its **assumptions at risk** — the plan decisions this layer will prove or
break (e.g. "plan assumes the list endpoint returns paginated data — L1 will
confirm"). Layers with no risky assumption need no discussion later; say so.

Present the layer map to the user, discuss, and get approval. Then append it
to the plan file under `## Pacer Layers` and initialize `## Pacer Progress`.

## 2. Skeleton (L0 / B0)

1. In stack mode, start the stack first: `gh stack init --base <trunk>` (or
   `gh stack add` if a stack already exists), branch named per the Branch
   Plan. See the stacked-prs skill for the mechanics.
2. Implement the full skeleton: real files, real signatures, real wiring —
   placeholder bodies only. Placeholder convention (greppable, layer-tagged):
   ```ts
   // TODO(pacer:L2): fetch real data — returns realistic mock for now
   ```
   Bodies either `throw new Error("TODO(pacer:L<k>)")` or return **realistic
   mock data** — mocks keep outer layers runnable and demoable early.
3. It must typecheck/compile. Run the check for real.
4. Give the user a **skeleton tour**: file tree, key signatures, the data
   flow in one paragraph — then ask your 1–3 highest-leverage questions
   (module boundaries, naming, direction of data flow). This is the cheapest
   moment in the whole task to change architecture; say so explicitly. In
   stack mode the tour doubles as the B0 review: what the user approves here
   is what the reviewer of the skeleton PR will approve.
5. Iterate until the user approves. Commit: `chore(<KEY>): skeleton (pacer L0)`.

## 3. Layer loop (L1 → Ln / B1 → Bn)

For each layer, in order:

1. **Brief (before writing code)**: restate what the plan says for this
   layer, then — this is the 陪跑 moment — proactively flag anything that now
   looks questionable given what the previous layers revealed. Max 3 items.
   If the user wants to change approach, update the layer map first.
   In stack mode, open the layer's branch now: `gh stack add <branch-name>`.
2. **Implement this layer only.** Replace placeholders tagged for this layer;
   calls into deeper layers remain placeholders. Never implement deeper than
   the current layer, even when trivial — the discipline is the point.
3. **Verify**: typecheck + lint + any tests touching this layer. Demonstrate
   behavior when cheap (test output, curl, screenshot) — outer layers run
   against mock-returning inners by design.
4. **Checkpoint (hard stop)**: report outcome, diff stat, deviations from
   plan, and at most 3 open questions. Wait for the user. They may: continue
   inward, adjust this layer, or re-slice remaining layers. In stack mode,
   check the diff stat against the Branch Plan's estimate — a rung growing
   past 400 lines gets split (a new rung in the Branch Plan), never absorbed.
5. **Sync the plan**: record any deviation in `## Drift Log` in the plan file
   (what changed, why, date); update `## Pacer Progress`. Commit:
   `feat(<KEY>): <layer summary> (pacer L<k>)`.

## 4. Closeout

1. `grep -rn "TODO(pacer:"` — must be zero, or each remaining marker is
   explicitly listed as deferred with the user's sign-off.
2. Run the full test suite.
3. Summarize the Drift Log — this is the honest changelog of where the plan
   was wrong and what was decided instead.
4. In stack mode: `gh stack submit` opens the whole ladder as draft PRs —
   let the user decide when each rung goes ready-for-review. Each PR
   description states the rung's single purpose and which placeholders it
   fills (split-pr's "PR descriptions" section is the format). The
   stacked-prs skill covers rebase/link/merge from here. Before the rungs go
   ready-for-review, offer `/pr-deck <KEY>` — the guided-reading deck that
   orients reviewers across the whole ladder.
5. If in the cs-jira flow, hand back: `/cs-jira:execute-plan <KEY>` Phase 3
   handles PR creation and the Jira comment (skip PR creation in stack mode —
   the stack already opened them).

## Rules

- Every checkpoint is a real stop. The anti-pattern this skill exists to
  fight is one-shot generation — never batch layers to "save the user time".
- **≤3 questions per checkpoint**, highest-leverage only. The original pain
  is that users have no patience for document review; a laundry list of
  questions recreates that pain in a new place.
- Keep a layer's diff under ~300 lines; if it grows past that, split the
  layer and checkpoint early.
- The plan file is a living document: deviations go in the Drift Log the
  moment they're decided — never silently diverge from the written plan.
- Placeholder markers are the single source of "what's left":
  `TODO(pacer:L<k>)` (or `B<k>` in stack mode), always greppable, always
  layer-tagged.
- Speak the user's language at checkpoints (中文使用者就用中文討論)；code,
  commits, and plan-file updates stay in English.

## Plan-file sections pacer owns

```markdown
## Pacer Layers
- L0 skeleton: <files> — covers plan steps 1,2
- L1 <name>: <files> — covers step 3 — at risk: <assumption>
...

## Pacer Progress
- current: L2
- done: L0 (commit abc123), L1 (commit def456)

## Drift Log
- 2026-08-14 L1: plan assumed X; actually Y — decided Z (user confirmed)
```

(In stack mode the Branch Plan replaces `## Pacer Layers`; Progress and Drift
Log work the same, keyed by rung id.)
