# `gh stack` command reference

Source: [Stacked pull requests CLI commands](https://docs.github.com/en/pull-requests/reference/stacked-prs-cli-commands)

## Contents

- [Install](#install)
- [Stack management](#stack-management) — `init`, `add`, `view`, `checkout`, `modify`, `unstack`
- [Remote operations](#remote-operations) — `submit`, `sync`, `rebase`, `push`, `link`, `merge`
- [Navigation](#navigation) — `switch`, `up`, `down`, `top`, `bottom`, `trunk`
- [Utility](#utility) — `alias`, `feedback`
- [Environment variables](#environment-variables)
- [Exit codes](#exit-codes)

## Install

```shell
gh extension install github/gh-stack
```

Requires GitHub CLI ≥ 2.90.0 and git ≥ 2.20, with `gh auth login` already done.

## Stack management

### `gh stack init`

Initialize a new stack in the current repository.

```shell
gh stack init [flags] [branches...]
```

| Flag | Meaning |
| --- | --- |
| `-b, --base <branch>` | Trunk branch (defaults to the repository default branch) |

### `gh stack add`

Add a new branch on top of the current stack.

```shell
gh stack add [flags] [branch]
```

| Flag | Meaning |
| --- | --- |
| `-A, --all` | Stage all changes including untracked files (requires `-m`) |
| `-u, --update` | Stage tracked files only (requires `-m`) |
| `-m, --message <string>` | Create a commit before creating the branch |

### `gh stack view`

View the current stack. Also the fastest way to answer "is this branch in a stack at all?"

```shell
gh stack view [flags]
```

| Flag | Meaning |
| --- | --- |
| `-s, --short` | Compact output, branch names only |
| `--json` | JSON output |

### `gh stack checkout`

Check out a stack by stack number, PR number, PR URL, or branch name.

```shell
gh stack checkout [<stack-number> | <pr-number> | <pr-url> | <branch>]
```

### `gh stack modify`

Interactively restructure the current stack.

```shell
gh stack modify [flags]
```

| Flag | Meaning |
| --- | --- |
| `--continue` | Continue after resolving conflicts |
| `--abort` | Abort and restore the previous state |

Prerequisites: an active stack checked out, a clean working tree, no rebase in progress,
no queued merges, and linear history.

Keybindings inside the session:

| Key | Operation |
| --- | --- |
| `x` | Drop branch |
| `d` | Fold down (into the branch below) |
| `u` | Fold up (into the branch above) |
| `i` | Insert a branch below |
| `I` | Insert a branch above |
| `Shift+↓` | Move down |
| `Shift+↑` | Move up |
| `r` | Rename |
| `z` | Undo |

Save with Ctrl/Cmd+S, then `gh stack submit` to apply the restructure on GitHub.

### `gh stack unstack`

Remove a stack from local tracking and unstack it on GitHub. Open, draft, and closed PRs
are unlinked; their base branches are left alone. Merged and queued PRs stay in the stack.

```shell
gh stack unstack [<stack-number>] [flags]
```

| Flag | Meaning |
| --- | --- |
| `--local` | Remove local tracking only, leave the stack on GitHub |

## Remote operations

### `gh stack submit`

Push branches, then create or update pull requests and the stack on GitHub.

```shell
gh stack submit [flags]
```

| Flag | Meaning |
| --- | --- |
| `--auto` | Skip the editor, use auto-generated titles |
| `--open` | Create PRs as ready for review instead of drafts |
| `--remote <name>` | Remote to push to |

PRs are created as **drafts** unless `--open` is passed.

### `gh stack sync`

Fetch, rebase, push, and sync pull request state.

```shell
gh stack sync [flags]
```

| Flag | Meaning |
| --- | --- |
| `--remote <name>` | Remote to fetch from / push to |
| `--prune` | Delete local branches for merged PRs |

When someone else adds PRs to the stack remotely, `sync` fetches the new branches and
appends them locally. If local and remote have diverged, interactive mode offers three
resolutions: treat remote as truth, delete the remote stack, or cancel.

### `gh stack rebase`

Pull from the remote and cascade-rebase across the stack.

```shell
gh stack rebase [flags] [branch]
```

| Flag | Meaning |
| --- | --- |
| `--downstack` | Rebase only trunk → current branch |
| `--upstack` | Rebase only current branch → top |
| `--no-trunk` | Skip trunk, rebase stack branches only |
| `--continue` | Continue after resolving conflicts |
| `--abort` | Abort and restore the previous state |
| `--remote <name>` | Remote to fetch from |
| `--committer-date-is-author-date` | Preserve author dates |

### `gh stack push`

Push the active branches in the current stack. Uses `--force-with-lease`.

```shell
gh stack push [flags]
```

| Flag | Meaning |
| --- | --- |
| `--remote <name>` | Remote to push to |

### `gh stack link`

Link existing pull requests into a stack on GitHub without local tracking. Arguments go
bottom-first.

```shell
gh stack link [flags] <stack-number | branch-or-pr> <branch-or-pr> [...]
```

| Flag | Meaning |
| --- | --- |
| `--base <branch>` | Base branch for the bottom of the stack |
| `--open` | Mark the PRs as ready for review |
| `--remote <name>` | Remote to push to |

### `gh stack merge`

Merge one or more stacked pull requests at once.

```shell
gh stack merge [<stack-number> | <pr-number>]
```

| Flag | Meaning |
| --- | --- |
| `--merge-method <method>` | `merge`, `squash`, or `rebase` |
| `--merge` / `--squash` / `--rebase` | Shorthands for the above |
| `-y, --yes` | Merge without confirmation |

## Navigation

| Command | Meaning |
| --- | --- |
| `gh stack switch` | Interactively switch to another branch in the stack |
| `gh stack up [n]` | Move up, away from trunk |
| `gh stack down [n]` | Move down, toward trunk |
| `gh stack top` | Jump to the top |
| `gh stack bottom` | Jump to the bottom |
| `gh stack trunk` | Jump to the trunk branch |

## Utility

### `gh stack alias`

Create a short command alias; the default name is `gs`.

```shell
gh stack alias [flags] [name]
```

| Flag | Meaning |
| --- | --- |
| `--remove` | Remove a previously created alias |

### `gh stack feedback`

```shell
gh stack feedback [title]
```

## Environment variables

| Variable | Values | Purpose |
| --- | --- | --- |
| `GH_STACK_THEME` | `auto`, `light`, `dark` | Color palette of the interactive screens |

## Exit codes

| Code | Meaning |
| --- | --- |
| 0 | Success |
| 1 | Generic error |
| 2 | Not in a stack, or stack not found |
| 3 | Rebase conflict |
| 4 | GitHub API failure |
| 5 | Invalid arguments or flags |
| 6 | Disambiguation required (branch belongs to multiple stacks) |
| 7 | Rebase already in progress |
| 8 | Stack locked by another process |
| 9 | Stacked PRs not enabled for the repository |
| 10 | Modify session interrupted; recovery needed |
