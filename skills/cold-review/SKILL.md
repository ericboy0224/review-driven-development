---
name: cold-review
description: Simulate the reviewer before the reviewer pays — hand the branch diff to a fresh subagent that has no ticket, no spec, no plan, no PR body and no memory, and make it narrate what the change does, commit by commit, listing every place it had to guess. The owner compares the narration to the intent; every wrong sentence and every guess is a readability defect, routed to one of three levers (naming, readable architecture, injected side effects) and fixed as a class, then a NEW fresh reader runs again until a stranger's narration matches. Ends with the reading guide for the PR body, written from the narration that finally passed. Use before a PR goes to humans — "/cold-review", "冷讀", "cold read the branch", "會不會看不懂", "reviewer 讀得懂嗎" — after sprint's readability gate, on an existing draft PR, or whenever the user asks whether a diff is understandable without the ticket. Not a defect hunt: correctness stays with the owner.
---

# Cold-review — a stranger narrates the diff before a colleague has to

Correctness on this team comes from the ticket and the discussion around it,
and only the owner was in both. Everyone else who opens the PR is doing
something different: building, as cheaply as they can, a working model of what
changed. They are learning, not checking. Every review comment is therefore a
signal that the model did not form cheaply at that line, and the code — not
the reviewer — is what pays for it, in this round and in every re-read later.

An AI agent stands exactly where that reviewer stands: it was not in the
discussion either. So it can rehearse the reviewer's failure before the
reviewer has it. That is this skill: a reader with no context narrates the
diff, the owner marks where the narration goes wrong, and the code is changed
until a stranger gets it right.

Arguments: `[pr-number | base-ref]` — default: the PR whose head is the current
branch; failing that, `origin/master`.

## 0. Intake — the diff the learner will actually see

1. Resolve the base. With a PR: `gh pr view <n> --json baseRefName`. Fetch it.
2. List the commits the reader will walk, in order:
   `git log --reverse --format='%h %s' origin/<base>..HEAD --no-merges`.
3. **Stop on a leaked sibling.** A commit whose subject carries another
   ticket's key, or that only exists because the base branch is behind its own
   feature branch, is not this change. A learner would build a model of two
   tickets and blame this one for both. Fix the base (merge the feature branch
   into the base PR, or move this PR's base) before reading. Report it; do not
   read around it.
4. Drop local-only scaffolding from the reading set (`DELETE BEFORE MERGE`
   markers, dev seed routes, `docs/`). The reader sees what the reviewer will
   see, nothing more.
5. Note the size: files, lines, commits. Above ~800 lines, plan for two reading
   passes (§1 says how).

## 1. The reader — fresh, blind, and never reused

Spawn **one general-purpose subagent** (never `fork` — a fork inherits this
conversation, which is the context the reader must not have). Hand it the
brief in `${CLAUDE_PLUGIN_ROOT}/skills/cold-review/references/reader-brief.md`
with the placeholders filled: repo path, base ref, the commit list. The brief
gives it the repository to read around in, because a reviewer can open files
too. It withholds, by explicit instruction: the ticket, the spec, the plan,
the PR body, `docs/`, the design doc, and every conversation this session had.

The reader returns six things:

1. **Narration** — one sentence per commit, then one paragraph for the whole
   change: what it does and why someone wanted it.
2. **Model** — the concepts it had to learn, each with the name the code uses
   and what the reader believes it means.
3. **Guesses** — every place it inferred intent the code does not state, with
   `file:line`, the guess, and what it would have needed to see instead.
4. **Stumbles** — names it could not map to a concept, code it read twice,
   effects whose owner it could not find, two things that looked the same.
5. **Re-entry** — three plausible future changes and where it would go to
   make each. Wrong answers here are the cost the next maintainer pays.
6. **Reach** — which files outside the diff it had to open to understand the
   diff. Every such file is a hop the reviewer pays.

For a diff above ~800 lines, run two readers in parallel with the same brief
and different commit halves, then a third for the whole with both narrations
withheld. Never let one reader see another's output.

**A reader is single-use.** Once it has narrated, it knows the change. Every
later round in §3 gets a new one.

## 2. The owner marks the gaps

Compare the narration to the intent, which lives in this context (the spec,
the plan, the discussion). Mark each sentence and each guess as one of:

| Mark | Meaning | Goes to |
| --- | --- | --- |
| **Wrong** | the reader says the code does X; the intent was Y | §3 — unless the code really does X, in which case it is a defect and the owner fixes it as such. Correctness is the owner's, not the reader's. |
| **Guess, in-code** | the fact the reader needed could have been in a name, a type, a signature, or the placement of an effect | §3 |
| **Guess, off-code** | the fact is a decision taken offline that no code can carry (why this route and not that, what the backend does) | the PR body's "decided offline" list |
| **Stumble** | the reader got there, but paid twice | §3 |
| **Reach** | a hop outside the diff | §3 if the hop is to something the diff should have carried; otherwise accept and name it in the reading guide |

Do not explain anything to the reader. Do not answer its questions. Its
confusion is the deliverable; the answer goes into the code or the PR body.

Every mark that goes to §3 gets a lever:

- **Naming** — the name did not carry the concept, or two names carried one,
  or one name carried two. Terms come from the design doc's terminology table
  when one exists; a term the doc lacks gets a row there, not a synonym here.
- **Readable architecture** — the reader could not follow the structure
  without holding several patterns at once: a concept that exists twice, a
  layer that only moves a line, state placed away from the thing that owns it,
  a component that does two jobs.
- **Injected side effects** — a complex operation performs its effects inline,
  so the reader cannot see the sequence without also reading the upload, the
  store write, the toast. The team's shape: the pure steps in one module, a
  hook that supplies the effects, a container that runs them, a shell that only
  renders. The reader could not locate an effect's owner is the tell.

A gap that fits no lever is usually two levers; split it.

## 3. Fix the class, then read again

Fixes follow `fix-comment` §3: the gap the reader hit is one *instance*, and
the diff is swept for the class before the commit. One class per commit,
`conventional-commits` for the message. Route by lever:

| Lever | Load |
| --- | --- |
| Naming | `simple-english:simple-english`, the design doc's terminology table |
| Readable architecture | `vercel-composition-patterns`, `${CLAUDE_PLUGIN_ROOT}/skills/blueprint/references/client-side-architecture.md` |
| Injected side effects | `${CLAUDE_PLUGIN_ROOT}/skills/blueprint/SKILL.md`, the auditor question "is any orchestration planned to live inside a provider, hook or component?" and its finding |

When the gap sits in code that was fixed more than twice after its feat
commit, prefer rewriting that region to the team's shape over patching the
name: three fixes mean the author's own model was unstable there, and a
learner's will not be steadier.

Then spawn a **new** reader on the new diff. Stop when:

- the narration matches the intent with no **Wrong** marks, and
- every remaining guess is **off-code**, and
- the re-entry answers point where the owner would go.

Two rounds is normal. A fourth round means the change's structure, not its
surface, is the problem — take it to `split-pr` or back to `blueprint` and
say so.

Record each round in the plan file under `## Cold Review`: round number,
gaps by lever, commits that fixed them. Gaps by lever are the number this team
wants to see decay across tickets; keep them countable.

## 4. The reading guide — the narration that passed

The final reader's narration is the only reading guide that has been tested
on a stranger. It becomes the PR body's learner section, in Simple English:

1. **What this changes** — the reader's whole-change paragraph, edited only
   for terms.
2. **Read in this order** — the per-commit sentences, in commit order. If the
   history will be re-cut after this, re-cut to *this* order: it is the order
   a stranger proved they can learn in.
3. **Decided offline** — every **off-code** guess, each answered in one
   sentence. This is where the discussion the reviewer missed is handed to
   them, once.
4. **You will need to open** — the accepted **Reach** files, named.

Show the guide to the user before it goes anywhere near the PR. Writing it
into the PR body is the user's call, as is every edit to a PR that already has
reviewers on it.

## 5. Close out with the user

Report, short:

1. **Rounds run** and gaps by lever per round.
2. **Fixed** — one line per class, with the hash.
3. **Waiting on you** — every **Wrong** mark where the code really does what
   the reader said (a correctness call), every gap whose fix is larger than a
   rename or a move, and the reading guide for approval.

## Rules

- The reader never gets the ticket, the spec, the plan, the PR body, `docs/`,
  or this conversation. If it asks, the answer goes into the code.
- The reader is never reused across rounds and never sees another reader's
  narration.
- The owner never argues with the narration. A wrong narration of correct code
  is a readability defect by definition.
- Correctness stays with the owner. The reader is not asked to find bugs, and
  a bug it happens to find is reported to the owner, not counted as a gap.
- Nothing the reader needed is answered with a comment when a name, a type, a
  signature, or the placement of an effect can carry it (`sprint` §3's
  no-comment default applies).
- The skill does not edit the PR body or the ticket; it hands the user the
  text.
