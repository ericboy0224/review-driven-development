# review-driven-development

A Claude Code plugin that treats **review as the unit of work**. Big PRs don't
get reviewed — they get skimmed and LGTM'd. This plugin makes every branch
small enough to be reviewed in minutes, by design rather than by discipline:

- **< 100 lines** — ideal: minimal mental load, precise feedback in minutes.
- **200–400 lines** — the ceiling for one self-contained change.
- **> 400 lines** — danger zone: reviewer fatigue, rubber-stamp approvals.

## The three skills

| Skill | Role |
| --- | --- |
| `split-pr` | Plan the split. Right after a spec & plan exist, discuss the component architecture from the business goal down, then cut the work into a skeleton-first ladder of single-purpose branches. Also retro-splits an oversized existing branch into a stack. |
| `pacer` | Pair-run (陪跑) the implementation branch by branch — skeleton first, placeholders down, one layer at a time, with a hard discussion checkpoint at every boundary. |
| `validate-stack` | The mechanical sweep over an existing ladder: base chain, stack membership, per-rung build, placeholder-marker census, sizes, equivalence with the branch it replaced, and table drift across PR bodies. Run it after any fold, rebase, or trunk move — that is where stacks break silently. |
| `stacked-prs` | The `gh stack` mechanics: create, link, rebase, repair, and merge the chain of PRs the other skills produce. |
| `pr-deck` | **Optional.** For audiences wider than the reviewers (QA, PM, a demo), a guided-reading deck — business goal, architecture, stack map, one slide per rung, AC-tested demo media — authored in open-slide, delivered as Google Slides under `RDD-Demo/<KEY>/`, shared org-wide, linked from every PR. Ordinary reviews need only the PR descriptions split-pr writes. |

## The flow

```
spec.md + plan.md          (however you produce them)
        │
        ▼
/split-pr <KEY>            architecture discussion → ## Branch Plan in plan.md
        │
        ▼
/pacer <KEY>               implement branch by branch, gh stack add per layer
        │
        ▼
/validate-stack            structural sweep — rerun after any fold or rebase
        │
        ▼
gh stack submit            one small, single-purpose PR per branch,
                           each carrying the stack's goal and its own
        │
        ▼
/pr-deck <KEY>             optional: a Google Slides deck for wider audiences
```

Each skill also works standalone.

## Install

```
/plugin marketplace add ericboy0224/review-driven-development
/plugin install review-driven-development@review-driven-development
```
