---
name: pr-deck
description: Produce a guided-reading deck for a PR stack before it goes to review — the business goal, the component architecture, the stack map, one slide per rung with its single purpose and review focus, and demo media captured by actually testing the acceptance criteria — authored in open-slide, delivered as Google Slides in Drive under RDD-Demo/<KEY>/, shared org-wide, URL attached to every PR in the stack. Use after a stack's draft PRs exist — "/pr-deck CR-123", "做導讀簡報", "make the review deck for this stack", "reviewer 需要導讀" — or whenever a large change needs a tour before humans review it.
---

# pr-deck — a guided-reading deck for a PR stack

A stack solves review size, not review orientation: seven small PRs still ask
the reviewer to reconstruct the whole in their head. This skill produces the
orientation — a deck a reviewer reads in 3–5 minutes before opening B0: what
the feature is for, how the components hang together, what each rung is alone
responsible for, and demo media proving the acceptance criteria against the
running app.

**This is an addition, not a requirement.** split-pr already puts the stack's
goal, the rung table, and each rung's own purpose into every PR description,
which is what makes the stack reviewable. Reach for a deck when the audience
is wider than the reviewers — QA, PM, a design check, a team demo — or when
the feature is visual enough that stills and clips carry more than prose. For
an ordinary engineering review, the descriptions are the deliverable and this
skill is skipped. Producing a deck also creates artifacts that must be
regenerated whenever the ladder changes; don't take on that upkeep without a
reason.

The deck's audience includes non-engineers (QA, PM), so the deliverable is
**Google Slides in Drive** — zero-friction inside the org's Workspace SSO —
organized one folder per big PR: everything for a stack lives under
`RDD-Demo/<KEY>/` (the ticket key of the original oversized PR).

Arguments: `[ticket-key | root PR number/url]`

Pipeline: gather → capture demos → author (open-slide) → convert (PNG →
PPTX → Google Slides) → publish to Drive → attach URLs to the PRs.

**Hard rule: the user approves the rendered deck before anything is uploaded
or any PR is edited.** Same contract as split-pr: plan and content first,
side effects only after an explicit OK.

## 0. Gather

1. Resolve the stack: from the root PR walk the base-ref chain upward (or
   `gh stack view`); collect each PR's number, title, single-purpose
   sentence, diff stat, and review-focus line from its description.
2. Read the Review Plan and AC table — `docs/plans/<KEY>/plan.md` and the
   bottom PR's acceptance-criteria section are the sources of truth.
3. Tooling check: node/npx (open-slide), `pptxgenjs` (installable ad hoc),
   a browser channel (claude-in-chrome or Playwright), and the user's Drive
   session in Chrome.

## 1. Capture demos from the acceptance criteria

The demos are evidence, not decoration — each one is produced by actually
exercising an AC against the running app.

1. Launch the app the way this repo launches it (dev server, preview build —
   follow the repo's own run conventions).
2. Walk each AC with the browser: screenshot the fulfilled state, named
   `ac<N>-<slug>.png`. For the money flow (the AC sequence a reviewer most
   needs to *see* move), record a GIF or short mp4.
3. Store under a local `deck-assets/<KEY>/` directory, and keep a map of
   AC → asset → the commit or PR that made it real (from the Review Plan).
4. **Degrade honestly**: if the environment cannot run (missing backend, no
   dev credentials), fall back to annotated code-walk screenshots and say so
   on the slide — never present a mock screenshot as a live capture.

## 2. Author the deck in open-slide

```
npx @open-slide/cli init deck-<KEY>
```

Slides are React components at 1920×1080; the user can click-edit on the
canvas and leave comments for `/apply-comment` — iterate there until the
content is approved.

Slide inventory (adjust, don't pad):

1. **Cover** — ticket, one-sentence business goal, stack badge (N PRs).
2. **Why** — the user-visible outcome in the spec's own words; what exists
   today vs. after.
3. **Architecture** — the agreed component tree and where state lives; this
   is B0's diagram, drawn once.
4. **Stack map** — the ladder table: rung, PR link, single purpose, size;
   the recommended review order.
5. **One slide per rung** — its single-purpose sentence, then the review
   question **paired with how this rung answers it**. The answer states the
   PR's actual handling, taken from the code and from decisions already
   settled in earlier review rounds; it turns an open-ended review into a
   check of a stated claim, and it stops reviewers re-opening questions the
   branch already closed. Also list what stays placeholder and which rung
   fills it, plus the demo media for the ACs it makes real.
6. **Verification** — what was run (typecheck/lint/tests per rung), and for
   retro splits the equivalence claim (top of stack vs. reference branch).
7. **How to review** — the 3–5 minute route: read B0 for architecture, then
   each rung asks one question.

Get the user's approval on the rendered deck before converting.

## 3. Convert to Google Slides

open-slide has no export — the bridge is render → image → PPTX → Drive
conversion:

1. Screenshot every slide route at exactly 1920×1080 PNG (Playwright or
   claude-in-chrome against the open-slide dev server).
2. Build a 16:9 PPTX with `pptxgenjs`: each PNG as a full-bleed background,
   and a **transparent hyperlink rectangle over every visible link target**
   (rung slide → its PR, demo thumbnail → its Drive video) so the flattened
   deck keeps its interactivity.
3. Slide N order must match the deck; verify the PPTX opens locally before
   uploading.

## 4. Publish to Drive (claude-in-chrome)

**Uploading is the step that fights back.** Drive's "New → File upload"
opens a native file dialog, which blocks browser automation outright, and
its hidden `<input type="file">` is not in the DOM (nor the a11y tree) until
that dialog is already opening — so `file_upload` has no ref to target. The
Drive API path is closed too: its create-with-content call takes base64, and
a deck is megabytes of it.

What works is Drive's own drag-and-drop handler:

1. Serve the file from a local HTTP server with
   `Access-Control-Allow-Origin: *` (Chrome treats `http://127.0.0.1` as a
   secure origin, so an https Drive page may fetch it).
2. On the Drive folder page, `fetch` it into a `File` object, put it in a
   `DataTransfer`, and dispatch `dragenter` → `dragover` → `drop` on the
   element at the centre of `[role="main"]`. All three coming back
   `defaultPrevented` is the signal Drive accepted the drop; confirm with a
   screenshot, then dispatch `dragleave` to clear the drop overlay.
3. Stop the local server as soon as the upload lands.

Then:

1. In the user's Drive, ensure `RDD-Demo/<KEY>/` exists (create the path if
   missing) — one folder per big PR; all of a stack's material lives there.
   Folder creation *is* fine through the Drive API (no content payload).
2. Upload the demo videos/GIFs first (their Drive URLs go into the PPTX's
   link overlays — capture URLs, rebuild the PPTX if placeholders were used).
3. Upload the PPTX, then open it and **File → Save as Google Slides**; the
   converted file is the canonical deck. Name both after the key:
   `<KEY> review deck`.
4. Sharing: set the **folder** to "anyone in the organization with the link
   — Viewer" (one setting covers deck + media). Never wider than the org.
5. On a later round, regenerate and replace the deck file, then re-check the
   PR links — a replaced file means a new URL; updating the links is part of
   this step, not the reviewer's problem.

## 5. Attach to the PRs

Append (never clobber) a `## Deck` section to every PR in the stack:

```markdown
## Deck
Guided reading for this stack: <slides-url> (slide <n> covers this rung)
Demo media: <folder-url>
```

The root/B0 PR also links the folder. Use `gh pr edit --body-file` with the
existing body plus the new section.

## Rules

- Nothing is uploaded and no PR is edited before the user approves the
  rendered deck.
- Demo media comes from exercising the ACs against the running app; degraded
  captures are labeled as such on the slide.
- One folder per big PR: `RDD-Demo/<KEY>/`, the whole stack's material
  together, shared org-wide read-only, never public.
- The deck orients; discussion stays on the PRs — the deck links out, it
  does not collect comments.
- Deck regeneration owns the link freshness: whoever replaces the file fixes
  every PR link in the same run.
- Speak the user's language while iterating (中文使用者就用中文討論); slide
  content, file names, and PR text stay in English.
