---
name: stacked-prs
description: Create, inspect, rebase, and repair GitHub stacked pull requests — chains where each PR targets the branch below it — using the `gh stack` CLI extension. Use this whenever the user mentions a stacked PR, a PR stack, 疊 PR, 堆疊 PR, a chain of dependent PRs, or asks why a PR is missing from a stack, why the stack badge shows the wrong count, how to rebase a branch whose base branch was rewritten or force-pushed, how to retarget a PR after the one below it merged, or how to open a PR on top of another still-open PR. Also use when a branch needs `git rebase --onto` because its parent branch history changed underneath it. Reach for this before hand-rolling `gh pr create` chains — a GitHub stack is an explicit linked object, and PRs created the ordinary way are not in one even when their base branches chain perfectly.
---

# Stacked pull requests

A stack is two or more pull requests **in the same repository** where the bottom PR
targets the trunk (usually the default branch) and each PR above targets the branch of
the PR below it. Each layer gets its own focused diff, so reviewers can approve them
independently instead of wading through one enormous PR.

## The thing that surprises everyone

**A GitHub stack is an explicit object, not something inferred from base/head chains.**

You can wire three PRs so that each one's base is the previous one's head, confirm it
with the API, and still have GitHub show them as unrelated — because nothing ever
*linked* them. PRs created with plain `gh pr create` or through the web UI are not in a
stack. The stack badge (⧉ 1/3, 2/3, 3/3) only counts linked members.

This matters because the symptom is confusing: the git side is provably correct, so it
is tempting to blame draft status, caching, or permissions. Check membership directly
instead of theorising:

```bash
gh stack view            # "not part of a stack" is the answer, not an error
```

Drafts are *not* the reason. `gh stack submit` creates PRs as drafts by default, so a
healthy stack is usually full of them.

## Diagnose before acting

Two independent questions, worth separating because they have different fixes:

| Question | How to check | If wrong |
| --- | --- | --- |
| Is the git wiring right? | `gh pr view N --json baseRefName` equals the head of the PR below | Rebase and retarget (see below) |
| Is the PR linked into the stack? | `gh stack view` | `gh stack link` |

A PR can have perfect wiring and no link, or be linked but sitting on stale commits.
Fixing one does not fix the other.

## Creating a stack from scratch

Requires `gh` ≥ 2.90.0 and git ≥ 2.20. Install once:

```bash
gh extension install github/gh-stack
```

```bash
gh stack init                    # first branch, based on the repo default branch
gh stack init --base release     # ...or on some other trunk
# write code, commit as usual
gh stack add BRANCH-NAME         # next layer up
gh stack add -Am "message"       # stage + commit + branch in one step
gh stack submit                  # push all branches, open the PRs, link them
gh stack view                    # branches, PR links, statuses, recent commits
```

`gh stack submit` opens drafts. Add `--open` when the layers are ready for review, or
flip them individually later — marking a PR ready notifies reviewers and may trigger
CODEOWNERS assignment, so let the user decide rather than doing it to "test something".

## Adopting PRs that already exist

This is the common case in a repo where the stack grew by hand. `gh stack link` attaches
existing PRs into a stack on GitHub without requiring local tracking first:

```bash
gh stack link <branch-or-pr> <branch-or-pr> [...]        # bottom first
gh stack link --base feature/integration 108 109 113
```

Order the arguments bottom-to-top. `--base` names the trunk the bottom PR lands on. This
does not rewrite any commits or change any PR's base — it only creates the link, which is
what makes the badge and the stack navigation appear.

## Keeping a stack current

When a lower layer changes, everything above it needs to move:

```bash
gh stack down                 # or: gh stack checkout BRANCH
# edit, commit
gh stack rebase --upstack     # cascade from here to the top
gh stack push                 # uses --force-with-lease
gh stack top
```

`gh stack rebase` with no flags cascades the whole stack from trunk upward.
`--downstack` covers trunk→current, `--upstack` covers current→top. On conflict: fix the
files, `git add`, then `gh stack rebase --continue`; `--abort` restores the prior state.

After anything merges, `gh stack sync --prune` refetches, rebases, and deletes local
branches whose PRs are gone.

GitHub also offers a **Rebase stack** button in the merge box. It runs the same cascade
server-side but produces **unsigned commits** — if the repo requires signed commits,
rebase from the CLI instead.

## When the parent was rewritten outside `gh stack`

Someone force-pushes the branch below you — a rebase onto a new trunk, a cleanup pass,
an amend. Your branch now carries stale copies of their commits, and a plain
`git rebase parent` will try to replay those duplicates and conflict against work that is
already upstream under different hashes.

The tool for this is three-argument `--onto`, which replays only *your* commits:

```bash
git rebase --onto <new-parent-head> <old-parent-head> <your-branch>
```

`<old-parent-head>` is the commit your branch was originally based on — the boundary
between their commits and yours. Find it with `git merge-base` recorded *before* they
force-pushed, or from the reflog, or by reading `git log --oneline` for where their commit
subjects stop and yours begin. Everything up to and including that commit is dropped;
everything after it is replayed onto the new parent.

Rituals worth keeping, because rebases of shared branches are the easiest thing to lose
work to:

- Tag first: `git tag -f <branch>-pre-rebase <branch>`. It costs nothing and the reflog is
  not forever.
- Push with `--force-with-lease`, never bare `--force`. The lease aborts if the remote
  moved since your last fetch, which is exactly the case where someone else's work is
  about to be erased.
- Never fetch with `--prune-tags` on a repo where you keep local-only backup tags — it
  deletes every tag the remote does not have, backups included.

### Expect these conflict shapes

When the parent branch restructured rather than merely moved, the conflicts are not
textual and cannot be resolved by picking a side:

- **modify/delete** — you edited a file the parent deleted. Ask what the parent replaced
  it with, then port your change into the new home. Often your change turns out to be
  *already upstream* (they did the same refactor), in which case the right resolution is
  `git rm` and letting the commit shrink.
- **add/add** — you both created the same file. Take the parent's version as the base and
  re-apply only the part that is genuinely yours.
- **rename fallout** — the parent renamed a type or hook and your commits still use the old
  name. `git` will not flag this; it merges cleanly and then fails to compile. After the
  rebase, grep for the old names and run the typechecker.

Always run the project's typecheck, lint, and tests after a structural rebase. A clean
`git rebase` says nothing about whether the result builds.

## Merging

Merging the bottom PR auto-rebases the remaining branches so the next PR retargets the
trunk — you do not retarget by hand. To land several layers at once:

```bash
gh stack merge --squash          # or --merge / --rebase
gh stack merge 108 -y
```

`gh stack unstack` dissolves a stack, unlinking its open, draft, and closed PRs while
leaving their base branches alone. Merged and queued PRs stay in the stack.

## Constraints

- Same repository only. **Cross-fork stacks are not supported.**
- Not supported in GitHub Desktop.
- The feature is in public preview and its behaviour can change.

## Full command reference

`references/cli-commands.md` has every `gh stack` subcommand, its flags, the interactive
`gh stack modify` keybindings, environment variables, and the exit codes (useful when
scripting — e.g. `2` means not in a stack, `3` a rebase conflict, `9` stacked PRs not
enabled for the repository). Read it when you need a flag that is not in this file.
