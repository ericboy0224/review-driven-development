# review-driven-development

A Claude Code plugin that treats **review as the unit of work**. Big PRs don't
get reviewed — they get skimmed and LGTM'd. But the fix is not "make every PR
tiny": a change chopped into many small PRs costs the reviewer more, not less,
because they must hold the whole ladder in their head to judge any one part of
it.

What is actually scarce is the reviewer's **context** — how much they can hold
at once, and how often they are forced to put it down and look somewhere else.
This plugin optimises for that, in this order:

1. **Curate the commit history** so the change can be read commit by commit.
   For most large-but-coherent work this is the whole answer.
2. **Split into a few complete PRs** only when one PR stays hard to read even
   with a clean history.
3. **Never publish scaffolding.** No placeholder bodies, no mock values, no
   TODOs that a later PR removes. A reviewer who meets one has to go read the
   later PRs to find out whether it is a real defect — and an automated
   reviewer just reports it as a finding.

Line count is a symptom, never a target.

## The skills

| Skill | Role |
| --- | --- |
| `split-pr` | Make a large change readable. Discuss the component architecture from the business goal down, then curate the commit history into a bottom-up narrative — and only if that is not enough, cut it into a small number of complete, self-contained PRs. Produces a `## Review Plan`. |
| `pacer` | Pair-run (陪跑) the implementation — skeleton first, placeholders down, one layer at a time, with a hard discussion checkpoint at every boundary. Skeleton-first is how the work is *built*; the placeholders are folded away before anything is published. |
| `validate-stack` | The mechanical sweep over a multi-PR stack: base chain, membership, per-rung build, equivalence with the branch it replaced, and table drift across PR bodies. Also flags any placeholder that reached a PR, and whether the stack is earning its coordination cost. |
| `stacked-prs` | The `gh stack` mechanics: create, link, rebase, repair, and merge a chain of PRs. |
| `pr-deck` | **Optional.** For audiences wider than the reviewers (QA, PM, a demo), a guided-reading deck delivered as Google Slides. Ordinary reviews need only the PR descriptions split-pr writes. |

## The flow

```
spec.md + plan.md          (however you produce them)
        │
        ▼
/split-pr <KEY>            architecture discussion → ## Review Plan in plan.md
        │
        ▼
/pacer <KEY>               implement layer by layer on one branch,
        │                  checkpointing at every boundary
        ▼
re-cut the history         bottom-up, complete commits, placeholders folded
        │                  away, equivalence proved
        ▼
one PR (usually)           curated history, read commit by commit
   or a few complete PRs   only when one is still too much to hold
        │
        ▼
/validate-stack            structural sweep — only when there is a stack
        │
        ▼
/pr-deck <KEY>             optional: a deck for wider audiences
```

Each skill also works standalone.

## Field notes

The bands this plugin used to enforce (<100 ideal, 400 ceiling) came out of
two experiments, CR-2530 and CR-2532. Both confirmed that smaller PRs read
faster individually — and both were rejected by reviewers for the same reason:
the lower rungs carried placeholders, so every finding required a forward
lookup into the higher rungs to check whether it was already solved. The time
saved per PR was spent again on context switching, and automated review on the
lower rungs produced only false alarms.

The consistent ask was **整理 commit 讓 reviewer 看得出脈絡** — curate the
commits so the narrative is visible. Reviewers already read big PRs commit by
commit when they want the author's reasoning; a clean history serves that habit
directly, at a fraction of the coordination cost of a stack.

## Install

```
/plugin marketplace add plaxieappier/review-driven-development
/plugin install review-driven-development@review-driven-development
```
