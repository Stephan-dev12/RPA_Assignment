# Recover Selector Guide

Repairing a target definition whose selector no longer resolves — element not found, selector stopped working, runtime failure. The original matches nothing, so it has to be re-derived against the current tree.

Recovery repairs an **existing** definition in place and preserves its identity: its Object Repository reference, or the `IdRef` link the workflow activity already holds. That is what separates it from [`uia-configure-target`](../skills/uia-configure-target/SKILL.md), which resolves a target from a natural-language description and registers a **new** one — running it here would create a second entry and orphan the link.

A selector that still resolves but looks fragile is not recovery. That is hardening, and it happens inside configure-target's [TARGET-7.2](../skills/uia-configure-target/SKILL.md) as part of the normal configure flow.

Recovery runs inline in the caller's own session; no subagent, no staged per-target folder.

## RECOVER-1: Stage the definition from its source

Pull the definition out of where it lives, so the repaired selector goes back to the same place.

| Source | Stage | Write back (RECOVER-5) |
|---|---|---|
| Object Repository reference | `object-repository get-element-definition --reference-id` | `object-repository update-element` |
| XAML activity | `target-anchorable get-definition --activity-id --workflow-file-path` | `target-anchorable link` |

```bash
uip rpa uia object-repository get-element-definition \
  --definition-file-path "$FOLDER/target.xaml" \
  --reference-id "$OR_REF"
```

```bash
uip rpa uia target-anchorable get-definition \
  --definition-file-path "$FOLDER/target.xaml" \
  --activity-id "$ACT_REF" \
  --workflow-file-path "$XAML_REL_PATH"
```

Prefer the OR form when a reference exists: it carries `ActivityType` over from the source, so the reliability rules match the activity (`GetText` avoids content-reflecting attributes, `Check` avoids state attributes). The XAML form needs `--activity-type` passed explicitly and defaults to `Click`.

> `WindowSelector` below means `SelectorArgument` on a window/screen definition and `ScopeSelectorArgument` on an element definition.

## RECOVER-2: Choose the snapshot source

The tree everything resolves against comes from one of two places, depending on whether the application is reachable.

| Situation | Source |
|---|---|
| App not reachable — runtime data or a failure dump shipped from elsewhere | `snapshot load --folder-path "$FOLDER"` over the as-received files |
| App reachable | `snapshot capture` for the desktop tree, then `snapshot capture "$WREF"` for that window's element tree |

```bash
uip rpa uia snapshot capture --folder-path "$FOLDER" && cat "$FOLDER/window-tree.yml"
uip rpa uia snapshot capture "$WREF" --folder-path "$FOLDER"
```

Take `$WREF` from `window-tree.yml`: match the definition's `WindowSelector` against it when that selector still works, otherwise pick the window by its listed name/app. The desktop capture takes no definition, so a broken `WindowSelector` does not affect it. Already holding the window's `wN`/`bN`? Run the second command only.

Capturing here is safe — recovery owns the session. A `TargetApp` definition needs the desktop tree only; skip the app-level capture.

## RECOVER-3: Repair the scope selector when the window itself is gone

Only when the definition's `WindowSelector` matches nothing. A `TargetApp` skips this step — its selector *is* what RECOVER-4 rebuilds.

For a `TargetAnchorable`, fix the window first so element recovery sees a resolvable scope. Identify the target window in `window-tree.yml` — the `$WREF` node if you resolved one, otherwise by name/app — author a selector from that node, and write only the scope, which leaves the element selector intact as reference material:

```bash
uip rpa uia target-anchorable update-definition \
  --definition-file-path "$FOLDER/target.xaml" \
  --scope-selector "$RECOVERED_WINDOW_SELECTOR"
```

Target window absent from `window-tree.yml` entirely: report the dead scope selector and stop — the application is not running the window this definition targets. Window found but no app-level tree staged: apply the repaired scope, report that element recovery needs a capture at that window, stop.

## RECOVER-4: Re-identify the target, then rebuild its selector

The broken selector matches nothing, so the element has to be found again before any selector can be authored. This is the step recovery owns — configure-target's TARGET-7.2 hardens a selector that already matches and will not search for a target.

Locate the element in the captured tree from what the definition still tells you: its metadata name and description, its `ActivityType`, and the attribute values in the stale selector as search hints. Correlate against `ApplicationScreenshot.png` when the tree alone is inconclusive. Follow [TARGET-6](../skills/uia-configure-target/SKILL.md) for the search and disambiguation rules; save the resulting `eN` as `$EREF`.

With `$EREF` known, produce the selector exactly as configure-target does — no separate procedure here:

1. [TARGET-7.1](../skills/uia-configure-target/SKILL.md) `target-anchorable resolve-defaults` against `$EREF` for a default selector.
2. [TARGET-7.2](../skills/uia-configure-target/SKILL.md) to discover attributes and ancestor tags, evaluate a candidate, and write the accepted selector into the definition.

No usable element in the tree: report that the target is not present in the captured state and stop. Do not author a selector from a guess.

## RECOVER-5: Write back to the source

Return the repaired definition to where RECOVER-1 took it from, so the existing reference or activity link keeps pointing at it:

```bash
uip rpa uia target-anchorable link \
  --targets "[{\"workflowFilePath\":\"$XAML_REL_PATH\",\"activityId\":\"$ACT_REF\",\"definitionFilePath\":\"$FOLDER/target.xaml\"}]"
```

For an Object Repository element, write back with `object-repository update-element`.
