---
name: demo-reel
description: Record one annotated walkthrough GIF of a feature — an in-page caption bar labels every scene with the requirement it demonstrates ([Loading], [Hover], [Warning], …), captured by exercising the running app with claude-in-chrome, delivered to Drive under RDD-Demo/<KEY>/ and linked from the PR. Mandatory when a reviewer cannot reach the feature in three steps from the app's entry point; the lightweight alternative to pr-deck otherwise. Use when the user wants demo material — "錄 demo", "製作 demo 素材", "框出、解釋對應的需求", "annotated walkthrough", "不用 deck,用一段影片說明" — when sprint's closeout triggers the demo obligation, or when a pr-deck feels like too much ceremony for a single PR.
---

# demo-reel — one annotated walkthrough instead of a deck

A deck orients a reviewer across many PRs; most single PRs don't need that.
What they need is proof: the feature moving, with each moment labeled by the
requirement it fulfills. This skill produces exactly one artifact — a GIF (or
short video) where a caption bar names every scene — so a reviewer, QA or PM
watches 30 seconds and knows what was built and why.

**The reviewer is the first audience, not the wider one.** When the change
sits behind a flow they cannot reach — a dialog that opens only after an
upload lands, a state that needs backend data they cannot produce — the clip
is the only way they see the feature at all, and without it they review the
diff and miss everything that is only visible on screen. `sprint` §5 makes
this call by counting steps from the app's entry point; more than three, or
any step needing data the reviewer cannot make, and this skill is not
optional. QA and PM are a bonus audience for the same artifact.

Reach for pr-deck instead when the audience must navigate a *stack* (rung
map, review order, per-rung questions). Reach for demo-reel when one clip
carries the story. Producing both is almost never worth the upkeep.

Arguments: `[ticket-key]` — resolves the spec/AC list via the cs-jira
convention (`docs/specs/<KEY>/spec.md`) when present.

## 0. Agree the scene list first

Ask the user for (or propose from the ACs) a **labeled checklist** — one
scene per requirement, each with a short tag and a one-line explanation:

```
[Loading]      advising tab spins; content area is one loading sheet
[Hover]        tab hover card: thumbnail, full name, kind
[Fill: Blur]   safe-area kept; overflow ghosts; blur fills the gaps
[Pill toggle]  ratio groups with unread dots; opening clears them
[Zoom in/out]  fixed steps; overflow scrolls
[Warning]      advisor failed: whole-frame resize + one-time hint
[Fill: Color]  sampled color fills the gaps
```

The user approves this list before anything is recorded — it is the storyboard
and the definition of done. Every scene's caption starts with its `[Tag]`.

## 1. Stage the app

1. Launch the app the way the repo launches it (its own dev conventions).
2. **Fix the window size before recording** (`resize_window`) — coordinates
   drift with every resize, and a mid-recording resize ruins the frames.
3. If the flow needs backend state that isn't available, stage **dev-only
   fake data**, and treat it as radioactive:
   - Mark the block `dev-only … must never be committed`, keep it unstaged,
     and record a **pre-PR gate** in the plan: revert + `grep dev-only`
     returns nothing.
   - **Fake data must obey the domain's own rules.** A record that
     contradicts the business logic (e.g. "the advisor failed" *and* "the
     advisor returned a crop") produces a demo that demonstrates something
     false — reviewers will trust the clip over the code. Derive each fake
     record from a real, reachable state.
4. Reload once before recording so per-session state (hints, read marks) is
   fresh — a stale flag silently skips a scene.

## 2. Inject the caption bar

Captions live **in the page**, not in post-production, so every frame carries
its label for free:

```js
window.__caption = (text) => {
  let bar = document.getElementById('__demo-caption');
  if (!bar) {
    bar = document.createElement('div');
    bar.id = '__demo-caption';
    Object.assign(bar.style, {
      position: 'fixed', top: '0', left: '0', right: '0', zIndex: '99999',
      background: 'rgba(0, 10, 58, 0.92)', color: '#fff',
      font: '600 20px/1.5 "Open Sans", sans-serif', padding: '12px 24px',
      textAlign: 'center', letterSpacing: '0.3px',
    });
    document.body.appendChild(bar);
  }
  bar.textContent = text;
};
```

Injected via `javascript_tool` after load; call `window.__caption('[Tag] …')`
before each scene's actions. The bar survives everything except a reload.
Write captions in the audience's language.

## 3. Record

With claude-in-chrome's `gif_creator`:

1. Set the first scene's caption, `start_recording`, then screenshot
   immediately — that screenshot is the first frame.
2. Per scene: update the caption (JS, costs no frame) → perform the scene's
   actions (`computer` clicks/hovers/scrolls are each captured) → screenshot
   if the resting state matters.
3. Screenshot the final state, `stop_recording`, then `export` with
   `download: true` and `showActionLabels: false` — the captions carry the
   meaning; the tool's own labels are noise. Keep click indicators.
4. Budget: max 50 frames. A 7-scene walkthrough lands around 25. If a scene
   goes wrong, `clear` and re-record the whole thing — frames are cheap,
   patching a bad take is not.
5. Timed UI needs pacing: a hint that auto-dismisses in 5s must be captured
   in the same batch as the action that raised it.

Collect the download into `deck-assets/<KEY>/` (untracked, never committed).

## 4. Deliver

1. Drive folder `RDD-Demo/<KEY>/` — create via the Drive API (folders are
   fine there; content uploads are not).
2. Upload the GIF with the **drag-and-drop handler trick** from pr-deck §4:
   serve the file from a local CORS server on `127.0.0.1`, `fetch` it into a
   `File`, dispatch `dragenter → dragover → drop` on the centre of
   `[role="main"]` on the Drive folder page; all three `defaultPrevented`
   means Drive took it. Screenshot to confirm, `dragleave` to clear the
   overlay, kill the server.
3. Link it from the PR body under a `## Demo` section placed **at the very
   top of the body** — the demo is the first thing a reviewer should meet.
   Rewrite the body to move it there if it exists elsewhere; never clobber
   other sections.
4. Sharing follows pr-deck's rule: folder visible to the org at most, never
   public.

## Rules

- The user approves the scene list before recording, and the exported GIF
  before it is uploaded or linked anywhere.
- Every scene's caption starts with its `[Tag]` from the agreed checklist —
  an unlabeled scene is a missing scene.
- Fake data must be domain-consistent, dev-only, and reverted before any PR;
  the revert is a named gate, not a memory.
- Degrade honestly: if the app can't run a scene, say so — never fake a
  capture.
- Re-record over patching; `clear` costs nothing.
- Speak the user's language while iterating; captions in the audience's
  language; file names in English.
