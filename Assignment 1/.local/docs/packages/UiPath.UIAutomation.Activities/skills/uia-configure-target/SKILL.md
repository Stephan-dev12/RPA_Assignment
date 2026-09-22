---
name: uia-configure-target
description: "Primary entry point for configuring a UiPath target -- ensures the screen and element exist in the Object Repository, checking for existing entries before creating new ones. Returns the OR reference ID. Supports both UiPath-selector and Computer-Vision (CV) element targeting: CV fallback is enabled by default, so the skill automatically falls back to CV when selector-based resolution fails; pass `--cv false` to disable it. A final natural-language (semantic-selector) route is likewise enabled by default and resolves elements that neither selectors nor CV could; pass `--semantic false` to disable it. Supports batch element configuration via pipe-separated list (e.g., --elements \"Five button | Plus button | Equals button\") to avoid redundant window captures and screen lookups. Use when asked to 'configure target', 'configure application', 'set up target', 'set up application', 'create target in OR', 'find or create target', 'get OR reference for an element', 'select application window', 'create window selector', 'create selector', 'get selector for', 'find selector', 'add target to object repository', 'configure CV target', 'target via computer vision', or when an orchestrator agent needs an OR element reference for a UI element. Trigger this whenever building automation workflows that need reliable OR references."
argument-hint: "--window <description> [--elements <descriptions>] [--screen-reference-id <id>] [--cv false] [--semantic false] [--no-improve] [--project-dir <path>]"
allowed-tools: Bash, Read, Write, AskUserQuestion
---

Ensure screen and optional elements exist in Object Repository (OR); reuse matches before creating. Return OR reference IDs.

`$ARGUMENTS`: `--window <description> [--elements <descriptions>] [--screen-reference-id <id>] [--cv false] [--semantic false] [--no-improve] [--project-dir <path>]`

**Read contract:** read this file from the top THROUGH § Output, then STOP — § Fallback Routes (TARGET-9 CV, TARGET-10 semantic) sits after it and is read ONLY when the flow routes an element there (its marker states the exact triggers). Follow TARGET steps mechanically, without commentary between steps. After errors, retries, or questions, resume next incomplete step. OR concepts and full commands: [`object-repository.md`](../../references/object-repository.md). Target types: [Target.md](../../activities/common/Target.md). CLI wrapper: [CLI](#cli).

## Global Invariants

1. **Paths:** use forward slashes. Every CLI path (`--folder-path`, `--definition-file-path`, `--project-dir`, paths inside `--refs`, etc.) must be absolute, native-host format. Windows requires `C:/...`, never relative, git-bash/MSYS/Cygwin `/c/...`, WSL `/mnt/c/...`, or bare `pwd`. Invalid paths may silently write artifacts elsewhere or fail with misleading `path not found`. In git-bash use `pwd -W` or `cygpath -m`; verify drive letter.
2. **CLI writes definitions:** never create/hand-edit `.xaml` or `.xaml.metadata`. Read allowed. Mutate only with listed CLI definition/anchor commands; they rewrite XAML and metadata atomically. Window-selector stabilization in TARGET-2 still uses CLI.
3. **Selectors:** element selectors come only from TARGET-7 `resolve-defaults` or TARGET-7.2 improvement, whose attributes come from `selector-intelligence get-selector-attributes`/`get-ancestors` and are validated by `selector-intelligence evaluate`; never compose them from tree/`interact get-all` data.
4. **Exit codes:** check each command. Nonzero -> show the output and stop; report the screen and any elements already registered.
5. **Batching:** chain output-independent calls with `&&` where shown. Stop between invocations only when output drives a decision. TARGET-8, TARGET-9, and TARGET-10 are iterative; batch only independent substeps.
6. **Stdout:** never suppress chained command output (`>/dev/null`, `| tail`, `| grep`, command substitution). Snapshot stdout names the artifacts folder, then links each artifact by file name relative to that folder; inspect them before recapturing.

## CLI

Define a shell function, never a command string (string re-expansion breaks paths with spaces):

```bash
cli() { uip rpa uia "$@"; }
```

With `$PROJECT_DIR`:

```bash
cli() { uip rpa uia --project-dir "$PROJECT_DIR" "$@"; }
```

Redeclare per Bash invocation; shell state does not persist. One declaration covers calls chained inside that invocation. Alternatively write `uip rpa uia ...` fully and double-quote every path. Keep JSON (`--refs`, `--definition-file-paths`) as one double-quoted literal exactly as shown; never reconstruct it by re-expanding a bare variable.

If CLI says `'uia' requires the 'UiPath.UIAutomation.CLI' package`, first verify quoted `--project-dir` arrived as one argument. This usually means a split/truncated project path, not a missing package.

**Validation screenshots.** `--validate` on `add-anchor`, `remove-anchor`, `update-definition`, `update-anchor-definition`, `fuzzify` and `fuzzify-anchors` adds a `Validation:` line and, on a match, a `Screenshot:` line. That screenshot is always cropped to the matched element and its immediate surroundings: enough to confirm the highlight sits on the intended control, not enough to judge the surrounding layout. When the wider context is what settles the question, follow up with a separate `validate --full-screen` call on the same definition; `validate` is the only command that accepts `--full-screen`.

```bash
cli target-anchorable validate --definition-file-path "$TARGET_FILE" --full-screen
```

## Input Parsing

| Input | State / rule |
|---|---|
| `--window <description>` | `$WINDOW`; ask user if absent. Derive Title Case `$SCREEN_NAME`. |
| `--elements <descriptions>` or `--element` | Optional pipe-separated targets. Split on `|`, trim into `$ELEMENT_LIST`; absent = screen-only. Derive Title Case `$ELEMENT_NAMES` (for example `add to cart button` -> `Add To Cart Button`). |
| `--cv false` | `$USE_CV=false`; default `true`. Fallback is per-element; always selector-first, no force-CV. Ignored screen-only. |
| `--semantic false` | `$CONFIGURE_SEMANTIC=false`; default `true`. Semantic is final fallback. |
| `--no-improve` | `$NO_IMPROVE=true`; default `false`; skips 7.2 selector improvement and CV/semantic validation as specified below. |
| `--screen-reference-id <id>` | `$SCREEN_REF_ID`; skips TARGET-3. Pass only while current window still matches that screen's window selector (same app window, different UI state); omit when unsure. |
| `--project-dir <path>` | `$PROJECT_DIR`; pass to every CLI call. |

## Definition Files

A definition is an inseparable same-base pair: runtime XAML plus `.xaml.metadata` design metadata (`Name`, `Description`, IDs, activity type). One never exists without the other.

- Window: `window.xaml` + `window.xaml.metadata`; serialized [`TargetApp`](../../activities/common/Target.md#targetapp), created by `target-app resolve-defaults`.
- Selector element: `target-${INDEX}.xaml` + `target-${INDEX}.xaml.metadata`; [`TargetAnchorable`](../../activities/common/Target.md#targetanchorable) with live-tree selector and `window.xaml` scope, created in TARGET-7.
- CV element: same target slot/pair; `TargetAnchorable` with CV search, created in TARGET-9.
- Semantic element: same slot/pair; semantic-selector-only `TargetAnchorable`, created in TARGET-10.

Supported mutation: `target-app update-definition`, `target-anchorable update-definition`, and anchor commands named below.

Common failures: snapshot capture = app not running, minimized, or invisible; resolve-defaults = invalid ref/element missing; `Target eN not found in snapshot` / `Target eN is stale` = required snapshot absent (capture first) or ref disappeared/belongs to replaced snapshot.

## TARGET-1: Prepare Working Folder

Never reuse prior-run artifacts; they may reference another window or app state:

```bash
rm -rf .local/.uia/.configure-target && mkdir -p .local/.uia/.configure-target
```

Set `$WORK_FOLDER` to its absolute native-host path; set `$WINDOW_DEFINITION=$WORK_FOLDER/window.xaml`, `$SCREEN_CREATED=false`. Run function declaration, cleanup, path resolution, and TARGET-2 top-level capture in one Bash invocation. Chain where shown.

## TARGET-2: Create Window Selector

Continue TARGET-1 invocation. No definition exists, so capture unscoped, then search the rendered tree for the expected window in the same round-trip:

```bash
cli snapshot capture --folder-path "$WORK_FOLDER" && grep -i -B1 -A2 '<distinctive fragment of $WINDOW: app or title word>' "$WORK_FOLDER/window-tree.yml"
```

This produces a rendered `window-tree.yml` and a `TopLevelScreenshot.png` (stdout links the written artifacts) and also confirms a just-launched app. Match `$WINDOW` against the returned entries' titles/app names, partial case-insensitive. Prefer browser-tab `BrowserTab` refs (`bN`, for example `b3`) over native browser-window refs for web apps; regular windows use `wN` (for example `w3`). Save `$WREF`. No hit, or several plausible hits the context lines cannot separate -> read `window-tree.yml` in full; still unresolved -> show list and ask. Never read the full tree when the bounded search already identified the window; the file stays on disk for later needs.

Resolve window. `--refs` must remain JSON with forward-slash paths. `resolve-defaults` prints the written definition's `Selector` — that printed selector is the window identity used by every later step; do not `cat` the definition file for it. With elements, chain app capture and OR lookup:

```bash
cli target-app resolve-defaults \
  --refs "[{\"ref\":\"$WREF\",\"definitionFilePath\":\"$WORK_FOLDER/window.xaml\"}]" \
  --name "$SCREEN_NAME" \
  && cli snapshot capture "$WREF" --folder-path "$WORK_FOLDER" \
  && cli object-repository get-screens --definition-file-path "$WORK_FOLDER/window.xaml"
```

`snapshot capture` scope comes from `$WREF`: with it, app tree; without, desktop tree. With `--screen-reference-id`, retrieve its definition and compare `TargetApp` identity against the new window selector printed by `resolve-defaults`: desktop `app=` plus compatible window identity; browser URL host. `get-screen-definition` prints only the written file's path, so the supplied screen's definition must be read from that file. Mismatch -> stop; never query/register elements under supplied screen.

```bash
cli object-repository get-screen-definition \
  --definition-file-path "$WORK_FOLDER/supplied-screen.xaml" \
  --reference-id "$SCREEN_REF_ID" \
  && cat "$WORK_FOLDER/supplied-screen.xaml"

cli object-repository get-elements --screen-reference-id "$SCREEN_REF_ID"
```

App capture produces `ApplicationLevelNodeTreeInfo.json`, `ApplicationLevelApplicationMetadata.json`, `ApplicationScreenshot.png`. Screen-only omits only the app-level `snapshot capture`; retain `get-screens`.

**Stabilize title if needed.** Inspect the `title` in the `Selector` printed by `resolve-defaults`. If it includes volatile page content beyond app identity, keep only a stable app-identifying substring with wildcards (for example `title='*10 Unread - dan@ - Outlook*'` -> `title='*Outlook*'`). Kept text must be an original substring ignoring wildcards. Leave stable titles such as `Calculator` unchanged. Only window selectors receive this special edit.

Evaluate the stabilized selector before writing it, so a candidate that fails never reaches the file:

```bash
cli selector-intelligence evaluate --selector "$STABILIZED_WINDOW_SELECTOR" --refs "$WREF"
```

Pass requires the command to succeed and acceptable feedback. Failure: retry once, then keep the original selector; never leave TARGET-2 failing.

Several windows matching the selector exactly is not one of those failures. Retry once, and accept the second result even if several still match: `evaluate` marks such a selector `idx='*'` on its target tag, which is what lets it resolve when there are multiple identical top level windows with the same attributes. In that case, and the successful evaluation, persist the selector from the evaluation command result.

```bash
cli target-app update-definition \
  --definition-file-path "$WORK_FOLDER/window.xaml" \
  --selector "$EVALUATED_WINDOW_SELECTOR"
```

## TARGET-3: Find or Register the Screen in the Object Repository

Skip entirely when screen reference supplied; TARGET-2 already ran TARGET-4 lookup instead. Otherwise read already-returned filtered screen table; do not rerun it. Initialize empty `$SCREEN_REF_ID`.

- Rows: case-insensitive name match and same-app/window-title selector match are strong signals. Confident match -> save `ReferenceId`; multiple plausible -> ask. Empty table -> leave empty.

### Reuse an existing application (only when no screen matched)

When screen remains empty, avoid duplicate application containers. Initialize empty `$APP_REF_ID`.

1. Read `window.xaml` selector identity: desktop = `app=` executable (including main window/dialog/`#32770`); browser = URL host, not browser executable (sites are distinct apps).
2. In its own invocation run unfiltered `cli object-repository get-screens` (no definition filter, which would hide sibling windows). Empty listing leaves app ref empty.
3. Find same executable/URL-host application and take its `AppReferenceId`. Several matches: prefer best screen/name fit; ask if ambiguous. None: leave empty; the next subsection creates one.

### Create the application (only when no application matched)

Skip if `$APP_REF_ID` is set. `create-screen` never creates its own container, so a screen always needs an application first. Derive from the step-1 selector identity, not from `$SCREEN_NAME`: `$APP_NAME` (required) is the Title Case application, not the window -- desktop = product behind the executable (`notepad.exe` -> `Notepad`), browser = site at the URL host (`careers.acme.com` -> `Acme Careers`). `$APP_DESCRIPTION` (optional, omit the flag when nothing meaningful to say) states what the application is (for example `Acme HR portal, employee-facing web app`). Run in its own invocation; its output supplies the next command's argument:

```bash
cli object-repository create-app \
  --name "$APP_NAME" \
  --description "$APP_DESCRIPTION"
```

Stdout is the bare reference ID; save as `$APP_REF_ID`. Failure: show error, stop; never continue to `create-screen` without it.

### Register the screen (only when no screen matched)

Skip if screen matched. Register before element resolution because `create-screen` reads live entry URL and later resolution can navigate away. Compose `$SCREEN_DESCRIPTION` with app, purpose, and distinguishing context (for example `The main login page of the Acme HR portal`, `Calculator application main window`). Chain metadata write with the create call:

```bash
cli target-app update-definition \
  --definition-file-path "$WORK_FOLDER/window.xaml" \
  --name "$SCREEN_NAME" \
  --description "$SCREEN_DESCRIPTION"
```

`--app-reference-id` is required and takes the matched or newly created `$APP_REF_ID`; the screen is created inside that application:

```bash
cli object-repository create-screen \
  --definition-file-path "$WORK_FOLDER/window.xaml" \
  --app-reference-id "$APP_REF_ID"
```

Save stdout `$SCREEN_REF_ID`; set `$SCREEN_CREATED=true`. Failure: show error, stop. The flag marks a screen that is new and therefore holds no elements yet; TARGET-4 uses it to skip the element lookup.

Screen-only: assess window selector with TARGET-7 criteria 1-3, 5, 6 (criteria 4 and 7 are element-only); record fragility warning.

### Screen-only mode exit

No elements: registered/reused screen is deliverable; jump to Output.

## TARGET-4: Search for Existing Elements in Object Repository

If `$SCREEN_CREATED=true`, no elements exist: put all requests in `$ELEMENTS_TO_CREATE`; skip lookup. If `--screen-reference-id` was supplied, TARGET-2 already returned the element table. Otherwise run:

```bash
cli object-repository get-elements --screen-reference-id "$SCREEN_REF_ID"
```

Compare every row to every request. Signals: name (case-insensitive/minor wording) and stored semantic description referring to same UI element are strong; same control type/similar selector attributes support; uncertain screenshot path may be read. Per confident match record `{$ELEMENT_NAME, $ELEMENT_REF_ID, found}` and skip TARGET-5..11 for it. Unmatched entries become `{$INDEX, $ELEMENT, $ELEMENT_NAME}`. `$INDEX` permanently names `target-${INDEX}.xaml` across every route. If none need creation, jump to Output.

## TARGET-5: Choose the Resolution Route for Each Element

Derive case-sensitive `$ACTIVITY_TYPE_${INDEX}` per creation entry from its request; default `None`. See [`selection-activity-types.md`](../../references/selection-activity-types.md). Also derive `$ELEMENT_DESCRIPTION_${INDEX}` here: a Title Case name (`$ELEMENT_NAME_${INDEX}`, already produced per entry in TARGET-4) plus an OR description containing control type, role/action, and screen location (for example name `Add To Cart Button`, description `Button that adds the item to the cart, in the product grid`). Both feed every route's `name`/`description` JSON fields in TARGET-7/9/10 below and are registered as-is in TARGET-11 -- no later edit needed. Each `{INDEX, ELEMENT, ELEMENT_NAME, ACTIVITY_TYPE}` occupies one route:

- `$SELECTOR_ELEMENTS`: TARGET-6/7.
- `$CV_ELEMENTS`: TARGET-9 (§ Fallback Routes, end of file — read it IN FULL the moment this list becomes non-empty).
- `$SEMANTIC_ELEMENTS`: TARGET-10 (§ Fallback Routes — read IN FULL when non-empty); populated only if semantic enabled.

Initialize all in selector. Route no/ambiguous matches and fragile results by:

| CV | Semantic | Next route |
|---|---|---|
| enabled | either | CV |
| disabled | enabled | Semantic |
| disabled | disabled | Report/ask; no fallback exists |

CV failure -> Semantic when enabled, else report. Selector-only requires `--cv false --semantic false`. Final resolved lists feed TARGET-11.

## TARGET-6: Identify Element Reference

`tree.yml`: one node per line; two-space indent = hierarchy. Line parts:

- **Role** -- node type: `Button`, `InputBox`, `CheckBox`, `DropDown`, `TableRow`, `MenuItem`, `Container`, etc.
- **"Name"** -- accessible label in quotes.
- **[ref=eN]** -- selectable reference; ref-less lines are context only.
- **[state]** -- `[selected]`, `[focused]`, `[disabled]`, `[read only]`, `[editable]`, `[offscreen]`, `[invisible]`, `[no rectangle]`, `[items deferred]`, `[sap]`; not exhaustive.
- **: text** -- inline value (`InputBox "Username" [ref=e15]: john_doe`). Newlines render as literal `\n`.
- **`- /attr: value`** -- attribute child lines of node above (`/placeholder`, `/url`, `/tooltip`, `/data-*`, ...).

```text
- Container [ref=e30]:
  - Button "Add to cart" [ref=e42]
    - /automationid: addToCart
  - InputBox "Username" [ref=e15] [sap]: john_doe
    - /placeholder: Enter username
  - DropDown "Region" [ref=e31] [items deferred]: East
```

Rendered states/attributes are a deliberate selection sufficient to pick refs from tree alone; identification rarely needs live inspection. Each renders only when the framework reports it, so anything missing is unknown, not false.

Search boundedly for each element's text or name, then read the lines around each hit; never read a huge tree unbounded. Hit may land on an `/attr:` line; owning `[ref=eN]` sits above with less indentation. Surrounding parent/sibling lines give section context (panel, dialog, row). For batches issue all `$SELECTOR_ELEMENTS` searches in one round-trip, not one element per turn.

Pick candidate whose role matches requested interaction (`Button` for click, `InputBox` for type) and whose name/attributes/section context fit the request. Skip `[disabled]`; prefer visible over `[offscreen]`/`[invisible]`/`[no rectangle]` duplicates.

`[sap]` marks SAP web frameworks (Fiori/UI5, Web GUI, Ariba). Prefer `[sap]` node over plain parent/child when same Name and within 1-2 levels, even if SAP role is generic (`Container`, `Group`) and plain node is native (`InputBox`, `Button`, `INPUT`); SAP attributes are richer/stabler.

For each selector entry save match as `$EREF_${INDEX}`. Route no hit after eligible retry by TARGET-5's matrix.

### Disambiguate with interact when tree is inconclusive

Exactly one candidate fits role, name, and section context -> save ref, skip this subsection. Interact resolves residual doubt, not routine confirmation. Escalate only when:

- several candidates share similar role/name (repeated rows/cards/cells, visible+hidden duplicates) and tree context cannot separate them;
- pick is generic/nameless node (`Container`, `Group`) identified by inference alone;
- role or name fits request only loosely;
- `NGetAttribute` target: always `get-all` to choose attribute to read.

Checks -- these select/confirm; never write selectors from output:

- `cli interact highlight eN`: box + screenshot path; read image to verify box sits on intended control.
- `cli interact get-all eN`: full live attributes; compare distinguishing `text`, `data-testid`, `automationid`, `position`. Visible-vs-hidden duplicates are normally separated by tree states already (`[invisible]`/`[offscreen]`/`[no rectangle]`); when those are absent, prefer refs whose live attributes indicate visibility.
- `cli interact get eN items`: `[items deferred]` DropDown/List omits its options from the tree; read `items` (also `selectedItem`, `selecteditems`) to disambiguate by contents. Prefer `get <attr>` over `get-all` when one attribute suffices (except when selecting an attribute for `NGetAttribute`).

### Retry capture with UIA framework

For unmatched/uncertain elements read `ApplicationLevelApplicationMetadata.json` `subsystem`. Retry only `"aa"`; for `"uia"`, `"webctrl"`, `"html"`, `"java"`, etc., current framework tree is richer, so proceed to screenshot.

```bash
rm -f "$WORK_FOLDER/ApplicationLevelNodeTreeInfo.json" "$WORK_FOLDER/ApplicationLevelApplicationMetadata.json" "$WORK_FOLDER/ApplicationScreenshot.png" "$WORK_FOLDER/tree.yml"
cli snapshot capture "$WREF" --folder-path "$WORK_FOLDER" --framework uia
```

Recapture replaces tree; discard all prior `eN`, re-search. For multiple/no clear candidates, read `ApplicationScreenshot.png` once and correlate structure+visuals. Route remaining ambiguity by TARGET-5's matrix; list candidates only when no fallback exists.

## TARGET-7: Get Element Selectors

Only `resolve-defaults` and 7.2 improvement may produce element selectors. Work until `RELIABLE`; never call `target-anchorable update-definition --full-selector` with hand-derived attributes. One further edit permitted — value substitution ([§ Choosing how to parametrize](#choosing-how-to-parametrize)): replace a literal value of an already-present attribute, or a residue span of one, with `{{variable}}` or `*`. Postcondition, verify before calling `update-definition`: tag list and every attribute name byte-identical to the definition just read; only substituted spans differ. Attribute missing -> never hand-add it; discover it in 7.2 with `get-selector-attributes` and confirm it with `evaluate`. Element acted on once per loop item: pin its per-item value via the loop variable; upstream search/filter does not guarantee a single runtime match. [§ When to parametrize](#when-to-parametrize-per-item-actions-in-a-loop).

### 7.1: Get the default selector

Use each entry's `$ACTIVITY_TYPE_${INDEX}`. Each call seeds `ScopeSelectorArgument` from `window.xaml` and writes default `TargetAnchorable`.

Resolve all once, each JSON entry carrying its own `activityType`, `name`, and `description` (from TARGET-5) so the created definition's metadata is correct without a later edit:

```bash
cli target-anchorable resolve-defaults \
  --window-definition-file-path "$WORK_FOLDER/window.xaml" \
  --window-ref "$WREF" \
  --refs "[{\"ref\":\"$EREF_1\",\"definitionFilePath\":\"$WORK_FOLDER/target-1.xaml\",\"activityType\":\"$ACTIVITY_TYPE_1\",\"name\":\"$ELEMENT_NAME_1\",\"description\":\"$ELEMENT_DESCRIPTION_1\"},{\"ref\":\"$EREF_2\",\"definitionFilePath\":\"$WORK_FOLDER/target-2.xaml\",\"activityType\":\"$ACTIVITY_TYPE_2\",\"name\":\"$ELEMENT_NAME_2\",\"description\":\"$ELEMENT_DESCRIPTION_2\"}]"
```

`--window-ref` pins exact captured window; without it CLI locates application by window selector.

### What improvement can act on

Improvement changes only strict `Selector` `FullSelectorArgument` on main `TargetAnchorable` or anchor `Target`; never `FuzzySelector`, `SemanticSelector`, `CV`, `TextNative`, or `Image`. Empty selector list jumps TARGET-8. `$NO_IMPROVE=true` skips only 7.2; still assess and route selectors.

### Assess selector reliability

Read all target XAMLs in one parallel batch; assess each `FullSelectorArgument` and first element's `ScopeSelectorArgument` once. `SearchSteps=FuzzySelector` stays selector route as `ANCHOR_PENDING`; strict criteria and 7.2 do not apply. TARGET-8 handles it.

Strict selector is `RELIABLE` only if all hold:

1. Every tag has a developer/semantic identifier appropriate to type (`automationid`, `name`, `role`, `aria-label`, `id`, `app`, `cls`); all-last-resort identifiers fail.
2. No purely positional `idx`, `tableRow`, `tableCol`, etc.
3. Values stable: reject purely numeric generated IDs, CSS-in-JS hashes such as `css-1wq41pf`, component IDs with 3+ structural dot segments, framework hashes in tag names.
4. Activity-safe: `GetText`/`SetText`/`TypeInto` do not primarily identify by `text`, `aaname`, `visibleinnertext`, `innertext`; `Check`/`Uncheck` not by `checked`/`aastate`; `SelectItem` not by `selecteditem`/`value`.
5. Good structure: typically ~2 tags; 4+ over-specified/fragile; 2-3 meaningful attributes per tag.
6. No `css-selector` attribute.
7. Uniquely resolvable: no tag matches more than one runtime node — fails when wildcard or shared text covers the discriminating value, not merely for containing one. Check, do not assume: per row/card/section scope tag, count matching siblings around `[ref=$EREF_${INDEX}]` in `tree.yml`. Any non-target ref under `selector-intelligence evaluate`'s **Matching candidates** fails this criterion; "matches the first of several" always fails.

Mark each strict selector `RELIABLE`, `PARAMETRIZE_PENDING`, or `NEEDS_IMPROVEMENT`. If all strict selectors are `RELIABLE` or `PARAMETRIZE_PENDING`, skip improvement to TARGET-8; fuzzy entries remain `ANCHOR_PENDING`.

`PARAMETRIZE_PENDING`: element acted on once per loop item, identity carried by runtime text varying per item — whether or not it currently resolves uniquely. Not a 7.2 case: hardening removes the discriminator the loop depends on. Keep resolved attribute set; value substitution happens in TARGET-11 ([§ When to parametrize](#when-to-parametrize-per-item-actions-in-a-loop)); wildcard only residue not derivable from loop variable. Failures of criteria 1-6 (generated ID, positional, over-specification) still run 7.2: treat the per-item attribute as to-preserve while hardening, then re-run criteria 1-7 on the improved selector.

### When to parametrize: per-item actions in a loop

**Rule:** selector matching more than one runtime item must carry the current item's distinguishing value via the loop variable, else it resolves to an arbitrary or stale match. `{{variable}}` input syntax and the `string.Format` form the CLI stores: [`selector-variables.md`](../../references/selector-variables.md).

Applies when an activity runs once per item in a loop (`ForEach` over rows/results/cards/entries) acting on the current item's element. Pin the varying value on the **item/row selector**, not only the leaf control.

Do NOT drop the per-item value because an upstream step (search, filter, prior navigation) narrowed the UI to one match. Fails at runtime:

- Panes/lists don't clear between iterations — non-pinned selector matches a **stale** prior-item node.
- One query returns several qualifying nodes (variants, duplicates) — non-pinned selector is ambiguous.
- Lists repopulate asynchronously — selector resolves before the current item is present.

A `selector-intelligence evaluate` not-unique warning — any non-target ref under `Matching candidates` — is **blocking** for a looped target, not advisory.

Parametrize only the per-item varying value; keep constant constraints (labels, roles, fixed qualifiers) literal.

#### Hard rule: only parametrize a configured target

Parametrization only replaces an existing value: never compose selector text, change attribute set, add an attribute, or parametrize a hand-authored selector. Replacing a residue span of an already-present value with `*` is part of the same permitted edit — only for text not derivable from the loop variable, never over the discriminator.

#### Choosing how to parametrize

Read configured selector; follow first match:

| Attribute to parametrize | Action |
|--------------------------|--------|
| **Already present** (strict or fuzzy) | Swap that literal value for `{{variable}}` token via `update-definition`, keeping exact attribute set. |
| **Missing from a strict selector** (`SearchSteps` contains `Selector`) | Discover it in [7.2](#72-run-improvement-on-fragile-selectors-only) with `selector-intelligence get-selector-attributes`, confirm with `evaluate`, then parametrize the value it wrote. |
| **Missing from a fuzzy selector** (`SearchSteps` is `FuzzySelector`) | [7.2](#72-run-improvement-on-fragile-selectors-only) does not act on fuzzy selectors. Parametrize a different already-present attribute expressing the same variation, or **abort** — never hand-add an attribute. |

#### Worked example: per-item row in a results list

`ForEach` over `productName`; loop body clicks current result row's Add to Cart button. Several sellers list the same product; only the `Contoso` listing qualifies. `resolve-defaults` on first item returns:

```xml
<ctrl name='Results' role='table' /><ctrl name='View Wireless Mouse M185 by Contoso Wireless Mouse M185 Contoso Electronics *' role='row' rowName='Wireless Mouse M185  Contoso' /><ctrl name='Add to Cart' role='push button' />
```

Value substitution per attribute — tag list and attribute names unchanged (postcondition above):

```text
name:    'View Wireless Mouse M185 by Contoso Wireless Mouse M185 Contoso Electronics *' -> 'View {{productName}} by Contoso*'
rowName: 'Wireless Mouse M185  Contoso'                                                  -> '{{productName}}  Contoso'
```

- Parametrize only first product-name occurrence in `name`; trailing residue (repeated product name, seller, category) not derivable from loop variable -> `*`.
- `by Contoso` stays literal: discriminator excluding other sellers' rows.
- Keep `rowName` two-space gap verbatim; product occurrence varies, seller constant.

```bash
uip rpa uia target-anchorable update-definition \
  --definition-file-path "C:/path/to/target-3.xaml" \
  --full-selector "<ctrl name='Results' role='table' /><ctrl name='View {{productName}} by Contoso*' role='row' rowName='{{productName}}  Contoso' /><ctrl name='Add to Cart' role='push button' />"
```

Sequencing: confirm literal selector against live current item first (`target-anchorable validate --definition-file-path ...` prints highlighted screenshot); substitute only after every live check passes — stored `string.Format` selector no longer validates against the live app. Read `SearchSteps` to pick flag: strict `Selector` -> `--full-selector`; `FuzzySelector` -> `--fuzzy-selector`.

### 7.2: Run improvement on fragile selectors only

Skip if no-improve. Otherwise every `NEEDS_IMPROVEMENT` strict selector enters `$ELEMENTS_TO_IMPROVE`; never include window or `PARAMETRIZE_PENDING` entries. Improvement precedes and is not replaced by TARGET-8: reliable improved selectors drop out of anchoring under 8.2 Rule 4.

Blocking gate: read/print each element's actual `SearchSteps`. Improve only if it contains strict `Selector`; do not infer. Remove fuzzy entries (anchored in TARGET-8). Every remaining entry must run 7.2. Seed with 7.1 selector targeting correct element; improvement hardens that seed, it does not find a better target. Prefer unique volatile seed over generic; restore by rerunning 7.1 resolve-defaults if needed.

**Read the guide once.** Before the first entry, read [`selector-improvement-guide.md`](../../references/selector-intelligence/selector-improvement-guide.md), once per skill run, never again between entries.

No capture or load is needed here: every command below reads the in-memory tree already captured.

**For each entry in `$ELEMENTS_TO_IMPROVE`, in index order, carry steps 1-4 to a conclusion before starting the next entry.** Bind `$DEF_FILE=$WORK_FOLDER/target-${INDEX}.xaml`, `$EREF=$EREF_${INDEX}`, and `$CURRENT_SELECTOR` = that entry's `FullSelectorArgument` as 7.1 wrote it.

**Step 1 -- Discover what the tree offers.** Author nothing yet:

```bash
cli selector-intelligence get-ancestors "$EREF" --selector "$CURRENT_SELECTOR"
cli selector-intelligence get-selector-attributes "$EREF"
```

`get-ancestors` prints the ancestor chain top-down, one line per node with role, name, and that node's `eN` ref, annotating each ancestor with the `--selector` tag that matches it. It is the only legal source of additional tags -- guide hard rule 3: an added tag must come from the target's ancestry -- and it is equally how tags to *remove* surface: an annotated intermediate container contributing no reliability. A `--selector` that misses the target exits nonzero and names the divergent tag; that is a diagnosis of the current selector, not a failure of discovery.

`get-selector-attributes` prints one node's selector-participating attributes verbatim, empty values included. Repeat it per node you want to include in the selector: the target first, then each ancestor from `get-ancestors` worth adding to the `$CURRENT_SELECTOR`. These outputs are the only legal attribute source -- never lift attributes from `tree.yml`, a screenshot, or `interact get-all`.

Values print double-quoted, so padding stays visible. Copy the text between those outer quotes into the selector -- the quotes delimit the value and never belong in it, and padding inside them is part of the value and must be reproduced exactly.

**Step 2 -- Judge the findings, or hand the entry to anchoring.** Judge what came back against the guide and against criteria 1-7 with this entry's `$ACTIVITY_TYPE_${INDEX}`.

Nothing usable means no attribute and no added ancestor tag raises reliability; look for an anchor instead -- a nearby node meeting 8.3's criteria: stable, close, unique, not already an anchor.

| Outcome | Do |
| --- | --- |
| Something usable | Continue to step 3. |
| Nothing usable, anchor found | Leave the selector as 7.1 wrote it; remember that node as this entry's anchor candidate for TARGET-8. Keep `NEEDS_IMPROVEMENT`; continue to the next entry. |
| Nothing usable, no anchor | Leave the selector unchanged; TARGET-8's reassessment routes the entry to CV/semantic. Keep `NEEDS_IMPROVEMENT`; continue to the next entry. |

**Step 3 -- Evaluate the candidate.** Author the improved selector so it satisfies criteria 1-6 in its own right, then evaluate it before writing it anywhere; `evaluate` is what settles criterion 7:

```bash
cli selector-intelligence evaluate --selector "$IMPROVED_SELECTOR" --refs "<selector refs in tag order>"
```

`--refs` pairs positionally with the selector's tags: one ref per tag, same order. Every ref comes from step 1's `get-ancestors` chain, which runs top-down and ends at the target -- take the line each tag matches, in tag order. All refs must be `eN` from this tree. Never add `idx` -- evaluate recomputes it (guide hard rule 4).

Failure exits nonzero reporting only the reason: does not parse, contains `{{variables}}`, tag count differs from ref count, uses an attribute the target node does not expose, does not match the target ref, or `idx` cannot be computed. Fix the named cause and evaluate again.

Accept the selector only when all three hold:

1. The command succeeded.
2. **Matching candidates** lists `$EREF` alone. Every ref listed matches the selector exactly, so any other one is a collision and fails.
3. **Feedback** raises nothing to address -- not unique, target not among the candidates, and duplicated attribute values each fail.

Otherwise revise from step 1's output and evaluate again. After three rejected attempts on this entry, take step 2's no-usable-finding branch instead.

**Step 4 -- Persist the accepted selector.** `$EVALUATED_SELECTOR` is step 3's **Evaluation** selector; `$WINDOW_SELECTOR` is the definition's current `ScopeSelectorArgument`, unchanged:

```bash
cli target-anchorable update-definition \
  --definition-file-path "$DEF_FILE" \
  --scope-selector "$WINDOW_SELECTOR" \
  --full-selector "$EVALUATED_SELECTOR"
```

Mark the entry `RELIABLE`. Step 3's gate already settled criteria 1-7; an entry left `NEEDS_IMPROVEMENT` is routed to CV/semantic by TARGET-8's reassessment.

## TARGET-8: Configure Selector Anchors

This step applies only to selector targets. CV performs its own anchor refinement inside TARGET-9.3; semantic targets do not use anchors.

Anchor = nearby stable element disambiguating main target. Find by captured-tree reasoning.

### 8.1 Gates and classification

Initialize empty `$STRICT_ELEMENTS_TO_ANCHOR`, `$FUZZY_ELEMENTS_TO_ANCHOR`. Classify only resolved `$SELECTOR_ELEMENTS`; CV/semantic/failed/missing definitions never enter:

- `FuzzySelector`: if any anchor already registered (often auto-added by 7.1), hard skip; never add second. Only no-anchor fuzzy enters `$FUZZY_ELEMENTS_TO_ANCHOR`.
- strict `Selector`: enter `$STRICT_ELEMENTS_TO_ANCHOR`.
- anything else: internal flow error; report and stop.

### 8.2 Decide whether an anchor is needed

For each strict candidate read `FullSelectorArgument`; apply first matching rule:

0. **`PARAMETRIZE_PENDING` or already parametrized -> DROP:** per-item value carried by loop variable ([§ When to parametrize](#when-to-parametrize-per-item-actions-in-a-loop)); anchor adds fragility, and `add-anchor` would convert strict selector to `FuzzySelector`.
1. **Positional -> KEEP:** any `idx`, `tableRow`, `tableCol`, or other purely positional attribute anywhere. Other label/content constraints (for example `visibleinnertext='*ETH gas*'`) do not offset it.
2. **Volatile-as-identifier -> KEEP:** identity uses target's changing `text`/`aaname`/`name`/`rowName`/`visibleinnertext`/`innertext`, `checked`/`aastate`, or `selecteditem`/`value`. Exception: stable label/header/column used only to scope parent/row/column (for example `colName='Market cap'`, enclosing `TR visibleinnertext='*Solana*'`) does not trigger keep.
3. **Unpinned sibling -> KEEP:** repeated cell/button/row/card sibling without stable row/column/section scope. Already pinned by stable row scope+`colName`, header, etc. does not qualify; a scope matching several runtime nodes (wildcard or shared text covering the discriminating value, for example `name='*by Contoso*'`) is not a pin — stability is not uniqueness.
4. **Otherwise -> DROP:** developer identifier or stable row+column scope is unique/stable; anchor adds fragility.

Remove dropped strict entries, then set `$ELEMENTS_TO_ANCHOR` = retained `$STRICT_ELEMENTS_TO_ANCHOR` + `$FUZZY_ELEMENTS_TO_ANCHOR`. Empty -> reassess selector results below.

### 8.3 Find anchor candidates

For each `$ELEMENTS_TO_ANCHOR`, locate target boundedly:

Search `tree.yml` for `[ref=$EREF_${INDEX}]` and read the surrounding parent/siblings/leaves around the hit; indentation is structure. If proximity unclear, read `ApplicationScreenshot.png` once. Candidate must be: stable (static distinctive text/developer ID, not timestamp/count/row value), close (sibling/adjacent label/within 1-2 levels), unique, and not already an anchor.

Mandatory duplicate check: read definition pair, enumerate registered anchors, map each selector/name semantically to tree ref, compare candidate. Same node -> choose another. Preference: explicit target label, table header for grid cell, nearest stable neighbor.

Maximum four slots `0..3`; prefer one strong anchor. Add multiple only when no single candidate disambiguates (for example row+column headers). Never pad; each adds runtime dependency. No qualified candidate -> retain the original target and leave the selector unresolved for reassessment.

### 8.4 Wire the anchors

Use CLI only. Complete add/assess/remove before the next anchor; removal shifts later indices. For strict mains, `add-anchor` atomically converts `Selector` to anchor-capable `FuzzySelector`; strict itself ignores anchors. Failure stops. Save `$AREF`, Title Case `$ANCHOR_NAME`, returned `$SLOT`:

```bash
cli target-anchorable add-anchor \
  --element-ref "$AREF" \
  --window-ref "$WREF" \
  --definition-file-path "$WORK_FOLDER/target-${INDEX}.xaml" \
  --name "$ANCHOR_NAME" \
  --validate
```

Verify main target validation and highlighted match. Then read slot `SearchSteps`; anchors may resolve strict or fuzzy (text labels/headers/static text commonly fuzzy). Assess enabled strict `FullSelectorArgument` or fuzzy `FuzzySelectorArgument` with TARGET-7 reliability rules (identifier, non-positional, stable, unique, ~2 tags). Correct main + reliable anchor -> keep on the selector route. Not found/wrong main/unreliable anchor -> remove, choose another; no valid candidate -> retain the restored original target and leave it unresolved:

```bash
cli target-anchorable remove-anchor \
  --definition-file-path "$WORK_FOLDER/target-${INDEX}.xaml" \
  --index "$SLOT"
```

### Reassess after improvement and selector anchoring, then route stragglers to CV/semantic

Keep reliable strict selectors, `PARAMETRIZE_PENDING` strict selectors, already-anchored fuzzy selectors, and selectors successfully anchored in TARGET-8 in `$SELECTOR_ELEMENTS`. Remove every remaining strict `NEEDS_IMPROVEMENT` or unanchored fuzzy entry from `$SELECTOR_ELEMENTS` and route it by TARGET-5's matrix; CV/semantic overwrites its slot. With no fallback, ask whether to register the warned fragile selector or omit it.

## TARGET-11: Register Elements in the Object Repository

Screen already exists as `$SCREEN_REF_ID`; screen-only never reaches here. Registration set = `$SELECTOR_ELEMENTS` + `$CV_ELEMENTS_FINAL` + `$SEMANTIC_ELEMENTS_FINAL` (the fallback lists are empty when no element was ever routed to § Fallback Routes), ordered by original index. Empty set -> delete screen only when `$SCREEN_CREATED=true`, report failures, stop; never call `create-elements`. Paths are comma-separated and may mix routes:

For each `PARAMETRIZE_PENDING` entry, first apply value substitution ([§ When to parametrize](#when-to-parametrize-per-item-actions-in-a-loop)): read `SearchSteps`, then `update-definition` with `--full-selector` (strict `Selector`) or `--fuzzy-selector` (`FuzzySelector`); verify TARGET-7 postcondition. Name/description flags do not touch the selector; substitution precedes them.

```bash
cli object-repository create-elements \
  --screen-reference-id "$SCREEN_REF_ID" \
  --definition-file-paths "$WORK_FOLDER/target-1.xaml,$WORK_FOLDER/target-2.xaml"
```

`create-elements` persists full `TargetAnchorable`, including `CvType`, `CvText`, `CvTextOccurrence`, `CvElementArea`, `CvTextArea`; no promotion step. Each element prints a block (blank-line separated): a created element lists `Name:`, `DefinitionFilePath:`, `ReferenceId:`; a failed element lists `Name:` and an `Error:` line (that element failed). Parse by `Name:` into `{$ELEMENT_NAME, $ELEMENT_REF_ID, created}` records.

If `$SCREEN_CREATED=true` and zero elements registered (empty set or all failed), delete orphan:

```bash
cli object-repository delete-screen --reference-id "$SCREEN_REF_ID"
```

Never delete reused screen; report failures.

## Output

Return screen reference; element references (table if multiple); screen-only window-selector warning; target/anchor fragility warnings; failures with reasons; registered `CREATED_UNVALIDATED` elements. No other observations, quality notes, or suggestions.

---

## Fallback Routes (TARGET-9, TARGET-10) — read ONLY when routed

**Read gate:** do NOT read past this marker during the initial full read. Read TARGET-9 IN FULL the moment any element enters `$CV_ELEMENTS` (TARGET-5 routing, or stragglers after TARGET-7/8 reassessment); read TARGET-10 IN FULL the moment any element enters `$SEMANTIC_ELEMENTS` or falls through from TARGET-9. Executing a fallback route without having read its section is the failure mode. When nothing is ever routed here, `$CV_ELEMENTS_FINAL` and `$SEMANTIC_ELEMENTS_FINAL` are empty lists at TARGET-11.

## TARGET-9: Resolve Computer Vision elements

Initialize empty `$CV_ELEMENTS_FINAL` and `$CV_FAILED`. `$USE_CV=false` or empty `$CV_ELEMENTS` -> TARGET-10. Otherwise operate directly on its entries. Each entry retains `$INDEX`, `$ELEMENT_NAME`, original description, and `$ACTIVITY_TYPE_${INDEX}`. Set `$WINDOW_DEFINITION=$WORK_FOLDER/window.xaml`, `$TARGET_FILE=$WORK_FOLDER/target-${INDEX}.xaml`.

`target-anchorable resolve-defaults` with `cve*`/`cvw*` creates CV-only `TargetAnchorable`: `SearchSteps=CV`, scope copied from window, CV type/text/areas populated, no selector step. Metadata inherits Name and carries ActivityType; TARGET-11 writes friendly metadata. Never hand-edit; only `target-anchorable resolve-defaults`, `update-definition`, `add-anchor`, `update-anchor-definition`.

`CvText` matches at runtime. Prefer button captions, static labels, menu items, tabs, column headers. Avoid typed contents, dates/times, counters, prices, badges, session IDs, user names, emails, tenants, environment text. Replace only a volatile caption span with `*`. If every distinguishing string is volatile, change ref, occurrence, or anchors instead of tightening text.

### 9.1 Capture the CV snapshot

Capture the window once:

```bash
cli snapshot capture "$WREF" --folder-path "$WORK_FOLDER" --type cv
```

CLI prints a `### CV snapshot` section with one markdown link per written artifact. Success always writes `cv-tree.yml`; normally `cv-application-screenshot.png`, but do not assume the screenshot exists unless stdout links it. Refs are 1-based (`cve1`, `cvw1`; `cve0`/`cvw0` invalid), ordered top-to-bottom/left-to-right:

```text
- Button [ref=cve4] "Submit" [Labels="Email","etc"]
  - Text [ref=cvw3] "First name"
- Button [ref=cve5] "Cancel"
- Text [ref=cvw7] "standalone label"
```

`cve*` = detected element; `cvw*` = OCR word. Nested words lie within their parent region and may occur under several containers. `[Labels=...]` exists only on `cve*` with saved anchor-word relations; prefer it for otherwise-equivalent candidates, then verify the highlight.

### 9.2 Pick refs and create definitions

Choose the expected CV type/ref for each `$CV_ELEMENTS` entry.

| Visual appearance                         | CvType           |
|-------------------------------------------|------------------|
| Clickable button with text/icon           | `Button`         |
| Text input field, search box, textarea    | `InputBox`       |
| Checkbox (square toggle)                  | `CheckBox`       |
| Radio button (circular toggle)            | `RadioButton`    |
| Window close button (X)                   | `CloseButton`    |
| Window maximize button                    | `MaximizeButton` |
| Window minimize button                    | `MinimizeButton` |
| Small icon/glyph without text             | `Icon`           |
| Arrow/chevron/expand button               | `ArrowButton`    |
| Table/grid cell                           | `Cell`           |
| Static text label                         | `Text`           |
| Image/picture/logo                        | `Image`          |
| Generic region/container                  | `Area`           |
| Any text (OCR-based, no specific control) | `AnyText`        |
| Group of words                            | `AnyWordGroup`   |
| Any icon (generic icon match)             | `AnyIcon`        |
| Data table/grid                           | `Table`          |
| Specific table cell                       | `TableCell`      |

Grep boundedly:

```text
Grep pattern="(?i)submit" path="$WORK_FOLDER/cv-tree.yml" output_mode="content"
Grep pattern="^\s*- Button \[ref=.*Total" path="$WORK_FOLDER/cv-tree.yml" output_mode="content"
```

Prefer `cve*` for clickable/editable controls; use `cvw*` only for true standalone text. Expected type absent but screenshot clearly shows target -> use the closest type/ref and verify carefully. Avoid volatile text; choose stable text or a textless ref plus anchors. Multiple plausible candidates -> inspect the printed screenshot or box one with `cli interact highlight cve4`; if still ambiguous, add the entry directly to `$CV_FAILED` with candidate refs and reason `AMBIGUOUS`; never invent.

Build one JSON array directly from the remaining `$CV_ELEMENTS` entries, carrying the same `name`/`description` from TARGET-5 (this also replaces CV's default inherited-application-name behavior, so no later name/description edit is needed):

```text
$REFS = "[{\"ref\":\"$EREF_1\",\"definitionFilePath\":\"$WORK_FOLDER/target-1.xaml\",\"activityType\":\"$ACTIVITY_TYPE_1\",\"name\":\"$ELEMENT_NAME_1\",\"description\":\"$ELEMENT_DESCRIPTION_1\"},{\"ref\":\"$EREF_2\",\"definitionFilePath\":\"$WORK_FOLDER/target-2.xaml\",\"activityType\":\"$ACTIVITY_TYPE_2\",\"name\":\"$ELEMENT_NAME_2\",\"description\":\"$ELEMENT_DESCRIPTION_2\"}]"
```

Resolve once:

```bash
cli target-anchorable resolve-defaults --window-definition-file-path "$WINDOW_DEFINITION" --window-ref "$WREF" --refs "$REFS"
```

Never pass `--folder-path` (unsupported). It prints one block per entry, blocks separated by a blank line: a successful CV entry lists `ReferenceId`, `DefinitionFilePath`, `SearchSteps: CV`, and its `CvType`/`CvText` (a selector-based entry lists its `SearchSteps` and `FullSelector`/`FuzzySelector` instead); a failed entry lists `ReferenceId` and an `Error:` line. Parse blocks by `ReferenceId:`, map to the existing entry/index. Add error blocks directly to `$CV_FAILED` with status `ERROR`; exclude them from validation. A single-entry retry uses the same command shape with one ref and overwrites the slot.

### 9.3 Validate and refine

For each created definition, `$NO_IMPROVE=true` skips validation: add the entry directly to `$CV_ELEMENTS_FINAL` with status `CREATED_UNVALIDATED` and `no_improve=true`, then continue.

Otherwise allow maximum three attempts per definition:

```bash
cli target-anchorable validate --definition-file-path "$TARGET_FILE"
```

Exact results:

- `Validation: The target was found against the live application.`, optionally followed by a `Screenshot: <path>` line.
- `Validation: The target was not found against the live application.`

Not-found is validation failure, not proof of absence: it covers zero candidates (hidden/occluded/stale/wrong ref) and duplicate candidates. Initial CV default often fails; refine before final status.

Found -> read the printed screenshot and confirm the intended element. Deterministic match may be the wrong sibling. Correct match -> add the entry directly to `$CV_ELEMENTS_FINAL` with status `RESOLVED`, caption, and screenshot path. Wrong match -> choose `$NEW_EREF`, rerun `resolve-defaults` for the same slot, validate again.

Not found -> compare same-type/similar-text candidates in the tree and screenshot. No plausible candidate -> retry a better ref if any; record `NOT_FOUND` only when no usable ref/definition remains. Plausible duplicates -> try applicable refinements in order:

1. Tighten stable text:

   ```bash
   cli target-anchorable update-definition --definition-file-path "$TARGET_FILE" --cv-text "$MORE_SPECIFIC_TEXT"
   ```

   `*` = zero or more, `?` = exactly one; bare text = case-insensitive substring. Other regex metacharacters (`.`, `^`, `$`, `[]`, `|`, etc.) are literal. Fuzzy matching is always on via `CvTextAccuracy` (>0, <=1; default 0.7). Wildcards also tighten the fuzzy branch; retaining the distinctive caption span is valid.

2. Different captions colliding fuzzily -> raise accuracy:

   ```bash
   cli target-anchorable update-definition --definition-file-path "$TARGET_FILE" --cv-text-accuracy $CV_TEXT_ACCURACY
   ```

3. True duplicate captions only -> enumerate the intended 1-based top-to-bottom/left-to-right occurrence; never use occurrence for textless controls:

   ```bash
   cli target-anchorable update-definition --definition-file-path "$TARGET_FILE" --cv-text-occurrence $CHOSEN_OCCURRENCE
   ```

4. Add a nearby distinctive anchor, especially for textless `InputBox`, `Cell`, `TableCell`, or icon; avoid sibling-colliding text:

   ```bash
   cli target-anchorable add-anchor --element-ref "$AREF" --window-ref "$WREF" --definition-file-path "$TARGET_FILE"
   ```

   On success prints `Message: Anchor added at index '{N}'.`; parse `{N}` (the new slot). Accepts `--name`, `--description`, `--validate` (which adds a `Validation:` line and, on a match, a `Screenshot:` line). Never pass `--folder-path`. Refine:

   ```bash
   cli target-anchorable update-anchor-definition --definition-file-path "$TARGET_FILE" --index $SLOT --cv-text "$ANCHOR_TEXT"
   ```

   Prints `Message: Anchor at index '{N}' updated.`; `Validation:`/`Screenshot:` lines appear only with `--validate`. If one anchor is insufficient, a second must use different relative geometry, not reinforce the same side.

`update-definition` prints `Message: Target anchorable definition updated.`; `--validate` adds `Validation:`/`Screenshot:` lines. After every text/accuracy/occurrence/anchor change, validate and verify the printed screenshot. Never fail solely from the initial default. After three attempts, add unresolved entries directly to `$CV_FAILED`: `NOT_FOUND` for absent/no usable ref, `AMBIGUOUS` when duplicates remain, or `ERROR` for CLI/CV service failure. Never register an unverified or wrong definition.

After all CV entries, if `$CONFIGURE_SEMANTIC=true`, remove each entry from `$CV_FAILED` and append it directly to `$SEMANTIC_ELEMENTS`, preserving index, name, original description, activity type, and CV failure reason; TARGET-10 overwrites the same slot. If `$CONFIGURE_SEMANTIC=false`, retain `$CV_FAILED` for Output. Continue to TARGET-10 in either case; its flag gate routes directly to TARGET-11 when semantic is disabled.

## TARGET-10: Resolve Semantic elements

Initialize empty `$SEMANTIC_ELEMENTS_FINAL` and `$SEMANTIC_FAILED`. `$CONFIGURE_SEMANTIC=false`, screen-only, or empty `$SEMANTIC_ELEMENTS` -> TARGET-11. Semantic is the final standalone semantic-selector-only route, never layered on selector/CV and never anchored. Operate directly on each existing entry; set `$TARGET_FILE=$WORK_FOLDER/target-${INDEX}.xaml`. Never hand-edit; for semantic target definition operations only use `target-anchorable resolve-defaults` and `validate`.

### 10.1 Ensure an application snapshot is loaded

Any earlier application/CV capture satisfies. Only if none exists from this run:

```bash
cli snapshot capture "$WREF" --folder-path "$WORK_FOLDER"
```

### 10.2 Resolve from the description

Derive one plain natural-language semantic description per entry: control + identifying UI details, no selector syntax. The description is matched at runtime against whatever is on screen then, so identify the element by what stays the same, not by what happens to be on screen while configuring:

- **Identify by:** control type/role (button, text box, checkbox, dropdown, cell); its static caption, label, or placeholder; the adjacent static label it belongs to; its section, panel, dialog, tab, or column header; stable relative position (`in the top-right toolbar`, `the first row of the results table`).
- **Never mention:** anything the user or the app can change -- current contents of a text box or editable cell, selected dropdown item, checkbox/toggle state, dates/times, counters, totals, prices, badge numbers, session/order/record IDs, user names, emails, tenant or environment names, row data values.
- **Say what the element is and where, not what it currently holds:** `the username text box under the 'Sign in' heading`, not `the text box containing john_doe`; `the Quantity cell in the first order row`, not `the cell showing 4`.

Build the JSON array directly from `$SEMANTIC_ELEMENTS`; use `semanticDescription` instead of `ref`, and carry the same `name`/`description` from TARGET-5 so metadata is set on creation. `$WREF` is mandatory—there is no window-selector fallback, and omitting it yields `Could not find the application` even with a snapshot:

```bash
cli target-anchorable resolve-defaults \
  --window-definition-file-path "$WINDOW_DEFINITION" \
  --window-ref "$WREF" \
  --refs "[{\"definitionFilePath\":\"$WORK_FOLDER/target-1.xaml\",\"activityType\":\"$ACTIVITY_TYPE_1\",\"semanticDescription\":\"$SEMANTIC_DESCRIPTION_1\",\"name\":\"$ELEMENT_NAME_1\",\"description\":\"$ELEMENT_DESCRIPTION_1\"},{\"definitionFilePath\":\"$WORK_FOLDER/target-2.xaml\",\"activityType\":\"$ACTIVITY_TYPE_2\",\"semanticDescription\":\"$SEMANTIC_DESCRIPTION_2\",\"name\":\"$ELEMENT_NAME_2\",\"description\":\"$ELEMENT_DESCRIPTION_2\"}]"
```

Resolve all entries in one call. Each entry prints a block: on success `DefinitionFilePath: $TARGET_FILE` then `SearchSteps: SemanticSelector`/`SemanticSelector: …`; on failure an `Error: $REASON` line (semantic entries carry no ref, so no `ReferenceId:` line). Blocks are blank-line-separated; map by `DefinitionFilePath:` to the existing entry. Add error blocks directly to `$SEMANTIC_FAILED` with status `ERROR` and exclude them from validation.

### 10.3 Validate and refine

For each created definition, `$NO_IMPROVE=true` skips validation: add it directly to `$SEMANTIC_ELEMENTS_FINAL` with status `CREATED_UNVALIDATED` and `no_improve=true`, then continue.

Otherwise allow maximum three attempts:

```bash
cli target-anchorable validate --definition-file-path "$TARGET_FILE"
```

Results are the same exact found/not-found messages as CV. Found -> read the printed screenshot and verify the described element. Correct match -> add the entry directly to `$SEMANTIC_ELEMENTS_FINAL` with status `RESOLVED` and screenshot path. Wrong sibling or not found -> refine the description: add a distinguishing role, adjacent label, section, or relative position, then re-resolve the same entry with the refined description — never `update-definition --semantic-selector`:

```bash
cli target-anchorable resolve-defaults \
  --window-definition-file-path "$WINDOW_DEFINITION" \
  --window-ref "$WREF" \
  --refs "[{\"definitionFilePath\":\"$TARGET_FILE\",\"activityType\":\"$ACTIVITY_TYPE\",\"semanticDescription\":\"$NEW_DESCRIPTION\",\"name\":\"$ELEMENT_NAME\",\"description\":\"$ELEMENT_DESCRIPTION\"}]"
```

An `Error:` block on re-resolve counts as a failed attempt; otherwise validate again, verify the highlight, and tighten each retry. After three unconfirmed attempts, add the entry directly to `$SEMANTIC_FAILED` with status `NOT_FOUND` and the last validation message. Record CLI/service failures as `ERROR`. Exclude every failed slot from registration. Continue with successes and report failures at Output; do not abort while any element or screen remains worth registering.

