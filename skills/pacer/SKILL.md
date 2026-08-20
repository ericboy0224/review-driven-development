---
name: pacer
description: Pair-run (陪跑) the implementation of a spec & plan — top-down, skeleton-first with placeholders, filling layers from outside in, with a discussion checkpoint at every layer boundary and all deviations written back into the plan. Use when the user wants to implement a plan interactively instead of one-shot execution — "陪我實作", "陪跑 CR-123", "/pacer", "implement this plan with me step by step", "骨架先行", or when they distrust a generated plan and want to validate it during implementation rather than on paper. Works with cs-jira convention (docs/specs/<KEY>/spec.md + docs/plans/<KEY>/plan.md) or explicit file paths. Skeleton-first is how the work is built, never how it is published — placeholders are gone before anything is opened for review.
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

**Skeleton-first is a build method, not a publishing method.** The placeholders
exist so you and the user can walk the architecture before it is expensive; they
are scaffolding for the two of you, not artifacts for a reviewer. By the time
anything is opened for review, every marker is gone and the history has been
curated into a narrative that reads bottom-up (see `split-pr` §2). A reviewer
who meets a placeholder has to go looking for the PR that removes it, and that
lookup costs more than the smaller diff ever saved.

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

**If the plan contains a `## Review Plan` section (written by split-pr), adopt
its commit list as the layer map — do not re-slice.** The architecture
discussion already happened there; confirm the plan is still current (no drift
since approval) and go straight to section 2. Note that the Review Plan is
ordered for *reading* — bottom-up, leaves first — while the layer loop below
builds top-down. Both orders are fine and they are reconciled at closeout, when
the history is re-cut into reading order.

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

## 2. Skeleton (L0)

1. Work on one branch. Do not open a PR yet, and do not start a stack — the
   publishing shape is decided at closeout, once the whole thing exists and its
   real seams are visible.
2. Implement the full skeleton: real files, real signatures, real wiring —
   placeholder bodies only. Placeholder convention (greppable, layer-tagged):
   ```ts
   // TODO(pacer:L2): fetch real data — returns realistic mock for now
   ```
   Bodies either `throw new Error("TODO(pacer:L<k>)")` or return **realistic
   mock data** — mocks keep outer layers runnable and demoable early.
3. It must typecheck/compile. Run the check for real.
4. **Pattern pre-check (React/TS repos; parallel subagents).** The skeleton is
   all signatures and seams — exactly what pattern guidance can judge before
   any body exists, and the cheapest moment to act on what it finds. Spawn two
   background subagents in one message while you prepare the tour; never load
   these skills into the main context (they are long reference documents and
   the findings are all you need):
   - one loads the `vercel-composition-patterns` skill (via the Skill tool)
     and audits the skeleton's component APIs against it — boolean-prop
     proliferation, missed compound-component or context seams, prop-drilling
     the layer map will bake in;
   - one loads the `vercel-react-best-practices` skill and audits the wiring —
     data-fetching placement, waterfall risks, state placed a layer too high,
     bundle/memoization hazards visible from the structure alone.
   Each subagent gets the layer map plus the skeleton diff and returns at most
   5 prioritized findings (`file:symbol` — what breaks the pattern — the
   change while it is still a signature edit). Skip this step, and say so,
   when the repo is not React or the skills are unavailable.
5. Give the user a **skeleton tour**: file tree, key signatures, the data
   flow in one paragraph — then ask your 1–3 highest-leverage questions
   (module boundaries, naming, direction of data flow). Fold pattern findings
   you agree with into those questions; they compete for the same ≤3 slots
   rather than adding a second list. This is the cheapest moment in the whole
   task to change architecture; say so explicitly. The tour is the user's
   review of the architecture — it replaces showing a skeleton to anyone else.
6. Append the surviving pattern findings to the plan under
   `## Pacer Pattern Watchlist`, each tagged with the layer whose brief must
   answer it (`L2: RightPanel props — decide compound vs flags`). A finding
   the user rejects is dropped, not carried.
7. Iterate until the user approves. Commit: `chore(<KEY>): skeleton (pacer L0)`.
   This commit is scaffolding and will be folded away at closeout; keep it as a
   checkpoint, not as something a reviewer will ever see.

## 3. Layer loop (L1 → Ln)

For each layer, in order:

1. **Brief (before writing code)**: restate what the plan says for this
   layer, then — this is the 陪跑 moment — proactively flag anything that now
   looks questionable given what the previous layers revealed, including any
   `## Pacer Pattern Watchlist` item tagged for this layer. Max 3 items.
   If the user wants to change approach, update the layer map first.
2. **Implement this layer only.** Replace placeholders tagged for this layer;
   calls into deeper layers remain placeholders. Never implement deeper than
   the current layer, even when trivial — the discipline is the point.
3. **Verify**: typecheck + lint + any tests touching this layer. Demonstrate
   behavior when cheap (test output, curl, screenshot) — outer layers run
   against mock-returning inners by design.
4. **Checkpoint (hard stop)**: report outcome, diff stat, deviations from
   plan, and at most 3 open questions. Wait for the user. They may: continue
   inward, adjust this layer, or re-slice remaining layers. A layer that has
   grown far past its estimate is a signal the plan mis-scoped it — say so and
   let the user decide, rather than splitting on the number alone.
5. **Sync the plan**: record any deviation in `## Drift Log` in the plan file
   (what changed, why, date); update `## Pacer Progress`. Commit:
   `feat(<KEY>): <layer summary> (pacer L<k>)`.

## 4. Closeout

1. `grep -rn "TODO(pacer:"` — must be zero, or each remaining marker is
   explicitly listed as deferred with the user's sign-off.
2. Run the full test suite.
3. **Review gate — nothing goes to PR without it.** Run the two reviews
   against the finished branch, before the history is re-cut, so their fixes
   land as commits the curation can absorb:
   - **Correctness review (one background subagent, spawned first).** Hand it
     the spec, the plan with its Drift Log, and the full branch diff. Its
     charter is the blind spots, not the style: acceptance criteria that do
     not actually hold, edge cases the spec never considered (empty/degenerate
     inputs, races between async flows, lifecycle/unmount timing, interactions
     with work scoped out to sibling tickets), and Drift Log decisions whose
     consequences were never re-checked downstream. Every finding must name a
     concrete failure scenario — inputs/state → wrong outcome — or it does not
     count.
   - **fe-review (main context, via the Skill tool)** while the subagent runs.
     It drives its own toolchain and reviewer panel and ends in a
     discuss-before-fix conversation, which is why it cannot be delegated to a
     subagent. Where fe-review is not installed, fall back to `/code-review`.
   Merge the two findings lists, dedupe, and discuss them with the user in
   fe-review's discuss-before-fix step. Apply the agreed fixes, re-run
   typecheck/lint/tests, and record each finding's outcome (fixed / rejected,
   with why) in the Drift Log. Skipping the gate requires the user's explicit
   sign-off, recorded the same way.
4. Summarize the Drift Log — this is the honest changelog of where the plan
   was wrong and what was decided instead.
5. **Re-cut the history for reading.** The build order was top-down; the
   reading order is bottom-up. Hand off to `split-pr` §2: fold the skeleton
   commit into the layers that completed it, drop every fixup, and re-commit so
   each commit is complete, single-purpose, and carries its own tests. Prove
   equivalence — the tree after the rewrite must be identical to the tree
   before it. Only then decide whether one PR with that history is enough, or
   whether it needs splitting into a small number of complete PRs (`split-pr`
   §3). Never publish the layer commits as-is.
6. If in the cs-jira flow, hand back: `/cs-jira:execute-plan <KEY>` Phase 3
   handles PR creation and the Jira comment.

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
- Placeholder markers are the single source of "what's left": `TODO(pacer:L<k>)`,
  always greppable, always layer-tagged — and always gone before anything is
  published. A marker that reaches a reviewer is a bug in the process.
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

## Pacer Pattern Watchlist
- L2: RightPanel props — decide compound vs boolean flags (composition-patterns)

## Drift Log
- 2026-08-14 L1: plan assumed X; actually Y — decided Z (user confirmed)
- 2026-08-15 gate: correctness review found unmount race in useFoo — fixed (commit 789abc)
```

(When split-pr wrote a `## Review Plan`, it replaces `## Pacer Layers`;
Progress and Drift Log work the same.)
