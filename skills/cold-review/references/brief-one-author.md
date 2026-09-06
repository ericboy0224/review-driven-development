# Reader brief — fill the placeholders, hand the whole file to a fresh general-purpose subagent (model: opus)

You are reading a code change the way a colleague on the team would read it
for the first time. You were not part of any discussion about it. You have no
ticket, no specification, no plan, no PR description, and you must not look
for them: do not open anything under `docs/`, do not run `gh`, do not read
markdown files that describe the work. If a file you open turns out to be
such a document, close it and say so in your report.

Read the code. You may open any source file in the repository. Your job is not
to find bugs and not to judge whether the change is understandable. Your job is
one question: does this change read as if one person wrote it, or as several
pieces written apart that distrust each other at the hand-offs? Answer it by
walking data end to end.

Repository (a git worktree; run every command from here, do not `cd` out):
`{{REPO_PATH}}`

Base ref: `{{BASE_REF}}`

Commits to read, in this order:

```
{{COMMIT_LIST}}
```

Skim the whole change first (`git diff <base>...HEAD -- src`, or the union of
the commits' diffs), then read the final state of the files it touches. When
another agent may be editing the working tree, pin every read to the head
commit: `git show <head>:<path>`, `git grep <pattern> <head> -- src`.

Pick the two or three pieces of data the change carries furthest — a server
response that ends up rendered, a user action that ends up written to the
server, a value converted between the domain and the wire. The owner may name
them here:

```
{{DATA_PATHS}}
```


Report, in this structure and nothing else:

## One author?

For each data path, walk it end to end and write down every station:
the type or shape the datum has there, the file, and what happens to it
(parsed, validated, converted, defaulted, narrowed, re-validated, renamed,
wrapped). Then report:

- how many distinct shapes one datum wears along the path, and which
  stations only rename or re-wrap;
- every station that checks something a type from an earlier station already
  guaranteed (a null check after a non-null type, a `zod` parse after a
  typed parse, a format after a format);
- every hand-off where the receiving side distrusts the sending side — a
  fallback, a default, an `as`, a guard — and whether the sending side's type
  already forbade that case;
- whether the stations read as one author's work: the same vocabulary for
  the same datum, one validation style (all `zod`, or all hand guards, not
  both), one place where the wire is trusted from then on;
- the stations where you had to hold two representations of the same datum
  in mind at once.

Rules for the report: one fact per sentence, active voice, no praise, no
proposals for how to fix anything. Cite `file:line` for every claim, and say
for each finding whether the change introduced it or inherited it (`git log
--oneline -1 -- <path>` at the base helps).
