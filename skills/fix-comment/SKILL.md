---
name: fix-comment
description: Answer the review comments on a PR one at a time — read what the comment actually claims, check its premise against the design or spec before touching anything, fix it, then sweep the whole PR for the same class of problem so the reviewer never has to write that comment twice, and reply in one Simple English sentence naming the commit. Routes each comment to the skill that owns its dimension: naming and copy to simple-english, architecture to vercel-composition-patterns and the client-side architecture reference, performance to vercel-react-best-practices. Use when a PR has review feedback to work through — "處理 review comments", "fix the review comments", "回覆 reviewer", "/fix-comment 143" — or after /fe-review or a human review leaves threads open. Never resolves a thread.
---

# Fix-comment — one comment, its whole class, one sentence back

A reviewer who writes the same comment twice in one PR has been made to do the
author's work. Most review comments are not one defect: they are one *instance*
of a habit that the diff repeats somewhere else. Fixing only the flagged line
sends the PR back for a second round on the same subject, and it teaches the
reviewer that reading carefully costs them more comments.

So every accepted comment here produces two things: the fix, and a sweep of the
rest of the PR for the same class. The sweep is the deliverable that makes this
skill worth running instead of patching lines by hand.

Arguments: `[pr-number | pr-url]` — default: the PR whose head is the current
branch.

## 0. Intake

1. Resolve the PR (`gh pr list --head "$(git branch --show-current)"` when no
   argument is given).
2. Fetch every thread with its code context — the REST comment list drops the
   resolved flag, so use GraphQL:

   ```bash
   gh api graphql -f query='
   query($owner:String!,$repo:String!,$pr:Int!) {
     repository(owner:$owner,name:$repo) { pullRequest(number:$pr) {
       reviewThreads(first:100) { nodes { id isResolved isOutdated path line
         comments(first:20) { nodes { databaseId author{login} createdAt body diffHunk } } } } } }
   }' -F owner=... -F repo=... -F pr=...
   ```

3. Separate the author's own annotation threads (guided-reading notes) from
   reviewer feedback. Only the reviewer's threads are work.
4. Compare each thread's timestamp against `git log` — a thread older than the
   commit that already answered it needs a reply, not a fix.

**Never resolve a thread.** Resolving is the reviewer's signal that they are
satisfied. Treat `isResolved` as read-only, reply instead, and let the reviewer
close it. Do not offer to resolve threads either.

## 1. Classify, then route

Read the comment and its `diffHunk`. Name the dimension before writing code,
because the dimension decides which skill answers it:

| Dimension | Routed to | Typical comment |
| --- | --- | --- |
| Naming, comments, copy, prose | `simple-english:simple-english` | "看不出他想表達什麼", "命名像個 variable", a message that reads wrong |
| Architecture, composition, state placement, module boundaries | `vercel-composition-patterns` + `${CLAUDE_PLUGIN_ROOT}/skills/blueprint/references/client-side-architecture.md` | "考慮抽出來嗎", "改 type 嗎", "這個 state 放這裡對嗎" |
| Performance, renders, bundle, memoization | `vercel-react-best-practices` | "每次呼叫都算一次", "這個會 re-render 全部" |
| Correctness and behaviour | the running app (`run` skill or the project's dev server) | "worth checking: …", an a11y or state defect |
| Test intent | the test file itself | "這是要測什麼", "需要重複嗎" |

Load the routed skill for the *reasoning*, not for a rewrite of everything it
touches. A comment about one name does not license renaming the module.

## 2. Check the premise before touching anything

A comment can be right about the defect and wrong about the remedy, and an
agent that skips this step invents work the design never asked for.

- **User-facing copy, UI structure, or behaviour** — read the design source
  first (the Figma node, the spec, the ticket). Never invent a user-facing
  string. If the design defines one message, the fix belongs in the state
  behind it, not in new copy.
- **A reviewer offering two routes** — the design or spec picks between them.
  Say which one you took and why, in the commit body.
- **A claim about a library's behaviour** — verify it in
  `node_modules`. Prop documentation and prop implementation disagree often
  enough that "the doc says contained-only" is not a reason to skip a fix.
- **A behaviour or spec question** (should zoom reset, should this warn) — ask
  the user with AskUserQuestion. Never settle a product question silently.

If the premise fails, reply with the fact instead of a fix. A thread that ends
in a correct explanation is finished work.

### "Unreachable by construction" is a fix, not a refusal

The most tempting wrong answer is the one that is *true*: the reviewer flagged
a case the callers cannot currently produce, so nothing needs to change. The
argument holds and the refusal still fails, because the fact it rests on —
the accept list two modules upstream, the filter the other branch applies —
**is not visible at the line the reviewer read**. The next reader arrives with
exactly the reviewer's information and asks the same question, and the caller
that eventually can produce the case arrives with no warning at all.

So when the reason for not fixing is a fact outside the flagged line, the fix
is to bring the fact to the line: a `throw` on the input that "cannot happen",
a type that makes it unrepresentable, a guard at the boundary that documents
itself. Say so in the reply — the reviewer was right that the code does not
say this.

Two reviewers raising the same point independently settles it on its own. A
premise invisible to two readers is invisible, and the second flag converts
any standing refusal into a fix without further argument.

## 3. Sweep the class (the step that earns this skill)

For every accepted comment, search the PR's own diff — not the whole repo — for
the same class of problem, and fix every instance in the same commit. The
reviewer flagged the one they happened to read.

```bash
git diff --name-only origin/<base>...HEAD   # the sweep's boundary
```

Recipes per class are in
`${CLAUDE_PLUGIN_ROOT}/skills/fix-comment/references/sweep-recipes.md`. The
sweep's result belongs in the commit body: which instances were found, and that
the sweep ran when only one existed.

A class that appears three or more times in one PR is a planning lesson, not a
review comment. Append it to `~/.claude/plan-lessons.md` following that file's
own protocol, so the next ticket starts from it.

## 4. Fix, verify, commit

- One story per commit, `conventional-commits` for the message. A commit body
  that needs an "and" between two classes means two commits.
- Toolchain gate before every commit: the project's type-check, lint, and tests.
- **Visual or interactive changes are verified in the running app**, not by the
  toolchain. Swapping a hand-rolled control for a design-system component
  changes the pixels: a component's own reset can beat a project class on equal
  specificity, and the reviewer will see it before you do.
- Keep local-only scaffolding out of the commit. When a dev-only harness lives
  in a file you must edit, write the clean version, stage it, commit, then
  restore the harness in the working tree.
- Push before replying, so every hash in a reply resolves.

## 5. Reply — one sentence, Simple English

Load `simple-english:simple-english` and write **one sentence per thread**,
maximum. The reviewer is reading twenty of these.

- A fix: `Fixed in <hash>` plus the substance, in the same sentence.
  *"Fixed in `b864771` with `sourceList.at(0)`, so the type admits the
  `undefined` that the guards already expect."*
- A rename or removal: name the new state.
  *"Renamed in `9b67ddd` to `findLargestFittingSize`."*
- An answer with no code change: state the fact.
  *"The second caller is `preMatchResizeTargets` in CR-2532, which is not
  merged into the feature branch yet."*
- A question whose answer is "no": answer first, then the fact.
  *"No: the box draws `mediaInFrame`, the region the target keeps, which is
  larger than the `safeArea` of the advisor on one axis."*

Rules that keep the sentence useful: name the symbol, never "the flag" or "the
state"; no semicolons; no hedging; no apology; no restating the comment back.
When a reply needs a second sentence, the extra sentence is usually a decision
that belongs in the commit body or in a question to the user.

A reply that describes a fix you later replace is worse than no reply. Delete it
(`gh api -X DELETE repos/{owner}/{repo}/pulls/comments/{id}`) and post the
corrected one, rather than stacking a contradiction under the reviewer's
comment.

## 6. Close out with the user

Report, grouped:

1. **Fixed and replied** — one line each, with the hash.
2. **Answered only** — the threads where the premise failed or the answer was
   already in the code.
3. **Waiting on you** — every behaviour or spec question, and every finding
   whose fix is larger than the comment (a type reshape, a component split).
   These are decisions, not backlog: put each one as a question with your
   recommendation.

Never report a thread as handled because a reply was posted. A reply is the
receipt, not the work.
