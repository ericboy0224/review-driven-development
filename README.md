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
| `conventional-commits` | The message format every commit in this flow uses: `<type>(<scope>): <description>`, the type-choice ambiguities resolved, and when a message needing an "and" means the commit should be split. Loaded automatically whenever a commit message is being written. |
| `blueprint` | **Optional.** Optimize a finished plan before any code exists: audit the planned client-side architecture (layer separation, state placement, composition — with the vercel-composition-patterns / vercel-react-best-practices skills), search every registry the plan could have reused from instead of building, ask what breaks if each proposed layer were deleted, make the plan declare the facts it takes from outside the repo, fix one word per domain concept and rewrite the rest with simple-english, discard everything outside the ticket's scope, and publish a visual artifact organized by the client-side architecture layers (layer map, composition, data flow — in English). Writes `## Blueprint Notes` and its glossary, which bind sprint's subagents and are verified at sprint's integration step. |
| `split-pr` | Make a large change readable. Discuss the component architecture from the business goal down, then curate the commit history into a bottom-up narrative — and only if that is not enough, cut it into a small number of complete, self-contained PRs. Produces a `## Review Plan`. |
| `sprint` | Execute a finished plan to completion as fast as possible, subagent-driven: decompose into file-disjoint work units, dispatch parallel implementer subagents in dependency-ordered waves, verify every wave, then run the review gate — a lifecycle audit by inventory, a correctness review, fe-review, and the feature exercised in the running app — and the closeout deliverables. One hard stop, at closeout — the human review lives in `blueprint` (before) and the closeout conversation (after), not in mid-flight checkpoints. Replaced `pacer` (retired 2026-08-24). |
| `fix-comment` | Work through a PR's review comments: read what each one claims, check its premise against the design before touching anything, fix it, then sweep the whole PR for the same class so the reviewer never writes that comment twice — and reply in one Simple English sentence naming the commit. Routes naming to simple-english, architecture to vercel-composition-patterns, performance to vercel-react-best-practices. Treats "unreachable by construction" as a fix rather than a refusal. Never resolves a thread. |
| `validate-stack` | The mechanical sweep over a multi-PR stack: base chain, membership, per-rung build, equivalence with the branch it replaced, and table drift across PR bodies. Also flags any placeholder that reached a PR, and whether the stack is earning its coordination cost. Ships `validate-history.sh` for the single-PR case: after a history re-cut, proves every commit builds on its own and carries no markers — the path, not just the end state. |
| `stacked-prs` | The `gh stack` mechanics: create, link, rebase, repair, and merge a chain of PRs. |
| `pr-deck` | **Optional.** For audiences wider than the reviewers (QA, PM, a demo), a guided-reading deck delivered as Google Slides. Ordinary reviews need only the PR descriptions split-pr writes. |
| `demo-reel` | One annotated walkthrough GIF instead of a deck: an in-page caption bar labels every scene with the requirement it proves, uploaded to Drive and linked at the top of the PR body. **Mandatory** when a reviewer cannot reach the feature within three steps of the app's entry point — sprint's closeout counts them; optional and lighter than a deck otherwise. |
| `cold-review` | Simulate the reviewer before the reviewer pays: three fresh `opus` subagents in parallel, each with no ticket, spec, plan, PR body or memory — one narrates the diff commit by commit and lists every place it had to guess, one reads it three months out (what the next change breaks, what the repo already had, one concept under two words), one walks data end to end to see whether the pieces trust each other. The owner marks each wrong sentence and guess, routes it to one of three levers — naming, readable architecture, injected side effects — fixes the class, and a NEW reader runs until a stranger's narration matches. The narration that passes becomes the PR body's reading guide. Correctness stays with the owner; the reader is a learner, as the human reviewer is. |

## The flow

```
spec.md + plan.md          (however you produce them)
        │
        ▼
/blueprint <KEY>           plan-stage architecture + naming audit,
        │                  scope-walled, ending in a visual artifact —
        │                  this is where the user reviews the design
        ▼
/sprint <KEY>              subagent-driven implementation in parallel waves,
        │                  review gate at the end, one hard stop at closeout
        ▼
re-cut the history         bottom-up, complete commits, placeholders folded
        │                  away, equivalence proved
        ▼
/cold-review               a fresh reader with no ticket narrates the diff;
        │                  wrong sentences and guesses are fixed by lever
        │                  until a stranger gets it right — its narration
        │                  becomes the PR body's reading guide
        ▼
one PR (usually)           curated history, read commit by commit
   or a few complete PRs   only when one is still too much to hold
        │
        ▼
/validate-stack            structural sweep — only when there is a stack
        │
        ▼
/pr-deck <KEY>             optional: a deck for wider audiences
   or /demo-reel <KEY>      optional: one labeled walkthrough clip instead
        │
        ▼
/fix-comment <PR>          review lands: fix each comment, sweep the PR for
                           the same class, reply in one sentence, never resolve
```

Each skill also works standalone.

## Field notes

### cold-review, first run (CR-2537, 2026-09-06)

Three lanes, one round each on a ~1800-line, 13-commit rung, all readers on
the same model. What each lane returned:

- **Today**: zero wrong sentences in two rounds. Ten in-code guesses in round
  one, six of them closed by one naming commit; four residual in round two.
  The skeleton commit that "would be curated away at closeout" cost the
  reader four stumbles on its own — it built a model of a design the branch
  had already deleted.
- **Future**: one real defect (a url basename sent back as a file id without
  decoding; a filename with a space made every dialog save fail — confirmed
  on staging), one reinvented poll loop beside the helper the dialog already
  used, and a drift list the owner acted on. The "facts outside the
  repository" list went straight into the PR body's risk section.
- **One author**: the dialog files and the run they borrowed from read as one
  hand; the upload path and the dialog path disagreed at every hand-off on
  the same wire facts (validate-or-trust the tag builder, one failure
  taxonomy or three, four outcomes for one empty basename).

What cold-review did not catch, by design: the change's headline acceptance
criterion did not hold on a real upload, and the reader had called the code
"deliberate" with good evidence. Deliberate is not right. Correctness stayed
with the owner and the running app.

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

### What the reviewers actually kept saying

The mechanisms added in 2026-08 come from reading all 148 threads four
reviewers opened on 39 PRs between June and August 2026, each sorted into one
class. The five largest were naming (21), rebuilding something that already
existed (18), async lifetime defects (17), surplus abstraction (16), and state
shape or placement (14). Together, 58% of everything a reviewer had to write.

Three of those had no mechanism at all. The reuse audit opened two drawers and
fifteen of the eighteen misses were in the other three. Nothing anywhere asked
whether a proposed layer earns its place — both pattern skills look for
structure that is missing, never structure that is surplus. And twelve threads
turned on a fact about somebody else's system that no closed-world audit could
have reached: a retired service, legacy rows that never existed, a library prop
whose docs contradict its source.

Two things the data argued *against* changing. **Line-count bands stay gone**:
among PRs that were actually reviewed, thread density does not track size —
1.35 per 100 lines under 600, 1.63 between 600 and 1500, 1.81 above. The one
real outlier, a 4269-line PR across 26 files, drew seven threads that all
landed on the two files a reader opens first, and was then closed. That is a
threshold in novelty and file count, not a gradient in lines. **And reply
length was fine**: a 113-character median answer to a 60-character median
question, with a long tail that was mostly load-bearing.

The habit that did not survive is inline self-annotation. Fifty-four threads
opened on one's own diff to explain how to read it drew four replies. The
reading route moved to the PR body, and the effort moved to `demo-reel`, since
the reviewers' unmet need turned out to be reaching the feature at all.

## Install

```
/plugin marketplace add ericboy0224/review-driven-development
/plugin install review-driven-development@review-driven-development
```
