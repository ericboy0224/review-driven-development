---
name: conventional-commits
description: Write every git commit message as a Conventional Commit — `<type>(<scope>): <description>` with an optional body and footer. Load this BEFORE composing any commit message, whenever you are about to run `git commit`, amend a commit, squash or reword during a rebase, or curate a branch's history. Also use when asked to fix, review, or standardise existing commit messages, when someone asks what type a change should be, or when a commit is rejected by commitlint. Covers the type list, subject rules, scope choice, when to use a body, BREAKING CHANGE, and how to split a commit whose message needs an "and".
---

# Conventional Commits

Every commit message follows:

```
<type>(<optional scope>): <description>

<optional body>

<optional footer(s)>
```

A machine reads the header to derive versions and changelogs; a human reads the
body to learn why. Write both for their own reader.

## Types

Lowercase, always. Pick by **what the change does to the product**, not by which
files it touched.

| Type | Use for | Version |
| --- | --- | --- |
| `feat` | New functionality a user or caller can now reach | MINOR |
| `fix` | Corrects behaviour that was wrong | PATCH |
| `refactor` | Restructures code without changing behaviour | — |
| `perf` | Makes existing behaviour faster or lighter | PATCH |
| `test` | Adds or changes tests only | — |
| `docs` | Documentation only | — |
| `style` | Formatting, whitespace, semicolons — no logic | — |
| `build` | Build system, bundler, dependencies | — |
| `ci` | CI/CD pipelines and their scripts | — |
| `chore` | Housekeeping that fits nothing above | — |
| `revert` | Reverts an earlier commit; name it in the body | — |

Resolving the common ambiguities:

- **`fix` vs `refactor`** — did observable behaviour change? If yes it is `fix`
  (or `feat`), however small the diff. A pure move is `refactor` even when it
  touches hundreds of lines.
- **`feat` vs `fix`** — could a user do something they could not do before? That
  is `feat`. Making an existing thing work as documented is `fix`.
- **`test` vs the change it covers** — a util and the tests proving it belong in
  **one** commit under the util's type. `test` is for tests that stand alone.
- **`chore` vs `build`** — dependency bumps and bundler config are `build`;
  `chore` is the residue, not the default.
- **`style` never means "design change".** A CSS change that alters what the
  user sees is `feat` or `fix`. `style` is formatting only.

## Description

- **Imperative mood**: "add", "drop", "keep" — not "added", "adds".
- **Lowercase start**, no trailing period.
- **Aim for ≤50 characters** for the whole header; treat 72 as the hard stop.
- Say what the change *achieves*, not which symbol it edited. `fix: preserve
  uploaded video filename` beats `fix: update handleUpload`.
- No ticket key in the description — it goes in the scope (below).

## Scope

Genuinely optional — most commits in this codebase have none. Add one when it
tells the reader something the description cannot:

- **A feature or module slug**, lowercase, when the work belongs to one:
  `feat(skip-to-store)`, `refactor(types)`.
- **A ticket key** when the commit is one of several on the same ticket and the
  key is the useful grouping: `refactor(CR-2453): route slot writes through a
  race-free accumulator`. Keep the key in its canonical uppercase form — it is
  an identifier, not a word.

Never use both, never invent a scope to fill the slot, and never write a bare
`[CR-1234]` prefix instead of a type — that prefix is the convention this skill
replaces.

## Body

Include one whenever the change is not self-evident from the header. Explain
**why**, and what the reader would otherwise have to reconstruct:

- the constraint or bug that forced this shape
- what you considered and rejected, when it is load-bearing
- consequences the diff does not show

Wrap at 72 characters. Do not restate the diff — the reader has it. Do not
attribute to a ticket or a review round; that belongs in Jira or the PR.

## Footers

- **Breaking changes**: `BREAKING CHANGE: <what breaks and what to do>` in the
  footer, uppercase. `feat(api)!: …` may mark it in the header too, but the
  footer is what tools read.
- **Reverts**: `revert: <original subject>` in the header, then
  `Refs: <sha>` in the footer.
- **Co-authorship**: end the message with the Co-Authored-By trailer this
  environment requires.

## One purpose per commit

If the description needs an "and", the commit is two commits. Split it — a
mechanical move separated from the behaviour change reviews in seconds instead
of hiding the real change inside churn. See the `review-driven-development`
plugin's `split-pr` for curating a whole branch this way.

## Before writing the message

1. `git diff --cached --stat` — know what is actually staged.
2. `git log --format='%s' -30` on the current branch's trunk — confirm the repo
   is on Conventional Commits and learn its scope habits.
3. If the repo's history is clearly and consistently on a *different*
   convention, say so and ask before switching it. Do not silently mix two
   conventions into one history.

## Examples

```
fix: preserve uploaded video filename

Media Center keys a folder's files by name, so renaming on upload
detached the optimize results from the slot that asked for them.
```

```
refactor(CR-2453): route slot writes through a race-free accumulator

Two slots resolving in the same tick each read the pre-write state and
the second overwrote the first. The accumulator makes the write order
irrelevant.
```

```
feat(skip-to-store)!: treat 'no interstitial selected' as OFF

BREAKING CHANGE: folders saved with Skip enabled but no interstitial
size now persist skipButton as absent. Re-save affected folders to
restore the previous payload.
```
