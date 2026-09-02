---
name: sprint
description: Execute a finished plan to completion as fast as possible, subagent-driven — decompose the plan into file-disjoint work units, dispatch parallel implementer subagents in dependency-ordered waves, integrate and verify each wave, then run the review gate and closeout deliverables before anything is published. One hard stop, at closeout. Use when the user wants the goal done rather than pair-run — "儘速完成", "run the plan", "implement this plan", "/sprint CR-123", "subagent-driven implementation".
---

# Sprint — subagent-driven plan execution

The retired `pacer` skill made implementation the review medium: skeleton
first, a discussion checkpoint at every layer. That was the right trade when
plans were untrusted and the human review had nowhere else to live. With
`blueprint` moving the architecture and naming review to the plan stage, the
plan arriving here has already been reviewed by the user — re-reviewing it at
every layer costs wall-clock without adding safety. Sprint spends that time
on parallelism instead, and concentrates the human conversation into **one
hard stop at closeout**, where the review gate's findings and the drift from
the plan are discussed together.

Speed comes from parallel subagents and from not stopping — never from
skipping verification. The gate, the history re-cut, and the placeholder ban
are exactly what pacer's closeout enforced; they are the parts that survive.

Arguments: `[ticket-key | plan-path]`
- Ticket key (e.g. `CR-123`) — resolve via cs-jira convention:
  `docs/plans/<KEY>/plan.md` and `docs/specs/<KEY>/spec.md`.
- Explicit path to a plan file. Spec is optional but the review gate is
  weaker without it.

## 0. Intake and dispatch map

1. Resolve and Read the plan (and spec if present). No plan, no sprint —
   offer to produce one first.
2. Safety check: current branch is not `main`/`staging`; warn on uncommitted
   changes. Identify the repo root the plan targets.
3. **Resume check**: if the plan contains a `## Sprint Progress` section,
   report where the last run stopped (current wave, done waves, open drift)
   and continue from there — do not re-decompose.
4. Read what earlier stages left in the plan — both bind every subagent:
   - `## Blueprint Notes` — accepted architecture and naming decisions.
     Subagents implement them; the integration step verifies they held.
   - `## Review Plan` (written by split-pr) — adopt its commit list as the
     unit map instead of decomposing again.
5. Otherwise **decompose the plan into work units**: each unit is a set of
   files, the plan steps it covers, and its verify command. Then order the
   units into **waves** by dependency: a unit that imports another unit's
   exports goes in a later wave. Within one wave, units must be
   file-disjoint — a shared file means the units merge or one moves to a
   later wave. Keep a unit's expected diff under ~400 lines; split bigger
   ones.
6. Post the dispatch map (waves, units, files, plan-step coverage) as a
   status update and **start immediately** — the map is information, not a
   question. Stop for the user only if the plan is missing something no
   subagent can decide (a credential, a product choice the spec never made).
   Append the map to the plan under `## Sprint Dispatch` and initialize
   `## Sprint Progress`.

## 1. Waves

For each wave, spawn all of its implementer subagents **in one message** so
they run concurrently. Each subagent gets:

- the spec and the plan excerpt for its unit (never the whole backlog);
- the binding decisions: `## Blueprint Notes`, the scope wall, and the
  repo's own conventions (AGENTS.md / CLAUDE.md path — the subagent reads
  them itself);
- its file list, with the instruction that files outside it are read-only;
- the **completeness contract**: the unit comes back done — real logic,
  loading and error states, tests where the repo tests that layer. No
  placeholder bodies, no `TODO` markers, no mock returns. A subagent that
  cannot finish its unit reports *why* instead of stubbing over it.
- the **failure-visibility clause**, which the contract above does not
  imply: every `catch`, every fallback and every default that stands in for
  a failure must name what failed and say where that name is read. A default
  is only allowed to replace a failure when it either sets state the UI can
  show, or throws. An empty `catch`, a `?? ''`, a fallback that leaves the
  "it worked" flag set — each of those satisfies "handles errors" while
  making the failure unobservable, which is worse than the crash it replaced,
  because the crash was at least reported. When a unit degrades on purpose,
  the reason travels with the degraded value, not in a comment.

Each subagent runs the unit's own verify (typecheck scoped to its files,
its tests) before returning, and reports: files touched, decisions made,
and any deviation from the plan with its reason.

## 2. Integrate and verify (per wave)

1. Run the full verify for real — typecheck, lint, the test suite the repo
   defines. Fix seams between units yourself; a failure inside one unit goes
   back to a follow-up subagent with the failure output.
2. Judge the deviations subagents reported. Decide autonomously and record
   each in `## Drift Log` tagged `(auto)` — **except** a deviation that
   changes scope or user-visible behavior beyond the spec, which is a
   blocked-stop: park that unit, continue the rest, ask at closeout or
   immediately if everything depends on it.
3. Check `## Blueprint Notes` conformance: every accepted decision either
   survived into the code or has a Drift Log entry saying why not. Silent
   erosion of a decision the user already made is a defect, not drift.
4. Update `## Sprint Progress`; commit the wave as one or more Conventional
   Commits (`feat(<KEY>): <unit summary>`). These commits are checkpoints;
   the reading order is decided at closeout.

## 3. Readability gate — before the review gate, and before the first push

The gate below hunts defects. This one hunts what a maintainer will pay for
later: a concept that exists twice, a distinction too fine for anyone but its
author to hold, a layer that only moves a line somewhere else, a paragraph of
rationale the types already say. Correctness has three reviewers; economy and
naming have none, which is why they are the things that survive to the human.

Run it on the diff, not the plan. Blueprint asks similar questions one stage
earlier, where most of these do not exist yet: a plan says "a helper that
classifies failures", never `FailureToastCopy`, never `Record`-versus-`switch`.

Four checks. Each produces a deletion or a rename, not a finding to discuss.

**1. One concept, one name, one implementation.** Before any new exported
name, search the repo for what it duplicates by CONCEPT, not by the name you
picked — a new `attempt` may duplicate a Result type, a new `pollX` may
duplicate `waitForX`, a new size formatter may duplicate one three directories
away that differs only by its separator. Record what was searched: absence is
an assertion and has to be earned, never recalled.

The sharpest version of this is two names for one output. If two helpers
produce strings that differ by an invisible character, they are one helper and
one of them is a bug waiting for the day someone "fixes" the other.

**2. Do not split a concept finer than a consumer branches on.** The test is
one question: does some caller actually take a different path on the
difference? If every consumer treats two names the same, they are one name and
the split is vocabulary the reader has to learn for nothing.

The split earns its keep when a consumer does branch — a poll-stage transport
death and a poll-stage error status close the dialog alike but need different
copy, so they are two causes. That is the bar; below it, merge.

**3. Subtraction, with the burden inverted.** For every function, type,
constant, wrapper and barrel the branch ADDS, the default is delete. Write the
cost of deleting it — a caller that would re-render, a type that would stop
being checked, a duplication that would return — and if the written answer is
not concrete, delete it. Never write the case for keeping it: that case is
always available and always convincing to its author.

Distrust a one-line body in another file with a single consumer most, because
the hop is the entire cost and it buys nothing; worse, whatever tests it
attracts are usually a second, weaker copy of a table that already exists and
that will drift out of sync silently. A hop that removes real duplication is a
different thing and survives this check: say what it subtracts.

**4. Comment density, measured against the repo.** Compute it, do not judge
it: comment lines over total lines for the branch's non-test files, against
the same ratio across the repo. Prose that argues a design decision belongs in
the PR body or the ticket, where it is read once by the people deciding —
not carried by every future reader of that file. What stays is what the types
cannot say.

The gate's output is applied before the review gate runs, so those reviewers
spend their attention on defects rather than on volume.

## 4. Review gate — nothing goes to PR without it

Run these reviews against the finished branch, before the history is re-cut,
so fixes land as commits the curation can absorb. Every finding, from any of
them, must name a concrete failure scenario — inputs/state → wrong outcome —
or it does not count.

- **Lifecycle audit (one background subagent, spawned first).** Async
  lifetime is where the defects that reach production live, and they are
  found by enumeration, not by reading a diff for suspicious code. Hand it
  the branch diff, have it build one list per row below, then walk each list
  and answer the question:

  | Enumerate | Ask of each |
  | --- | --- |
  | every `AbortSignal`, and every place a controller is minted | who else is still using the signal this abort reaches? |
  | every effect whose work depends on a ref or a conditionally rendered node | does that node exist on the run this effect actually gets? |
  | every retry, re-entry, and second invocation of a handler | what does the second run overwrite that the first is still awaiting? |
  | every module-level object, array, or map a function returns | can a caller mutate it, and does the next caller inherit that? |
  | every `Promise.all` / `race` / fan-out | what happens to a member that settles after its owner is gone? |
  | every reduce, sort, or pick over a collection | what does it return when the collection is empty, and when every member is degenerate? |

- **Correctness review (a second background subagent, in parallel).** The
  spec, the plan with its Drift Log, and the branch diff. Its charter is the
  rest of the blind spots: acceptance criteria that do not actually hold,
  edge cases the spec never considered, interactions with work scoped out to
  sibling tickets, `(auto)` drift decisions whose consequences were never
  re-checked downstream, and a sweep of the failure-visibility clause — list
  every `catch`, `??`, `||`, and default in the diff, and say for each what
  the user sees when it fires.

- **fe-review (main context, via the Skill tool)** while the subagents run.
  Where fe-review is not installed, fall back to `/code-review`.

- **Exercise the feature in the running app**, via the `run` skill, along the
  route a reviewer would take. A diff cannot show a design-system component
  behaving unlike its own documentation, a control that renders but cannot be
  reached, or a popover that takes focus from the dialog around it — and
  those are the defects that survive to a reviewer, because the author had
  the feature open the whole time and never arrived at it cold. If the flow
  cannot be reached from the app's entry point at all, that is itself the
  finding: it triggers the demo obligation in §5.

Apply the fixes that are unambiguous, re-running verify after. Findings that
are judgment calls go to the closeout conversation.

## 5. Closeout — the one hard stop

1. `grep -rn "TODO("` over the branch diff — placeholders were banned at
   dispatch, so anything found is a defect to fix now, not to defer.
2. Run the full test suite.
3. **The closeout conversation.** Present, in the user's language: what was
   built (against the plan's goal), the Drift Log — every `(auto)` decision
   is theirs to overturn — the gate findings and what was already fixed, and
   the judgment calls that need their answer. This is the single hard stop;
   apply what they decide and record outcomes in the Drift Log.
4. **Re-cut the history for reading.** Hand off to `split-pr` §2: fold
   fix-up commits away and re-commit so each commit is complete,
   single-purpose, and carries its own tests, ordered bottom-up for reading.
   Prove the path with
   `${CLAUDE_PLUGIN_ROOT}/skills/validate-stack/scripts/validate-history.sh
   --base <trunk> --equals <pre-rewrite branch>` — every commit builds on
   its own, zero markers, head byte-identical to the pre-rewrite branch.
   Then decide: one PR with that history (usually), or a few complete PRs
   (`split-pr` §3).
5. **The demo obligation.** Count the steps from the app's entry point to
   the feature: launch, then every navigation, upload, or state change a
   reviewer must perform before the change is on screen. **More than three,
   or any step needing data the reviewer cannot produce, and `/demo-reel` is
   mandatory** — not the optional extra its own skill calls it. A reviewer
   who cannot reach the code judges it from the diff alone, and every defect
   that only appears on screen ships. Run it and link the clip at the top of
   the PR body.

   Reachable in three steps or fewer: no demo, and say so at closeout — the
   reading route in the PR body is enough.
6. **Author the PR description** to `docs/plans/<KEY>/pr-body.md` following
   split-pr §5: the goal in the user's terms, the reading route, the 2–3
   decisions the reviewer is asked to judge. The gate findings and their
   outcomes go in verbatim as the risk note; the verification claims state
   exactly what ran, nothing more.

   **Read the body and the diff together, sentence by sentence, before it is
   posted.** A behaviour described but not implemented, an example whose
   numbers the code cannot produce, a test count that moved since it was
   written — each reaches a reviewer as a lie you did not mean to tell, and
   each is free to catch. What the risk note carries is what the reviewer must
   judge; a question that belongs to another team, or an assumption already
   closed, is noise in the one section they read closely.

   **The reading route lives in the PR body, never in the diff.** Do not
   open inline threads on your own changes to explain them. An annotation
   sits where only a reader already in the right file will meet it, it
   competes with the reviewer's own threads for the same margin, and it goes
   stale as soon as the line moves. Everything such a note would say belongs
   in the body, where it is read once, before the diff.
7. **Feed the ledger.** Distill the Drift Log into at most 1–3
   *generalizable* planning lessons and update `~/.claude/plan-lessons.md`
   by its own protocol (merge before append, ×N counts, 30-entry cap). A
   drift that teaches nothing beyond this ticket adds no entry.
8. If in the cs-jira flow, hand back: `/cs-jira:execute-plan <KEY>` Phase 3
   handles PR creation and the Jira comment — with `pr-body.md` as the PR
   body, not a regenerated one.

## Rules

- **One hard stop.** The closeout conversation is the only planned wait for
  the user. Mid-flight stops exist only for genuine blockers: a scope or
  behavior decision the spec never made, or an integration failure the lead
  cannot resolve. "This wave is done" is a status line, never a question.
- **Speed never skips verification.** Full verify per wave, the readability
  gate, the review gate, the re-cut proof — all mandatory. What sprint removed
  is the waiting, not the checking.
- **The readability gate is answered in writing, not in your head.** Its four
  checks each produce an artefact: what was searched, which consumer branches,
  what deleting would cost, what the density is. An unwritten answer is the
  author agreeing with the author.
- **The completeness contract is absolute.** Every unit lands whole. A
  subagent that stubs is re-dispatched; a marker that reaches the gate is a
  defect. Sprint has no placeholder convention because it has no
  placeholders.
- Units are file-disjoint within a wave; dependencies are expressed as wave
  order, never as two agents editing one file.
- The plan file is a living document: dispatch map, progress, and every
  deviation go into it as they happen — never silently diverge.
- Speak the user's language in the closeout conversation (中文使用者就用中文
  討論); code, commits, and plan-file updates stay in English.

## Plan-file sections sprint owns

```markdown
## Sprint Dispatch
- wave 1: U1 media utils (src/utils/media/*) — covers steps 1,2
          U2 preview hook (src/hooks/usePreview.ts) — covers step 3
- wave 2: U3 editor container (src/components/pages/...) — covers steps 4,5 — needs U1,U2

## Sprint Progress
- current: wave 2 (U3 running)
- done: wave 1 (commits abc123, def456)

## Drift Log
- 2026-08-24 U2 (auto): plan assumed the list endpoint paginates; it does not — dropped the cursor param
- 2026-08-24 gate: correctness review found unmount race in usePreview — fixed (commit 789abc)
```
