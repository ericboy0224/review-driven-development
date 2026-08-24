---
name: split-pr
description: Make a large change reviewable — first by curating its commit history into a readable narrative, and only if that is not enough, by cutting it into a few complete, self-contained PRs. Use right after a spec & plan are generated ("plan 好了，來拆 branch", "/split-pr CR-123", "開工前先拆"), when a PR or branch has grown past what a reviewer can hold ("PR 太大", "這筆 947 行怎麼辦", "幫我拆成 stack"), or before starting a feature big enough that one PR would be hard to read. Never ships placeholders, mock values, or TODOs that a later PR removes. Always plans and discusses first — never touches a branch before the user approves.
---

# split-pr — make a large change readable

The scarce resource is not the reviewer's patience for long diffs. It is their
**context**: how much of the change they can hold in their head at once, and
how often they are forced to put it down and look somewhere else.

That gives two failure modes, and they pull in opposite directions:

- **Too big to hold.** One diff so large the review degrades into a skim.
- **Too fragmented to hold.** So many PRs that the reviewer must carry the
  whole ladder in their head to judge any one of them — and worse, must flip
  forward to later PRs to check whether the thing they are about to flag is
  already fixed there. Every such lookup is a context switch, and the cost of
  those switches exceeds whatever was saved by the smaller diff.

Line count is a symptom of the first, never a goal in itself. **Do not tune a
split to hit a number.** Tune it so each PR can be understood and judged
without leaving it.

## The completeness rule

**Never publish, in one PR, something a later PR removes.**

No placeholder bodies, no mock return values, no `TODO(next-pr:…)` markers, no
functions that exist only until the rung above deletes them. If the ticket is
expected to deliver the whole feature, the PRs that deliver it must each be
finished code.

This is not a style preference. It is what makes review possible:

- A reviewer who finds a problem in a placeholder cannot tell whether it is a
  real defect or scaffolding that disappears two PRs later. To avoid filing a
  false alarm they go and read the later PRs — the exact context switch this
  skill exists to prevent.
- Automated review is worse than useless on such a PR: it has no way to know
  what the ladder intends, so it reports the scaffolding as findings, and the
  human ends up doing the pass manually anyway.

Skeleton-first is a fine way to *build* — write the contracts, then fill
them in. It is not a way to *publish*. When the work is ready to go out, any
skeleton or checkpoint commit is folded into the commit that completes it.

## Decision order

Work down this list and stop at the first step that makes the change readable.

1. **Curate the commit history.** For most large-but-coherent changes this is
   the whole answer, and it is the cheapest. See §2.
2. **Split into a few complete PRs.** Only when a single PR stays hard to read
   even with a clean history. Aim for the smallest number of PRs that each
   stand alone — two or three is usually right, rarely more than four. See §3.
3. **Reconsider the ticket.** If the work genuinely cannot be told as one
   story, the ticket is doing more than one thing and the split belongs in
   Jira, not in git.

Arguments: `[ticket-key | plan-path | branch/PR]`
- Ticket key (e.g. `CR-123`) — resolve `docs/plans/<KEY>/plan.md` and
  `docs/specs/<KEY>/spec.md` (cs-jira convention), or explicit file paths.
- A branch name, PR number, or PR URL — an existing branch to make readable.
- Nothing — ask which; if the current branch is far ahead of its base, suggest
  working on it.

## 0. Intake

1. Get the real diff — `gh pr view` for base/size, `git diff <base>...<head>
   --stat` for the file list, then read the changed files. For a plan-time run
   with no code yet, read the plan and spec instead.
2. Identify the trunk. Note the repo's branch-naming convention from recent
   branches, and read two or three recent substantial PR descriptions for the
   house style.
3. Read the existing commits (`git log --stat <base>..<head>`). Often the
   author already told the story and it only needs tidying.

## 1. Architecture discussion — before anything else

Do not open with a branch list or a commit list. Boundaries fall out of
component boundaries, and those are a design decision the user must own.

1. Restate the **business goal** in one or two sentences: what the user of the
   product gets. Confirm it.
2. Propose a **component sketch**: the module tree from the outermost surface
   inward — names, one-line responsibilities, who imports whom, where state
   lives. Flag where the plan is silent.
3. Discuss until the tree is agreed. Ask at most 3 highest-leverage questions
   per round (module boundaries, state ownership, data flow direction).

## 2. Curate the commit history

The goal: a reviewer can read the commits in order and watch the change being
built, without ever needing a later commit to make sense of an earlier one.

**Build bottom-up, not skeleton-first.** Leaf utilities and their tests land
first, complete; the wiring that turns them on lands last. The final commit is
usually the one that changes user-visible behaviour, and it is short because
everything beneath it is already in place and already tested.

Each commit:

- **Is complete on its own.** It compiles, its tests pass, and nothing in it
  is waiting for a later commit to be finished or removed.
- **Has one purpose, describable in a sentence with no "and."**
- **Carries its own tests.** A util and the tests that prove it belong in the
  same commit; a reviewer judging the util should not have to search for them.
- **Says why in the body**, not what. The diff already says what. Load the
  `conventional-commits` skill before writing any of these messages — it owns
  the type choice, the subject rules and the scope decision.

What to eliminate:

- Fixup commits, "address review", "typo", "rename after feedback". Squash
  them into the commit whose story they belong to.
- Commits that only exist to be undone later.
- Mechanical churn mixed into a behaviour commit — a pure move or rename gets
  its own commit so the reviewer can skip it in seconds instead of hunting for
  the real change inside it.

The rewrite is `git rebase --onto` plus `git reset --soft <base>` and
re-committing in the new order. Verify by proving equivalence: the tree at the
end of the curated history must be identical to the tree before it
(`git diff <original-head> <curated-head>` is empty). Never rewrite the
original branch in place — cut a new one and keep the original until the user
says otherwise.

Then say so in the PR description: tell the reviewer the history is curated and
worth reading commit by commit, and list the commits with one line each.

## 3. If it still needs splitting — split into complete PRs

Only reached when a single curated PR is still too much to hold. Cut along
**seams where the work is genuinely finished on one side**, so each PR is a
thing that could merge on its own and leave the codebase coherent.

Good seams, in rough order of preference:

1. **A pure refactor that unlocks the feature** — a move, an extraction, a
   shared type. It changes no behaviour, so it reviews in minutes and gets out
   of the way of the real change.
2. **A self-contained module with its own tests** — a matching algorithm, a
   parser, a validator. Complete, exercised by tests, judged on its own terms.
   It is legitimately not called yet; say so in the description, and open the
   PR that calls it at the same time so the reviewer can see where it lands.
3. **The integration that turns it on** — the wiring, the UI, the behaviour
   change. This is where the product decisions live and where review attention
   is worth the most.

Bad seams — every one of these forces a forward lookup:

- A contracts-only PR whose bodies arrive later.
- A structure PR whose logic arrives later.
- Any cut that leaves one side computing a value nothing consumes yet *and*
  unable to be judged without seeing the consumer.

Each PR must pass the standalone test: **could a reviewer judge this without
opening any other PR in the stack?** If not, merge it with the PR that answers
its question.

## 4. Write the plan and stop

Append to the plan file, or write a standalone one:

```markdown
## Review Plan
- trunk: <branch this lands on>
- shape: single PR with curated history | N complete PRs
- commits (per PR, in order):
  1. <one-sentence purpose> — <files> — est ~<n> lines
  2. ...
- what each PR can be judged on without leaving it: <one line each>
- open questions: <anything the discussion left undecided>
```

Present it and **wait for the user's OK**. They may merge steps, re-order, or
move a boundary — update the plan file, not the conversation memory.

**No branch mutation, no force-push, no PR creation before that OK.**

## 5. PR descriptions

Written in the repo's own style — read its recent substantial PRs and follow
their pattern, not a generic template. On top of that:

- **The goal in the user's terms**, in the first paragraph.
- **The reading route**: whether to read the diff whole or commit by commit,
  and the commit list with one line each if the latter.
- **The decisions this PR asks the reviewer to judge** — the two or three
  places where a different choice was available. This is what reviewers
  actually want and what a big diff buries.
- **When there is more than one PR**: a short shared block naming the other
  PRs and what each owns, so a reviewer landing on any one of them knows the
  shape without opening the rest. Keep it to a table and a sentence — if it
  needs more than that, the split is too fine.
- **Verification claims match what ran.** State what was executed. If the
  history was curated rather than re-run end to end, say that the equivalence
  proof is what carries the original verification over.

## Rules

- No branch mutation before explicit user approval of the plan.
- Never publish a placeholder, mock value, or TODO that a later PR removes.
- Every PR passes the standalone test: judgeable without opening another PR.
- Every commit is complete, single-purpose, and carries its own tests.
- Readability decides the boundaries; line count is a symptom, not a target.
- Prefer curating history over splitting; prefer two PRs over five.
- Never rewrite the original branch in place — keep it until the user says so.
- Prove equivalence after any history rewrite (`git diff` against the original
  head is empty).
- Speak the user's language in discussion (中文使用者就用中文討論); the plan
  file, branch names, commit messages, and PR text stay in English.

## Mechanics that will bite

- **In a git worktree, `.git` is a file, not a directory.** `test -d
  .git/rebase-merge` silently reports "no rebase in progress" while one is very
  much in progress. Use `git rev-parse --git-path rebase-merge`.
- **Pick the rebase boundary as the commit, not the branch.** `--onto <new
  base> <old branch>` re-applies commits that are already upstream and
  conflicts against them; `--onto <new base> <that commit>^` replays only that
  commit's own work.
- **`git rebase --update-refs`** moves every branch ref that points into the
  range being replayed — essential when amending a commit that several
  branches sit on top of.
- **`gh stack link` assumes the trunk is the default branch.** It will silently
  retarget the bottom PR to `master` and inflate its diff. Use `gh stack init
  -b <trunk>` followed by `gh stack submit --auto`, and re-check the bottom
  PR's base after any stack operation.
- **GitHub refuses a base change on a linked stack member.** Unstack first,
  then retarget, then re-link.
- **`gh stack submit` pushes your *local* branches by name.** A stale local
  branch sharing a name with a remote one will clobber it. Delete every
  leftover local branch before submitting, and make local names match remote.

### Reusing an existing PR number — three ways to destroy it

A PR's head branch cannot be changed through the API, so the *only* way to
reuse a PR is to push new content to its original head branch. Three
operations kill it instead, all irreversibly — GitHub answers a reopen with
`state cannot be changed. The <branch> branch was force-pushed or recreated`:

- **Renaming the head branch.** Even though GitHub keeps a redirect and
  retargets *base* refs, the open PR is closed and cannot be reopened.
  Recreating the branch under its old name does not help. If a branch name no
  longer describes its content, live with the name or open a new PR — never
  rename to fix it.
- **Pushing before fixing the base.** If the new head content is an ancestor
  of the PR's current base, GitHub sees the head as already contained and
  auto-closes the PR. **Retarget the base first, then push.**
- **Deleting the branch**, obviously — including as a side effect of tidying
  up "surplus" branches while a PR still points at one.

Order that works: unstack → retarget every base → force-push content →
re-link → delete leftovers last.

## Field notes

- **CR-2530** (947 lines, six rungs, skeleton-first): the split did make each
  PR faster to read, and the reviewers said so. What they also said: the
  placeholders in the lower rungs forced them to keep opening the higher ones
  to check whether a problem was already solved, and automated review on the
  lower rungs produced only false alarms. The speed gained per PR was spent
  again on context switching.
- **CR-2532** (1285 lines, nine rungs, retro split): too fine. Nine PRs for a
  two-point ticket meant no rung could be judged without the ladder in mind,
  and the synthesized placeholders never existed in the real work — they were
  manufactured purely to stage the review. A retro split is exactly where
  skeleton-first has the least to offer: the architecture is already settled by
  the time you are splitting, so the skeleton buys no early feedback and costs
  the reviewer a forward lookup on every rung.
- The consistent ask across both: **整理 commit 讓 reviewer 看得出脈絡** —
  curate the commits so the narrative is visible. Reviewers already read big
  PRs commit by commit when they want the author's reasoning; a clean history
  serves that habit directly, at a fraction of the coordination cost of a
  stack.
