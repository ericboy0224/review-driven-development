---
name: blueprint
description: Optimize a finished plan before any code exists — audit the planned client-side architecture (layer separation, state placement, state shape, component composition) with the vercel-composition-patterns and vercel-react-best-practices skills, rewrite proposed names and plan prose with simple-english, refuse every change outside the ticket's scope, then publish a visual artifact (component composition + data flow, in English) the user can actually read. Use after plan.md is complete and before /sprint — "optimize the plan", "review the plan architecture", "visualize the plan", "/blueprint CR-123".
---

# Blueprint — plan-stage architecture and readability pass

Once `/sprint` starts, implementation runs to completion without mid-flight
checkpoints — which makes this skill the last cheap moment to change the
architecture, and the main place the user's judgment enters the flow. A plan
declares components, hooks, state, and data flow in prose; layer separation,
state placement, and composition seams are all judgeable from that prose
plus the existing code the plan touches — and a finding here costs a
sentence edit instead of a re-dispatched subagent.

The second problem this skill solves is that plans are walls of text. A plan
the user can *see* gets reviewed; a plan they must parse gets skimmed and
LGTM'd — the same failure this plugin fights in PRs, one stage earlier. The
deliverable is therefore twofold: an optimized plan file, and a visual
artifact of the component composition and data flow, written in English.

Arguments: `[ticket-key | plan-path]`
- Ticket key (e.g. `CR-123`) — resolve via cs-jira convention:
  `docs/plans/<KEY>/plan.md` and `docs/specs/<KEY>/spec.md`.
- Explicit path to a plan file. Spec is optional but sharpens the scope wall.

## 0. Intake and the scope wall

1. Resolve and Read the plan (and spec if present). No plan, no blueprint —
   offer to run the plan-producing flow first instead of inventing one here.
2. Read `~/.claude/plan-lessons.md` if it exists. A lesson that touches this
   plan is raised in the discussion step (§3) alongside the audit findings.
3. **Build the scope wall.** From the spec and plan, list what is in scope:
   the files the plan touches, the components/hooks/functions it creates or
   changes, and the flows it alters. Everything else is out of scope. This
   list gates every later step: a finding, rename, or "improvement" that
   lands outside the wall is discarded before the user ever sees it — this
   skill optimizes the plan, never the codebase around it.

## 1. Architecture audit (parallel subagents)

Spawn six background subagents in one message; never load the pattern
skills into the main context (they are long reference documents and the
findings are all you need). Each subagent gets the spec, the plan, the scope
wall from §0, and read access to the repo; each returns at most 5 prioritized
findings, and every finding must name the plan step it targets and the
concrete cost of leaving it (`plan step — what breaks the pattern — the
one-line plan edit that fixes it`). A finding that requires touching
out-of-scope code is discarded, not reported.

- **Composition** — loads the `vercel-composition-patterns` skill (via the
  Skill tool) and audits the component APIs the plan proposes: boolean-prop
  proliferation, missed compound-component or context seams, prop drilling
  the plan is about to bake in.
- **React practices** — loads the `vercel-react-best-practices` skill and
  audits the planned wiring: data-fetching placement, waterfall risks, state
  planned a layer too high, bundle and memoization hazards visible from the
  plan's structure alone.
- **Client-side layering** — reads
  `${CLAUDE_PLUGIN_ROOT}/skills/blueprint/references/client-side-architecture.md`
  and audits the plan against it: does each planned piece sit in one layer,
  is every piece of state typed (local / remote / shared) and homed
  accordingly, do presentational components stay free of business and
  fetching logic.
- **State shape** — reads §3 of the same reference and asks one question of
  every piece of state the plan introduces: can the proposed type represent a
  combination that must never exist? A `status` (or `phase`, `kind`, `step`)
  field beside fields that are nullable only in some of those states is the
  signature, and the finding is the discriminated union that replaces it,
  written into the plan text. This audit is the cheapest one in the skill: the
  same change is one sentence here, and a type reshape plus a review round
  once the code exists.
- **Prior art** — audits what the plan proposes to *build* against what the
  repo, its workspace, its dependencies, its design system and the language
  itself already ship. Take every new file, type, helper, constant and UI
  element in the plan, and for each one search these registries in order:

  1. the repo's own utility, type and constant directories (`src/utils`,
     `src/typings`, `src/constants` or whatever this repo calls them);
  2. the workspace's shared packages — the exports of every `libs/*` or
     equivalent the repo already depends on;
  3. `package.json` — a dependency already installed for something else;
  4. the design system's component directory, then the repo's own shared
     component directory;
  5. the platform — for anything the plan describes as grouping, waiting,
     decoding, aborting, comparing or aggregating, name the built-in that
     does it before writing one.

  **Enumerate each registry for real, never from memory**, and report per
  proposal which registries were searched and what the nearest existing thing
  is. A proposal with no match says so explicitly — absence is an assertion
  here, not the default. The miss is always the helper nobody knew was there,
  and a hand-rolled copy of one reads as a deliberate choice to every later
  reviewer. Judge the plan's colors and spacing the same way: when the theme
  exposes a design system namespace beside MUI-compat aliases that resolve to
  the same value, the plan must name which vocabulary it writes, or one file
  ends up with both.

- **Subtraction** — audits the structure the plan proposes to *add*, which no
  other auditor is charged with. Take every wrapper, hook, context layer,
  extracted constant, barrel, indirection and boundary-enforcing test in the
  plan, and ask one question of each: **what breaks if this is deleted?** The
  answer must name a concrete consequence — a caller that would re-render, a
  type that would stop being checked, a duplication that would return. No such
  answer means the finding is "delete it, inline the thing it wraps".

  The pattern skills cannot do this: both are built to find *missing*
  structure, so a plan can pass composition and React-practice audits while
  carrying a memoized wrapper around an already-stable identity, a hook that a
  CSS line replaces, or a constant with exactly one reader. Prefer the simpler
  shape whenever the difference is small — the burden of proof sits on the
  layer, not on removing it.

Skip the two Vercel audits, and say so, when the repo is not React or the
skills are unavailable. The layering, state-shape, prior-art and subtraction
audits always run — prior art searches fewer registries when the plan proposes
no UI, but it still runs.

## 2. Naming and readability pass

Load the `simple-english:simple-english` skill (ASD-STE100 Simplified
Technical English) and apply it to two targets:

1. **Identifiers the plan proposes** — new files, components, hooks, props,
   functions. One word, one meaning: no synonym pairs (`fetch`/`load`/`get`
   for the same act), no name whose meaning needs the plan to decode, no
   abbreviation the repo does not already use. Names that already exist in
   the repo are renamed only if the plan already renames them — the scope
   wall applies to names too.
2. **The plan prose itself** — short sentences, active voice, one instruction
   per sentence, condition before command. The plan is an instruction
   document; rewrite it like one.

Produce a naming table (`current → proposed → why`, one line each) for
anything you want to change; prose rewrites are applied with the plan edits
in §3, never silently before the user has agreed.

## 3. Discuss, then apply

1. Merge the audit findings, the naming table, and any applicable
   plan-lessons into one list. Present it and ask **at most 3 questions**,
   highest-leverage only: a laundry list recreates the document-review pain
   this plugin exists to remove.
2. The user decides per item. Apply the agreed edits to `plan.md` directly —
   the plan file is the single source of truth and it converges toward the
   agreed shape, exactly as it does under sprint's Drift Log.
3. Record the outcome under `## Blueprint Notes` in the plan file (format
   below). Accepted findings bind sprint's subagents and are *verified at
   sprint's integration step* instead of re-raised; rejected findings are
   recorded with the reason and never carried forward.

## 4. Visual artifact

Publish the optimized plan as a visual artifact, in English, after the plan
edits land — the artifact is a view of the plan, never a fork of it; any
content difference between the two is a bug.

**The client-side architecture layers are the artifact's organizing frame.**
The page describes the plan in the same language the layering audit judged
it in (`references/client-side-architecture.md`): every planned piece
appears inside its layer, every diagram makes the layer boundaries visible,
and a piece that resists placement in one layer is not a drawing problem —
it is an audit finding that belongs back in §1.

1. Load the `artifact-design` skill first, then author the page and publish
   it with the Artifact tool. Diagrams are mermaid (artifacts render it
   natively); wide diagrams scroll in their own container.
2. Contents, in this order:
   - **Goal** — the change in the business terms of the spec, 2–3 sentences.
   - **Layer map** — the plan at a glance: one row or band per layer
     (presentation / interaction / state / domain / infrastructure), each
     planned piece placed in exactly one, marked new versus touched. This is
     the page's table of contents; everything below zooms into it.
   - **Component composition** — a mermaid tree of the planned components,
     grouped into layer subgraphs: what contains what, and where the
     container/presentational split falls.
   - **Data flow** — one mermaid flowchart or sequence per user-facing flow:
     user action → interaction logic → state → infrastructure → render,
     crossing the same layer bands the layer map drew. A flow that skips a
     layer or doubles back is drawn as it really is — visible awkwardness is
     the point.
   - **State placement table** — each piece of state: its type
     (local / remote / shared), its home layer and module, and why that home.
   - **Naming decisions** — the accepted naming table from §2.
   - **Scope wall** — what is in, what is explicitly out.
   - **Open questions** — anything the user deferred in §3.
3. Re-running blueprint on the same ticket republishes to the same artifact
   URL (same file path); record the URL in `## Blueprint Notes`.

## Rules

- **The scope wall is hard.** Out-of-scope findings are discarded before the
  discussion, not presented as "optional extras". The temptation this rule
  kills is the audit skills returning repo-wide advice.
- ≤5 findings per auditor, ≤3 questions to the user. Prioritize; do not
  enumerate.
- The plan file is the single source of truth. The artifact is generated
  from it after edits; never edit the artifact's content independently.
- Speak the user's language in the discussion (中文使用者就用中文討論); the
  plan file and the artifact stay in English.
- Blueprint is optional and idempotent: running it on an already-optimized
  plan should produce few or no findings, not a fresh round of churn.

## Plan-file section blueprint owns

```markdown
## Blueprint Notes
- 2026-08-24 accepted: RightPanel takes children, not 4 boolean flags — plan step 3 updated (composition)
- 2026-08-24 accepted: preview fetch moves into usePreviewAssets, out of the container (react-best-practices)
- 2026-08-24 rejected: global store for wizard state — wizard is one subtree, Context is enough
- naming: MediaDataHandler → useMediaUpload — says what it does, hook naming rule
- artifact: <url>
```

Sprint reads this section at dispatch (the decisions bind every implementer
subagent) and at integration (each accepted item either survived into the
code or has a Drift Log entry saying why not).
