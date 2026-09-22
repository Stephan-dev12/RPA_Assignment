# Coded Authoring Guide (UI Automation)

Mode guide for authoring UIA calls in coded C# workflows. Read IN FULL before authoring any coded UIA call, AFTER the core [ui-automation-guide.md](../ui-automation-guide.md) — the core owns the shared law (mandatory target-generation gate, terminology, pitfalls, control-specific patterns, reading values); this guide owns the coded API model.

**Service accessor:** `uiAutomation` (type `IUiAutomationAppService`)

Coded-specific API: [coded-api.md](../coded/coded-api.md).

## Workflow Pattern

1. **Open/Attach** application screen; receive `UiTargetApp`.
2. Use handle for Click, TypeInto, GetText, etc.
3. `UiTargetApp` is `IDisposable`; dispose via `using` or manually.

## Screen Handle Affinity (Critical)

> Here, "screen" means **Object Repository screen** (`Descriptors.<App>.<Screen>.<Element>`), not capture screen ([ui-automation-guide.md § Terminology](../ui-automation-guide.md#terminology--what-screen-means)).

**Each `UiTargetApp` binds one Object Repository screen.** Descriptors require their screen's handle; Screen A descriptor on Screen B handle fails: `"Target name 'X' is not part of the current screen."`.

```csharp
// CORRECT — use Home elements on the homeScreen handle
var homeScreen = uiAutomation.Open(Descriptors.MyApp.Home);
homeScreen.Click(Descriptors.MyApp.Home.Products);   // OK

// Then attach to the next screen for its elements
var formScreen = uiAutomation.Attach(Descriptors.MyApp.Form);
formScreen.TypeInto(Descriptors.MyApp.Form.Email, "test@example.com");  // OK

// WRONG — using a Home element on the Form screen handle
formScreen.Click(Descriptors.MyApp.Home.Loans);  // FAILS
```

In multi-screen flows, finish one screen before attaching next.

## Target Resolution

`UiTargetApp` methods accept:

- **`string target`** — target name defined in the Object Repository screen.
- **`IElementDescriptor elementDescriptor`** — strongly-typed Object Repository descriptor (e.g., `Descriptors.MyApp.LoginScreen.Username`).
- **`TargetAnchorableModel target`** — via the `UiTargetApp` indexer (`app["targetName"]`, `app[Descriptors.MyApp.Screen.Element]`) or built from a CLI-captured selector with `Target.FromSelector("<…/>")` ([§ Selector-Only Targets](#selector-only-targets-no-object-repository)).
- **`RuntimeTarget target`** — runtime target returned by `GetChildren` or `GetRuntimeTarget`.

## Finding Descriptors (Mandatory)

**MANDATORY for `uiAutomation.*`:** follow strict order; stop at first matching descriptor.

> **CRITICAL:** Steps 1 → 2 → 3 → 4 MUST be followed sequentially. NEVER skip to Step 4 (UITask).

### Step 1 — Check the project's Object Repository

Read `<PROJECT_DIR>/.local/.codedworkflows/ObjectRepository.cs`: `Descriptors` class with `Descriptors.<App>.<Screen>.<Element>` hierarchy.

> **This file is generated and it LAGS the Object Repository.** Registering a screen or element does not update it by itself, so the copy on disk routinely describes an older OR than the one you just wrote to. **Reading it before regenerating is the single most common way to conclude an element "doesn't exist" when it does.** Two states look like an answer but are not:
>
> - **Empty body — `public static class Descriptors { }` — or no file at all.** Neither means "no elements are registered". The file has not been (re)generated since the OR gained them. On a freshly scaffolded project this is the normal starting state, including immediately after a successful `create-elements`.
> - **Body present, but an element you just registered is absent or carries an older name.** Same cause. Regenerate and re-read before treating it as missing.
>
> **Regeneration:** per-file `uip rpa validate --file-path "<ANY>.cs" --project-dir "<PROJECT_DIR>" --output json` rewrites the file when it is missing or the Object Repository changed. The host generates it only after loading the project with a `[Workflow]`/`[TestCase]` `.cs` present, so write the coded stub before the first `uip rpa` command of the session (registering it in `project.json` `entryPoints` is not required and does not help).
>
> Install the UIA package (and any other activity packages) before that first command too: `CodedWorkflow.cs`'s `uiAutomation` accessor is baked from the packages present when the host first loads the project, and unlike `ObjectRepository.cs` it does not refresh in-session. Installing a package afterward needs a full regen — delete `.local/.codedworkflows/`, restart the host, `validate`.
>
> **Write the coded stub before capture:**
>
> ```csharp
> public class <WorkflowName> : CodedWorkflow
> {
>     [Workflow]
>     public void Execute() { }
> }
> ```
>
> After capture run `validate` once and read real member names from the file before writing the body.

If the file cannot be regenerated, enumerate the saved registered apps/screens/elements without regeneration:

```bash
uip rpa get-object-repository --project-dir "<PROJECT_DIR>" --output json
```

Returns the App → Screen → Element tree, each entry carrying `name`, `description`, `type`, `reference`. Confirm existence before authoring; strongly typed `Descriptors.<App>.<Screen>.<Element>` still requires `ObjectRepository.cs`. The verb is **top-level and hyphenated** — there is no `uip rpa object-repository` group (`Unknown command: object-repository`), and the `uip rpa uia object-repository` group has no `get`. Returned names are OR names, not C# members — convert per § Descriptor Naming.

Add Object Repository namespace:
```csharp
using <ProjectNamespace>.ObjectRepository;
```

### Step 2 — Check UILibrary NuGet packages

Check `project.json` `dependencies` for `*.UILibrary`, `*.ObjectRepository`, `*.Descriptors`, `*.UIAutomation`; inspect via `uip rpa packages inspect`.

List library-exposed apps/screens/elements (not merely assembly API) from its `.nupkg` Object Repository: run `uip rpa get-library-object-repository --output json`, pointing at library `.nupkg` path(s). Same hyphenated top-level shape as `get-object-repository`, not an `object-repository get-library` subcommand.

For UILibrary, use **package**, not project, namespace:
```csharp
using <PackageNamespace>.ObjectRepository;
```

### Step 3 — Configure the target

[uia-configure-target-guide.md](uia-configure-target-guide.md) MUST be read IN FULL first.

After completion, re-read `ObjectRepository.cs`; search returned reference IDs for exact `Descriptors.<App>.<Screen>.<Element>` paths.

### Step 4 — UITask / ScreenPlay (last resort only)

ScreenPlay (`UITask`) performs AI UI interactions without precise selectors. Use **only** when Step 3 selectors are genuinely unreliable.

### Descriptor Naming — read the generated names, never predict them

An Object Repository name is not used verbatim as the C# member. **Every character invalid in a C# identifier becomes `_`** — spaces, `-`, `.`, `(`, `)`, including a trailing space. OR name `Test Click 2018 WPF x86 v2.0(1)` generates member `Test_Click_2018_WPF_x86_v2_0_1_`. (A `.` behaves oppositely in the project *namespace*, where it survives as a namespace separator.) So the OR name and the descriptor path differ:

| OR element name | Generated member |
|---|---|
| `Five` | `Descriptors.<App>.<Screen>.Five` |
| `Equals Button` | `Descriptors.<App>.<Screen>.Equals_Button` |
| `Result Display` | `Descriptors.<App>.<Screen>.Result_Display` |

Predicting the identifier (`EqualsButton`, `ResultDisplay`) yields `CS1061: '__<Screen>' does not contain a definition for '<Name>'`. Take every member name from the regenerated `ObjectRepository.cs` (§ Step 1), not from the `--name` values passed to `create-elements`.

**The `<App>` segment is not the app name verbatim either, and its shape depends on the screen nested inside it.** When the app name equals the screen name, the generated app container carries a `__` prefix — C# forbids a member whose name matches its enclosing type — but when the two differ, the app keeps its plain sanitized name:

| OR app → screen | Generated path |
|---|---|
| `Calculator` → `Calculator` | `Descriptors.__Calculator.Calculator.<Element>` |
| `Calculator_App` → `Calculator` | `Descriptors.Calculator_App.Calculator.<Element>` |

`__` is therefore **not** a blanket app-segment convention to apply by rule. A wrong app segment also fails differently from a wrong element name: **`CS0117` blames the app segment, `CS1061` the screen or element member.**

**Do NOT rename Object Repository entries to avoid imagined C# collisions.** Names matching `System.Object` members are safe: an element named `Equals` generates `public __Equals Equals { get; private set; }` and validates, builds, and runs clean — the property hides `object.Equals` harmlessly and does not even raise a hiding warning. A defensive rename desynchronizes the OR name from the UI label it describes and fixes nothing. If a name genuinely fails to compile, the generated file will say so — react to that, not to a guess.

> **Renaming an OR element rewrites your source files.** When an element is renamed, Studio does not merely regenerate `ObjectRepository.cs` — it also rename-refactors every `Descriptors.*` call site in the project's coded workflows, in the same sub-second pass. Renaming `Plus` to `Plus Operator` rewrote `calculator.Click(...Standard.Plus)` to `calculator.Click(...Standard.Plus_Operator)` on disk, unprompted.
>
> Consequences worth planning for: a rename does **not** leave call sites broken for you to fix, so it is cheaper than it looks; but any cached or in-flight view of a coded `.cs` goes stale the instant an OR element is renamed. **Re-read every affected `.cs` after an OR rename** rather than writing over it from a stale copy — an editor or agent holding the pre-rename text will silently revert Studio's refactor.

## Selector-Only Targets (no Object Repository)

`Attach`/`Open` accept a `TargetAppModel`, and every `UiTargetApp` action accepts a `TargetAnchorableModel` built by the static `Target` factories — no Object Repository entry, no `ObjectRepository.cs`. Both types and `Target` live in `UiPath.UIAutomationNext.API.Models`.

**Use when** the project has no Object Repository, the selector is computed at runtime (row index, loop variable, dynamic title), or the workflow receives selectors as arguments. **Otherwise use descriptors** (§ Finding Descriptors): they carry anchors, CV, and image data, and Studio rename-refactors call sites. `Target` has no anchor factory — a target that needs an anchor stays on the descriptor path.

Selectors still come from target capture (core guide § Mandatory: Generate Targets) — take them from the captured definitions instead of registering them. Keep each selector as a named constant or an input parameter.

```csharp
using UiPath.UIAutomationNext.API.Models;
using UiPath.UIAutomationNext.Enums;

// Launch or reuse — FilePath/Arguments start the app when the selector finds no window
using var app = uiAutomation.Open(new TargetAppModel
{
    Selector = "<wnd app='Numbers'/>",
    FilePath = "/Applications/Numbers.app/Contents/MacOS/Numbers",
    Arguments = docPath,
    IsExactTitleEnabled = true,
}, new TargetAppOptions { OpenMode = NAppOpenMode.IfNotOpen, CloseMode = NAppCloseMode.Never });

// Already running
var sap = uiAutomation.Attach(new TargetAppModel().WithSelector("<wnd app='*' title='S4H (1) (*)*' />"));

// Runtime-computed selector; full (window included) or partial under the attached app
var cell = Target.FromSelector($"<wnd app='Numbers' title='invoices*'/><ax role='AXTable'/><ax role='AXRow' title='{rowId}'/><ax role='AXCell' idx='1'/>");
app.TypeInto(cell, new TypeIntoOptions
{
    Text = value,
    EmptyFieldMode = NEmptyFieldMode.SingleLine,
    ClickBeforeMode = NClickMode.Single,
    InteractionMode = NChildInteractionMode.Simulate,
});
sap.Click(Target.FromSelector("<sap id='tbar[1]/btn[8]' />"), new ClickOptions { ClickType = NClickType.Single, MouseButton = NMouseButton.Left, InteractionMode = NChildInteractionMode.Simulate });
if (!sap.WaitState(Target.FromSelector("<sap id='usr/cntlGRID1/shellcont/shell' />"), NCheckStateMode.WaitAppear, 5))
    throw new Exception("Grid did not appear");
var text = app.GetText(cell, new GetTextOptions { ScrapingMethod = NScrapingMethod.TextAttribute });
```

- `TargetAppModel`: `Selector`, `FilePath`, `Arguments`, `Title`, `Url`, `BrowserType`, `IsExactTitleEnabled`, `Area`. `TargetAppOptions` is the same as on the descriptor path (`OpenMode`, `AttachMode`, `CloseMode`, `Timeout`, `InteractionMode` as `NInteractionMode`, `WebDriverMode`, `WindowResize`, `DialogHandlingOptions`); disposing the handle closes the app unless `CloseMode = NAppCloseMode.Never`.
- `Target` factories: `FromSelector`, `FromFuzzySelector`, `FromSemanticSelector`, `FromImage(imagePath, accuracy)`, `FromComputerVision(...)`; chain `WithScopeSelector`, `WithFuzzySelector(selector, fuzzyAccuracy, fuzzyMatches)`, `WithSemanticSelector`, `WithPointOffset`, `WithFriendlyName`.
- Action options carry the input method as `NChildInteractionMode` (`ClickOptions`, `TypeIntoOptions`); only `TargetAppOptions.InteractionMode` is `NInteractionMode`. `ClickOptions.ClickType` is `NClickType`; `TypeIntoOptions.ClickBeforeMode` is `NClickMode`.
- One `UiTargetApp` per app selector; screen handle affinity does not apply (there is no screen), but a target must still resolve under the attached window.

## Coded-Specific Pitfalls

- **Missing ObjectRepository using** — without `using <ProjectNamespace>.ObjectRepository;`: `CS0103: The name 'Descriptors' does not exist in the current context`
- **Screen handle mismatch** — element descriptor on wrong screen handle causes `"Target name 'X' is not part of the current screen."` Always use the correct handle for each screen's elements.
- **Stale `ObjectRepository.cs` read as truth** — `CS1061: '__<Screen>' does not contain a definition for '<Element>'` after a successful `create-elements` usually means the file had not regenerated yet, not that the element is missing. Re-read it (§ Step 1) before re-capturing anything. If it stays empty or missing, the cause is a missing precondition or trigger — no coded `.cs` on disk, or no per-file `validate` since the OR write — not a missing OR CLI call.
- **Block-bodied `using` aborts the run verdict** — `using (var app = uiAutomation.Open(...)) { ... }` raises `IDE0063` ("'using' statement can be simplified"). That diagnostic lands in the run's `Data.errors` and flips `Data.output` to `"Execution aborted. See attached errors for more information"` **even though the workflow body executed and logged normally** — the run reads as failed while the automation actually worked. Use the C# 8 declaration form:

    ```csharp
    using var app = uiAutomation.Open(Descriptors.MyApp.Home);   // not: using (var app = ...) { }
    ```

- **`LogLevel` is ambiguous when `UiPath.Core.Activities` is imported** — `CS0104: 'LogLevel' is an ambiguous reference between 'UiPath.Core.Activities.LogLevel' and 'UiPath.CodedWorkflows.LogLevel'`. The built-in `Log(message, level)` takes the `UiPath.CodedWorkflows` one, which `using UiPath.CodedWorkflows;` already provides — drop the `UiPath.Core.Activities` import unless the file needs another type from it.
