# Selector Variables

Inject variable/argument values into configured selector values. Read this file whenever writing a `{{variable}}` token or a `string.Format` selector, to get the input syntax and the stored form right.

| Location | Authoring form | Result |
|---|---|---|
| Hand-authored XAML `InArgument<string>` | Write `string.Format` | Stored/runtime form |
| Definition (`window.xaml`, `target-n.xaml`) | Pass `{{variableName}}` to CLI `update-definition`; never hand-edit | CLI writes equivalent `string.Format` |

`{{variableName}}` is CLI input only, never stored. Every referenced variable must be declared as an XAML argument or enclosing activity variable (for example, parent `Sequence`); unresolved runtime token becomes literal text. Definition files belong to [`uia-configure-target`](../skills/uia-configure-target/SKILL.md): mutate windows with `target-app update-definition`, elements with `target-anchorable update-definition`.

## In XAML

Variable-capable selector `InArgument<string>` properties:

- `Selector` — selector on `TargetApp` (Use Application/Browser). Only `TargetApp` property supporting variables.
- `ScopeSelectorArgument` — window selector on `TargetAnchorable`.
- `FullSelectorArgument` — strict element selector on `TargetAnchorable`.
- `FuzzySelectorArgument` — fuzzy element selector on `TargetAnchorable`.

Rules:

- Positional placeholders: `{0}`, `{1}`, …
- Each placeholder binds, in order, to variables listed after format string.
- Escape literal `{` and `}` as `{{` and `}}`.

VB expression:

```text
String.Format("<webctrl id='{0}' tag='{1}' />", elementId, tagName)
```

C# expression:

```text
string.Format("<webctrl id='{0}' tag='{1}' />", elementId, tagName)
```

Entire selector may be bare variable (no `string.Format`):

```text
mySelector
```

### XAML example

`TargetAnchorable` example:

```xml
<uix:TargetAnchorable Version="V6">
  <uix:TargetAnchorable.ScopeSelectorArgument>
    <InArgument x:TypeArguments="x:String">[string.Format("&lt;wnd app='chrome.exe' title='{0} - Google Chrome' /&gt;", pageTitle)]</InArgument>
  </uix:TargetAnchorable.ScopeSelectorArgument>
  <uix:TargetAnchorable.FullSelectorArgument>
    <InArgument x:TypeArguments="x:String">[string.Format("&lt;webctrl id='{0}' tag='BUTTON' /&gt;", elementId)]</InArgument>
  </uix:TargetAnchorable.FullSelectorArgument>
  <uix:TargetAnchorable.FuzzySelectorArgument>
    <InArgument x:TypeArguments="x:String">[string.Format("&lt;webctrl id='{0}' /&gt;", elementId)]</InArgument>
  </uix:TargetAnchorable.FuzzySelectorArgument>
</uix:TargetAnchorable>
```

`TargetApp.Selector` example:

```xml
<uix:TargetApp Version="V3">
  <uix:TargetApp.Selector>
    <InArgument x:TypeArguments="x:String">[string.Format("&lt;wnd app='chrome.exe' title='{0} - Google Chrome' /&gt;", pageTitle)]</InArgument>
  </uix:TargetApp.Selector>
</uix:TargetApp>
```

## In definition files

Definition is serialized `TargetApp`/`TargetAnchorable` plus sibling `*.xaml.metadata`. CLI atomically rewrites both. Pass `{{variableName}}` to `update-definition`; never hand-edit or pass handwritten `string.Format`.

`{{...}}` input syntax:

- Token must be valid identifier; otherwise literal.
- Repeated variable uses same placeholder (`{0}`) and one trailing argument per distinct variable.
- Bare entire-selector variable (for example, `mySelector`) stores direct variable expression.

### Element selector (`target-anchorable`)

`--full-selector` (strict), `--fuzzy-selector`, `--scope-selector` (window), and `--semantic-selector` accept `{{variable}}`; `--full-selector` and `--fuzzy-selector` are mutually exclusive.

```bash
uip rpa uia target-anchorable update-definition \
  --definition-file-path "C:/path/to/target-1.xaml" \
  --full-selector "<webctrl data-test='{{testName}}' data-field='result' tag='INPUT' />"
```

CLI stores:

```xml
<uix:TargetAnchorable.FullSelectorArgument>
  <InArgument x:TypeArguments="x:String">[string.Format("&lt;webctrl data-test='{0}' data-field='result' tag='INPUT' /&gt;", testName)]</InArgument>
</uix:TargetAnchorable.FullSelectorArgument>
```

### Window selector (`target-app`)

`--selector` is only variable-capable `TargetApp` property.

```bash
uip rpa uia target-app update-definition \
  --definition-file-path "C:/path/to/window.xaml" \
  --selector "<wnd app='chrome.exe' title='{{pageTitle}} - Google Chrome' />"
```

CLI stores:

```xml
<uix:TargetApp.Selector>
  <InArgument x:TypeArguments="x:String">[string.Format("&lt;wnd app='chrome.exe' title='{0} - Google Chrome' /&gt;", pageTitle)]</InArgument>
</uix:TargetApp.Selector>
```

## Conversion between the two forms

| Form | Where it appears | Example |
|------|------------------|---------|
| `{{variable}}` | input to `update-definition` (CLI/UI "string view") | `<webctrl id='{{x}}' />` |
| `string.Format` | `InArgument` stored in XAML / definition file | `string.Format("<webctrl id='{0}' />", x)` |
