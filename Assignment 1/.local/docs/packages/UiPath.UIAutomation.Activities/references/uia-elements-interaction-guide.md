# UI Elements Interaction Guide

Drive captured Object Repository targets; this guide covers interaction, not capture.

## Date and time inputs

Applies to native `<input type="date">`, framework web pickers, and desktop segmented pickers (macOS `AXDateTimeArea`, WinForms/WPF `DateTimePicker`, Java/SAP date fields). All accept the **rendered** format, not the canonical `value`, and several fail silently.

1. Input method. Web: key events — `DebuggerApi` on Chromium-based browsers, `HardwareEvents` elsewhere ([input-methods-guide.md](input-methods-guide.md)). Never use `Simulate` on web date inputs: it sets the underlying value without the `input`/`change` events, so validation/data binding may not commit. Desktop: per application, same guide.
2. During authoring, while snapshot refs (`e5`, ...) remain live, determine the fixed displayed format and bake it into the workflow. This read chooses the input value, not selector construction. Stop at first successful strategy (strategy 1 is web-only):

   | # | Strategy | Use when | Trade-off |
   |---|----------|----------|-----------|
   | 1 | **Inject JavaScript** — `uip rpa uia interact browser eval <e-ref> "(el) => …"` (element-scoped). Read `type`, `placeholder`, framework picker's sub-input values / internal state, shadow DOM. For **native date input** rendered segments are not in DOM (`value` is ISO); locale guess (`navigator.language` / `Intl`) reflects only *content-language* preference — can differ from browser/OS **UI locale** actually rendering picker — treat as hint, confirm with strategy 2. | Reliable for framework pickers whose format is exposed in DOM (`placeholder` / sub-input values). | Web only; fragile to page changes. Locale guess may not match native date picker. |
   | 2 | **Screenshot** — `uip rpa uia interact screenshot <e-ref>` (or window ref); read rendered placeholder/value visually. | JS cannot derive it (canvas-rendered, opaque widget), or to read/confirm rendered order for **native date input** (the reliable read — strategy 1's locale guess can diverge). | Non-deterministic (visual interpretation). |
   | 3 | **Read the attribute** — `uip rpa uia interact get <e-ref> <attribute>` for one attribute; `get-all <e-ref>` dumps all. `placeholder` (e.g. `MM/DD/YYYY`) is good explicit hint **when present**. | `placeholder` / explicit format attribute exists. | Deterministic, but `value` and accessibility value are **canonical/ISO** form — may NOT match displayed format. Never infer typing format from `value` alone for native date input. |

   Flags: [cli-reference.md § Interact](cli-reference.md#interact).
3. Format input to the detected display format, zero-padded, in rendered segment order (for example, ISO `2026-07-01` -> `07/01/2026`).
4. Type without emptying first (`NTypeInto` property `EmptyFieldMode` = `None`). Segmented/internal date state may break after emptying or `Ctrl+A`/`⌘A`+`Delete`. If stale content remains or overtyping fails, retry with an emptying mode. Confirm name/default in [../activities/TypeInto.md](../activities/TypeInto.md).
5. Check during authoring whether the segments auto-advance: type one segment and screenshot. Many desktop pickers do **not**: typing the whole date in one go fills the first segment and the remaining segments **silently keep their old values, with no error**. For those, type each segment separately and move with `[k(right)]` between them (`[k(tab)]` where right arrow does not move focus; token syntax in [../activities/TypeInto.md](../activities/TypeInto.md)). Do not add the key on pickers that do auto-advance, or a segment gets skipped.
6. Verify by asserting, not by absence of an error. Segmented controls often expose no `value`/text attribute, so `GetText`/`GetAttribute` cannot confirm the result. Use `CheckAppState` (`NCheckState`) on an element whose `name`/text is the **expected rendered date** (a long-form label, a summary line, or the saved record), and fail in the else branch.

## Dropdowns, lists, and comboboxes

`SelectItem` (`NSelectItem`) capability depends on `items`, not technology/tag/role; applies to native HTML `<select>`, WinForms/WPF, Java, SAP, and div/ARIA controls. Procedure and confirmation via `items`/`selecteditem`/`selecteditems`: [select-item-usage-guide.md](select-item-usage-guide.md).

- **`items` lists options** → control selectable; `SelectItem` drives it — pass one of listed values. No capturing individual option elements or opening list first.
- **`items` empty/absent** → not real option-list control. Fall back to click-to-open + click option (capture both as OR targets), or `TypeInto` for type-ahead / filter combos.

This includes Lightning `role="combobox"` buttons; selectable controls need no option-element capture.

## Debugging a failed interaction with an element

If interaction remounts target (focus, dropdown/popup expansion), next action can hit detached node: `InvalidNodeException: "The UI element is invalid..."`, distinct from "not found"/"click failed". Typical case: `TypeInto` click-before-typing detaches field. If selector still resolves and input-mode/delay changes do nothing, split into separate activities (for example, `Click`, then `TypeInto`) so second re-resolves target.

## Buttons disabled during async operations

Selector may match present but `disabled` button during validation/load/refresh. UIA retries target finding, not enabled state; Check App State waits for appearance/disappearance, not enabled. Set click `DelayBefore` and/or `DelayAfter` on activity, not standalone `Delay`.

- Use `DelayBefore` only when button has observable disabled→enabled transition driven by validation / load / refresh.
- Keep as small as reliably works — fixed wait, runs every execution. Raises odds button is enabled at click time; not a guarantee.

```xml
<uix:NClick DisplayName="Click Submit (form validates first)"
            DelayBefore="1"
            sap2010:WorkflowViewState.IdRef="NClick_1" />
```

```csharp
formScreen.Click(Descriptors.MyApp.Form.Submit, new NClickOptions { DelayBefore = 1 });
```

Confirm names/defaults/units in [../activities/TypeInto.md](../activities/TypeInto.md) / [../activities/Click.md](../activities/Click.md); do not author property surfaces from memory.
