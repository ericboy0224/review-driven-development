# Reader brief — fill the placeholders, hand the whole file to a fresh general-purpose subagent

You are reading a code change the way a colleague on the team would read it
for the first time. You were not part of any discussion about it. You have no
ticket, no specification, no plan, no PR description, and you must not look
for them: do not open anything under `docs/`, do not run `gh`, do not read
markdown files that describe the work. If a file you open turns out to be
such a document, close it and say so in your report.

Read the code. You may open any source file in the repository to understand
the diff, the way a reviewer would. Your job is not to find bugs. Your job is
to build, as cheaply as you can, a working model of what changed and why, and
to report exactly where building that model was expensive or impossible.

Repository (a git worktree; run every command from here, do not `cd` out):
`{{REPO_PATH}}`

Base ref: `{{BASE_REF}}`

Commits to read, in this order:

```
{{COMMIT_LIST}}
```

Read them one at a time, in order, with `git show <hash>` (for the diff) and
the working tree (for surrounding code). Do not read a later commit before
you have written your sentence for the earlier one.

Report, in this structure and nothing else:

## 1. Narration

One sentence per commit, in order, prefixed with the hash: what this commit
does, in the words a colleague would use. Then one paragraph for the whole
change: what it does and why someone wanted it. Write what the code says, not
what you suspect was meant.

## 2. Model

The concepts you had to learn. For each: the name the code uses, and what you
believe it means, in one sentence. Mark with `?` any concept whose meaning you
are not sure of.

## 3. Guesses

Every place where you inferred an intention the code does not state. For each:
`file:line`, what you guessed, and what you would have needed to see (a name,
a type, a signature, a placement) to not have to guess. Include the guesses
that turned out consistent with later commits; the reader who arrives at that
line does not have the later commit yet.

## 4. Stumbles

Where you paid twice: a name you could not map to a concept, code you read
more than once, an effect (a write, a request, a toast, a store update) whose
owner you could not find, two things that looked the same and were not, or
looked different and were the same.

## 5. Re-entry

Name three plausible future changes to this area and, for each, the file and
function you would go to first. Say how confident you are.

Then read the change once more as if it were three months old and you had
forgotten this session: which names, shapes or placements would you have to
re-learn, and which facts the code leans on will have changed by then (a
design-system marker, a backend response shape, a sibling module's signature)?

## 6. Reach

Every file outside the diff you had to open to understand the diff, and the
question that sent you there.

## 7. Pressure on the new interfaces

For every type, function signature, hook, prop or constant the change exports
or adds to an existing export: name the most likely next change a caller will
ask of it, and say whether the current shape absorbs that change or breaks its
callers. Name only changes you can argue from the code and its callers, not
hypothetical futures. Say what you would have written differently today if
that next change is real.

## 8. Already exists

For every helper, type, hook or component the change adds, search the
repository for something that does the same job by CONCEPT, not by name
(`grep`/`rg` over `src/`; read candidates). Report each candidate with its
path and one sentence on whether it is the same thing, a near-duplicate that
differs in one detail, or genuinely different. Report the searches that found
nothing too, with the terms you used.

## 9. Same thing, different words

List every pair where the change and the existing code (or two places in the
change) name one concept with two words, or use one word for two concepts.
For each pair: both names, both locations, which one is older or more widely
used in the repository (count the call sites), and which one the design
vocabulary in the code (constants, enums, type names) already prefers.

Rules for the report: one fact per sentence, active voice, no praise, no
proposals for how to fix anything except where §7 explicitly asks what you
would have written. You are describing what happened when you read, not
reviewing.
