# Client-side architecture checklist

Distilled from Khalil Stemmler's client-side architecture guide
(https://khalilstemmler.com/articles/client-side-architecture/introduction/).
The premise: frameworks rotate, but separation of concerns does not. A plan
that puts each concern in its own layer stays cheap to change for the life of
the code; a plan that mixes them is the "enormous mess" every undisciplined
React codebase converges to.

Audit the plan against each question below. Report only failures, at most 5,
prioritized by how expensive the mix-up becomes after implementation. Every
finding names the plan step it targets and the one-line plan edit that fixes
it. Findings that require touching code the plan does not already touch are
out of scope — discard them.

The layer table below is also the organizing frame of blueprint's visual
artifact (§4): the audit and the artifact describe the plan in the same
language, so a reader moves between them without translating.

## The layers

| Layer | Owns | Must not own |
| --- | --- | --- |
| Presentation | Rendering props to UI | Fetching, business rules, cross-component state |
| Interaction | Event handlers, controllers — deciding *what happens* on user action | Rendering detail, transport detail |
| State | The app's data: local UI state, remote (server-cache) state, shared state | Transport, rendering |
| Domain | Client-side business rules (validation, derivation, eligibility) | Framework types, fetching |
| Infrastructure | API clients, caches, storage, transport | Business rules, UI decisions |

## 1. Layer separation

- [ ] Every planned component, hook, and module sits in exactly one layer.
      A piece the plan describes with "and" across layers ("fetches and
      renders", "validates and submits") is two pieces.
- [ ] Presentational components receive props and render; they contain no
      fetching, no business rules, and no knowledge of where data came from.
- [ ] Container/interaction pieces own state and handlers and delegate all
      rendering to presentational children.
- [ ] Domain logic (validation rules, derivations, eligibility checks) lives
      in pure functions or plain modules — testable without a framework, in
      a Node-only test runner.
- [ ] Nothing above the infrastructure layer names a transport (URL, HTTP
      verb, GraphQL document, storage key).

## 2. State placement

- [ ] Every piece of state the plan introduces is typed: **local UI**
      (one component's ephemeral state), **remote** (server-owned, cached),
      or **shared** (client-owned, crossing a subtree).
- [ ] Remote state lives in the server-cache tool the repo already uses
      (Apollo cache, React Query, SWR) — never copied into component state
      or a global store "for convenience".
- [ ] Local UI state stays in the component that owns it; it is not lifted
      "in case someone needs it later".
- [ ] Shared state is scoped to the smallest subtree that needs it (context
      at the subtree root) before any global store is considered.
- [ ] State mutations follow one consistent pattern per state type — no
      plan step that updates the same data two different ways.

## 3. State shape (can the type say something false?)

A type that lists fields describes storage. A type that lists states describes
the thing. When the plan writes the first for something that is the second, the
compiler stops being able to help, and every reader pays in null checks.

- [ ] For each piece of state, the plan says how many **distinct states** it
      passes through in its life, and which fields exist in each one.
- [ ] A field that exists in some states only is modelled as a member of a
      **discriminated union**, not as a nullable field beside a `status`,
      `phase`, `kind` or `step` field. Those two facts moving independently is
      the signature of this defect: `{ status: 'ready', fill: null }` type-checks
      while being a state that must never exist.
- [ ] No invariant in the plan is written as prose that only one function keeps
      ("a settled source always has a fill"). Either the type carries it, or the
      plan names the one function that does and every reader that trusts it.
- [ ] A plan step that introduces a status field with dependent fields carries
      the union in the plan text, before the code exists. The same change costs
      one sentence here and a review round plus a type reshape later.

The four marks this defect leaves in a diff, useful when auditing existing code
rather than a plan — each one is a symptom, not the cause:

| Mark | What it is compensating for |
| --- | --- |
| `?.` on a field inside a branch that already excludes the empty case | the type does not know the branch narrowed anything |
| `NonNullable<>` or an intersection type re-tightening a field | one kind of value needed its own type all along |
| A hand-written `is` predicate over a discriminant | the discriminant would narrow on its own in a union |
| `as SomeType` in a fixture | the fixture cannot be built from the real type, because the real type is looser than reality |

## 4. Interaction logic

- [ ] State changes are owned by named event handlers, not effects reacting
      to renders. An effect the plan keeps must carry its justification.
- [ ] Each user-facing flow in the plan can be traced in one direction:
      user action → handler → state change → render. A flow the plan cannot
      state in that order is a finding.
- [ ] Async flows plan their loading and error states up front, not as a
      follow-up.

## 5. Infrastructure

- [ ] API access goes through the repo's existing clients and wrappers; the
      plan creates no parallel client for an endpoint family that has one.
- [ ] Errors cross the infrastructure boundary typed and specific — no plan
      step that swallows an error or generalizes it into a vague message.

## 6. Testability (the design smell detector)

- [ ] The plan's business logic is stated so it could be tested as pure
      functions — inputs and outputs, no rendering required. If a rule can
      only be tested by mounting a component, it is in the wrong layer.
