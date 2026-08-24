# Sweep recipes — finding the rest of the class

One review comment is one instance. These recipes find the others inside the
PR's own diff, so the reviewer never writes the same comment twice.

Set the boundary first — the sweep covers the files this PR touches, never the
repo:

```bash
BASE=$(gh pr view --json baseRefName --jq .baseRefName)
FILES=$(git diff --name-only "origin/$BASE...HEAD" | grep -E '\.tsx?$')
```

Then run the recipe for the class the comment belongs to. Every recipe below is
`grep` over `$FILES`; read each hit before changing it, because a hit is a
candidate, not a verdict.

---

## Hand-rolled instead of existing

**Comment shape:** "怎麼不用 DS 元件？", "clsx?", "這個 repo 不是有 helper 嗎"

```bash
grep -nE '<(button|input|select|textarea|dialog)[ >]' $FILES        # raw elements
grep -nE 'className=\{(\[|`)' $FILES                               # hand-joined classes
grep -nE 'style=\{\{ *(gridArea|display: .flex)' $FILES            # literals a helper should name
```

Before replacing an element with a design-system component, read the
component's own styles: a forced reset (`background-color: transparent`,
`border: none`) wins over a project class on equal specificity, so the design's
look needs `&&` or the swap silently flattens the UI. Verify in the app.

Check that the helper you reach for is already a dependency and already used
elsewhere in the repo — `grep -rn "from 'clsx'" src | head`. If it is not, the
comment is a proposal to discuss, not a fix to apply.

## Type says one thing, code says another

**Comment shape:** "從型別看來 X 是一定會有的", "這裡不用判斷吧"

```bash
grep -nE '\[[0-9]+\]|\[[a-z]+\.length - 1\]' $FILES     # unchecked index access
grep -nE '\?\.|!== undefined|!= null' $FILES            # guards that may be dead
grep -rn 'noUncheckedIndexedAccess' tsconfig.json       # is the index even checked?
```

Without `noUncheckedIndexedAccess`, `list[0]` types as present while the code
around it keeps guarding. `.at(0)` / `.at(-1)` return `T | undefined` and make
the guard the type's requirement. Sweep every index in the diff, not only the
flagged one — the same file usually has two or three.

## The same rule written twice

**Comment shape:** "same as X ? 考慮共用嗎"

```bash
grep -nE 'Math\.(min|max)\(' $FILES                     # fit / clamp rules
grep -nE '(width|w) / .*(height|h)' $FILES              # ratio math
grep -noE '\b[A-Z_]{4,}\b' $FILES | sort | uniq -c | sort -rn | head   # repeated literals
```

Two copies of a formula whose whole job is to keep two subsystems agreeing (the
preview and the payload, the client and the server) is the highest-value share
in a PR. Name the shared function after the rule, not after either caller.

## Dead surface

**Comment shape:** "為何要從這邊 export？"

```bash
for f in $FILES; do
  for sym in $(grep -oE '^export (function|const|type|interface) [A-Za-z_]+' "$f" | awk '{print $NF}'); do
    n=$(grep -rn "\b$sym\b" src | grep -v "^$f" | grep -v '\.test\.' | wc -l)
    [ "$n" -eq 0 ] && echo "UNUSED $f -> $sym"
  done
done
```

Re-exports added "for convenience" and never imported are the common case.
Delete rather than justify.

## Invented user-facing text

**Comment shape:** a message that overstates, or copy nobody designed

```bash
grep -nE '"[A-Z][^"]{20,}"|'"'"'[A-Z][^'"'"']{20,}'"'"'' $FILES | grep -viE 'aria-|data-|className|import'
```

Every string a user reads must trace to the design or the spec. List the strings
the PR adds and check each one against the design source. If the design defines
one message and the code has three, the extra two are the defect — not the
copy's wording.

## The type can say something false

**Comment shape:** "考慮改 type 嗎？like `{ status: 'a' } | { status: 'b'; … }`",
"這裡不用判斷吧", a branch that narrows nothing

```bash
grep -nE "status:|phase:|kind:|step:" $FILES                    # the discriminant
grep -nE "\?\.\w+|NonNullable<|as [A-Z]\w+|is [A-Z]\w+ =>" $FILES   # its four compensations
```

A `status` field beside fields that are nullable only in some of those states
lets the type describe a state that must never exist — `{ status: 'ready', fill:
null }` type-checks. The reviewer usually flags one of the four marks below;
sweep for the other three in the same pass, because they all compensate for the
same missing union:

| Mark | Compensating for |
| --- | --- |
| `?.` inside a branch that already excludes the empty case | the branch narrowed nothing |
| `NonNullable<>` or an intersection re-tightening a field | one kind of value needed its own type |
| A hand-written `is` predicate over a discriminant | a union would narrow on its own |
| `as SomeType` in a test fixture | the real type is looser than reality |

The fix has two steps, and the first one is separately readable: write the state
whole instead of field by field (`map.set(key, {...})` rather than four
assignments), then split the type into a union. Under immer, field assignment
across variants is a compile error, which is the point.

**After the union lands**, prove that no compensating guard survived it. This
needs no change to the repo's config:

```bash
npx eslint --rule '{"@typescript-eslint/no-unnecessary-condition":"error"}' $FILES
```

It reports every `?.` and every condition the type says can only go one way —
`Unnecessary optional chain on a non-nullish value`. Two limits, both measured:
the project must already set `parserOptions.project`, or the rule has no type
information to work from; and the rule **cannot find the loose type itself**.
Before the union, `fill?.style` against `fill: Fill | null` is legitimate as far
as the type knows, and the rule stays silent — it verifies the cleanup, it does
not detect the class. The detector is the reviewer, or the plan.

This class belongs to the plan stage. When it appears, `blueprint`'s state-shape
audit is where it costs one sentence instead of a type reshape — record it in
`~/.claude/plan-lessons.md`.

## Names that describe the wrong thing

**Comment shape:** "確認一下，X 和 Y 是一樣的嗎？"

Names in this class cannot be grepped; the question in the comment is the
detector. When a variable is named after concept A but assigned from concept B,
check whether the *value* is wrong before renaming — a misnamed variable often
hides a wrong value, and renaming it would cement the bug. Ask the user when the
answer depends on the design.

After a rename, sweep for the old vocabulary so the codebase carries one name
per thing:

```bash
grep -rn '<old-name>' $FILES
```

## Tests that repeat themselves

**Comment shape:** "這要測的目標和 L116 一樣吧", "為何要特別測這個？"

```bash
grep -nE '^\s*(it|test)\(' $FILES                       # read the case list as a whole
grep -c 'expect(' <one-test-file>                       # assertion density per case
```

Two assertions that drive the same branch to the same answer are one assertion.
A case whose intent is not obvious from its name keeps its assertions and gains
a comment saying which one is the point.
