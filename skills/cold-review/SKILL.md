---
name: cold-review
description: Simulate the reviewer before the reviewer pays — hand the branch diff to a fresh subagent that has no ticket, no spec, no plan, no PR body and no memory, and make it narrate what the change does, commit by commit, listing every place it had to guess — then reads it again as a stranger three months out: which new interface the next likely change breaks, what the repository already had that the diff rebuilt, where one concept wears two names, and whether a datum keeps one shape from the wire to the screen or is re-validated at every hand-off because the pieces were written apart. The owner compares the narration to the intent; every wrong sentence and every guess is a readability defect, routed to one of three levers (naming, readable architecture, injected side effects) and fixed as a class, then a NEW fresh reader runs again until a stranger's narration matches. Ends with the reading guide for the PR body, written from the narration that finally passed. Use before a PR goes to humans — "/cold-review", "冷讀", "cold read the branch", "會不會看不懂", "reviewer 讀得懂嗎" — after sprint's readability gate, on an existing draft PR, or whenever the user asks whether a diff is understandable without the ticket. Not a defect hunt: correctness stays with the owner.
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
3. **Read this rung only.** On a stack, the reviewer reads the PR's diff
   against the rung below it, so the reading set is the commits that carry
   this ticket's key. Commits from a sibling ticket that show up only because
   the base rung has not yet pulled its own feature branch are not this
   change: drop them from the reading set by hash and mention them in the
   report. They are a base-sync note, not a finding.
4. Drop local-only scaffolding from the reading set (`DELETE BEFORE MERGE`
   markers, dev seed routes, `docs/`). The reader sees what the reviewer will
   see, nothing more.
5. Note the size: files, lines, commits. Above ~3000 lines, plan for two
   reading passes (§1 says how). A single reader handled 1800 lines across 12
   commits without loss (CR-2537, 2026-09-06).

## 1. The readers — three lanes, fresh, blind, never reused

The reader's job is too wide for one pass: today's understandability, the
change three months out, and whether it reads as one author's work are three
different readings of the same diff. Run them as **three general-purpose
subagents in parallel, in one message, model `opus`** (never `fork` — a fork
inherits this conversation, which is the context a reader must not have).
Each gets its own brief from `${CLAUDE_PLUGIN_ROOT}/skills/cold-review/references/`
with the placeholders filled: repo path, base ref, head commit, the commit
list. Every brief gives the repository to read around in, because a reviewer
can open files too, and withholds, by explicit instruction: the ticket, the
spec, the plan, the PR body, `docs/`, the design doc, and every conversation
this session had.

| Lane | Brief | Reads | Returns |
| --- | --- | --- | --- |
| **Today** | `brief-today.md` | commit by commit, in order | 1 narration (one sentence per commit, one paragraph for the whole) · 2 model (the concepts it learned) · 3 guesses (`file:line`, what it inferred, what would have removed the guess) · 4 stumbles (read twice, unmapped name, effect with no visible owner) · 5 re-entry (three future changes and where it would go; the change read again as three months old) · 6 reach (files outside the diff it had to open) |
| **Future** | `brief-future.md` | the final state, skimmed whole | 7 pressure (per new export, the next likely change argued from callers, absorb or break) · 8 already exists (the repo searched by concept, misses recorded) · 9 same thing, different words (call-site counts, so the older word is known) |
| **One author** | `brief-one-author.md` | two or three data paths, end to end | 10 station tables: shapes per datum, re-checks of what an earlier type guaranteed, distrustful hand-offs, vocabulary and validation style along the path, inherited vs introduced |

Code written in file-disjoint pieces fails the third lane first: each piece
validates the other's output, and the reader holds two models of one datum
at once. Name the data paths in the brief when you know them (the wire
response that ends up rendered, the user action that ends up written); leave
the placeholder empty to let the reader choose.

A ticket-specific question — "does this behaviour read as deliberate or as
an oversight, and from what?" — goes as an extra numbered section at the end
of the **Today** brief. It asks how the code reads, never whether it is
right.

When the working tree is being edited by someone else, pin the readers to the
head commit (`git show <head>:<path>`) and say so in the brief.

Model: `opus` by default. One reader on `opus` covered 1800 lines across 12
commits without loss; escalate a lane to a stronger model only when its report
comes back thin, never pre-emptively. Above ~3000 lines, split the **Today**
lane by commit halves and add a third whole-change reader with both halves
withheld.

**A reader is single-use.** Once it has narrated, it knows the change. Every
later round in §3 gets three new ones, and no reader ever sees another's
output.

## 2. The owner marks the gaps

Merge the three reports into one list first — the lanes overlap on purpose
(a Drift the Future lane counts is often a Stumble the Today lane hit), and
one gap counted twice is one fix. Then compare the narration to the intent,
which lives in this context (the spec, the plan, the discussion), and mark
each sentence and each guess as one of:

| Mark | Meaning | Goes to |
| --- | --- | --- |
| **Wrong** | the reader says the code does X; the intent was Y | §3 — unless the code really does X, in which case it is a defect and the owner fixes it as such. Correctness is the owner's, not the reader's. |
| **Guess, in-code** | the fact the reader needed could have been in a name, a type, a signature, or the placement of an effect | §3 |
| **Guess, off-code** | the fact is a decision taken offline that no code can carry (why this route and not that, what the backend does) | the PR body's "decided offline" list |
| **Stumble** | the reader got there, but paid twice | §3 |
| **Reach** | a hop outside the diff | §3 if the hop is to something the diff should have carried; otherwise accept and name it in the reading guide |
| **Brittle** | the reader named a next change, argued from callers, that the shape breaks | §3 as architecture — when the owner agrees the change is real. A future nobody can argue from the code is not paid for today. |
| **Reinvented** | something in the repository already does the job | §3 as architecture: delete the new one and call the old, or say in the commit body what the old one lacks |
| **Drift** | one concept, two words; or one word, two concepts | §3 as naming: align to the older or more used word, or to the design doc's term when one exists, never to the newer coinage |
| **Fragmented** | one datum, several shapes, or a station re-checking what an earlier type guaranteed | §3 as architecture: parse once where the wire enters, trust the type from then on, delete the re-checks and the shapes that only rename. One vocabulary and one validation style along the path. |

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
- **Readable architecture** also owns **Brittle**, **Reinvented** and
  **Fragmented**: a shape the next real change breaks, a wheel the repo
  already had, and a datum that changes shape at every hand-off because the
  pieces were written apart.
- **Naming** also owns **Drift**: the newer word yields to the older one, and
  both yield to the design doc.
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

Then spawn **three new** readers on the new diff. Stop when:

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
