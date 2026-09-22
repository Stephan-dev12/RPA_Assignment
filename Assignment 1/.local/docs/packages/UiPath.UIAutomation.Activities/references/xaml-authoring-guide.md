# XAML Authoring Guide (UI Automation)

Mode guide for authoring UIA activities in `.xaml` workflows. Read IN FULL before authoring any XAML UIA activity, AFTER the core [ui-automation-guide.md](../ui-automation-guide.md) — the core owns the shared law (mandatory target-generation gate, terminology, pitfalls, control-specific patterns, reading values); this guide owns the XAML activity model.

XAML-specific activity details: [../activities/](../activities/) — one file per activity, `activities/<Activity>.md`.

## Multi-Screen Authoring

> Here, "screen" means **capture screen** ([ui-automation-guide.md § Terminology](../ui-automation-guide.md#terminology--what-screen-means)): UI state requiring separate `uia-configure-target` pass after app advance, not Object Repository screen. One Object Repository entry can still represent multiple capture passes separated by `uip rpa uia interact` advances.

Honor caller ordering: capture-first tasks defer authoring until all targets register; otherwise add activities per capture screen as references arrive. Keep UI activities in `NApplicationCard`; validate each batch. First read [uia-configure-target-guide.md](uia-configure-target-guide.md) IN FULL.

## Key Concepts

### Application Card (Use Application/Browser)

Every workflow starts with **Application Card** (`uix:NApplicationCard`) opening/attaching desktop app or browser; all Click, TypeInto, GetText, etc. belong inside. Card has no app `FilePath`/URL; linked `TargetApp` identifies app ([§ Target Configuration](#target-configuration)).

> **Default: ONE card per attached application instance.** `ByInstance` covers main window, dialogs, popups, menus, and owned children. Add/nest for another instance/application/process or proven `ByInstance` failure; never per window/dialog/Object Repository screen.

#### Window Attach Mode

`AttachMode` (`NAppAttachMode`, default `ByInstance`) controls inner target search. Change per [../activities/ApplicationCard.md](../activities/ApplicationCard.md).

**`ByInstance` — Application Instance (default/preferred).** Finds selector window; attaches ALL instance windows (main/dialogs/children). Each activity uses its **scope selector** to choose instance window, then searches inside.

Use for separate same-instance windows (e.g. dialogs); one card covers all via activity scope selectors.

```xml
<uix:NApplicationCard AttachMode="ByInstance" DisplayName="Use App (Invoice app)"
                      sap2010:WorkflowViewState.IdRef="NApplicationCard_1" Version="V2">
    <uix:NApplicationCard.Body>
        <Sequence sap2010:WorkflowViewState.IdRef="Sequence_1">
            <!-- scope selector targets the main window -->
            <uix:NClick DisplayName="Click New Invoice" sap2010:WorkflowViewState.IdRef="NClick_1" />
            <!-- scope selector targets the dialog window of the same instance -->
            <uix:NTypeInto DisplayName="Type amount in dialog" Text="[in_Amount]"
                           sap2010:WorkflowViewState.IdRef="NTypeInto_1" />
        </Sequence>
    </uix:NApplicationCard.Body>
</uix:NApplicationCard>
```

**`SingleWindow` — narrower fallback only after demonstrated `ByInstance` failure.** Attaches only selector window; cannot find same-instance parent/child/dialog targets and always ignores activity scope selectors.

```xml
<uix:NApplicationCard AttachMode="SingleWindow" DisplayName="Use App (single window)"
                      sap2010:WorkflowViewState.IdRef="NApplicationCard_2" Version="V2">
    <uix:NApplicationCard.Body>
        <Sequence sap2010:WorkflowViewState.IdRef="Sequence_2">
            <!-- only targets in THIS window resolve; scope selector is ignored -->
            <uix:NClick DisplayName="Click Save" sap2010:WorkflowViewState.IdRef="NClick_2" />
        </Sequence>
    </uix:NApplicationCard.Body>
</uix:NApplicationCard>
```

#### One application instance = one card (even with multiple Object Repository screens)

Object Repository creates **screen** per distinct window selector (e.g. titled dialog/popup/child), not card: **Object Repository screens != Application Cards.** Window selectors determine screens; attached application instances determine cards. Matching `app=` signals compatibility, not instance identity.

`ByInstance` hosts activities across same-instance Object Repository screens. Each scope selector finds its window within instance; card selector need not match every screen. Owned dialogs/popups validate/run under one card without dedicated cards or "indicated element does not belong to the target application/browser" errors.

Concrete MS Paint File ▸ Open ▸ Cancel example: [§ Same-Instance Secondary Windows](#same-instance-secondary-windows--reuse-the-card-do-not-nest).

Never nest for second Object Repository screen or "scope/selector alignment"; `ByInstance` aligns via activity scope selector. Add card only after [escalation gate below](#nesting-application-cards).

#### Nesting Application Cards

> **Nest for another instance/application/process** (e.g. App A -> App B). Same-instance windows use one `ByInstance` card ([§ One application instance = one card](#one-application-instance--one-card-even-with-multiple-object-repository-screens)); nest same instance only after proven attach/find failure, never for another Object Repository screen.

Cards nest; activity can target any card on parent chain. For two-app switching, nest cards, place all activities in innermost, attach each to correct card.

`ScopeIdentifier` selects exact card `ScopeGuid`; omission selects nearest applicable card. Activity target must match selected card, not lexical ancestors. Attachment: [../activities/ApplicationCard.md](../activities/ApplicationCard.md).

**IMPORTANT:** Only configured-target activities may have `ScopeIdentifier`; never add it without target.

Example: App A outer, App B inner; both activities live inner. Read uses A `ScopeGuid`; write uses B. Repeat switching without card re-entry.

```xml
<uix:NApplicationCard AttachMode="ByInstance" DisplayName="App A (source)"
                      ScopeGuid="aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"
                      sap2010:WorkflowViewState.IdRef="NApplicationCard_1" Version="V2">
    <uix:NApplicationCard.Body>
        <Sequence sap2010:WorkflowViewState.IdRef="Sequence_1">
            <uix:NApplicationCard AttachMode="ByInstance" DisplayName="App B (target)"
                                  ScopeGuid="bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb"
                                  sap2010:WorkflowViewState.IdRef="NApplicationCard_2" Version="V2">
                <uix:NApplicationCard.Body>
                    <Sequence sap2010:WorkflowViewState.IdRef="Sequence_2">
                        <!-- ScopeIdentifier = App A card's ScopeGuid → reads from App A (outer) -->
                        <uix:NGetText DisplayName="Get value from App A" TextString="[out_Value]"
                                      ScopeIdentifier="aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"
                                      sap2010:WorkflowViewState.IdRef="NGetText_1" Version="V5" />
                        <!-- ScopeIdentifier = App B card's ScopeGuid → pastes into App B (inner) -->
                        <uix:NTypeInto DisplayName="Type value into App B" Text="[out_Value]"
                                       ScopeIdentifier="bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb"
                                       sap2010:WorkflowViewState.IdRef="NTypeInto_1" Version="V5" />
                    </Sequence>
                </uix:NApplicationCard.Body>
            </uix:NApplicationCard>
        </Sequence>
    </uix:NApplicationCard.Body>
</uix:NApplicationCard>
```

> GUIDs are placeholders. Generate card `ScopeGuid` via `uip rpa activities get-default-xaml` starter `NApplicationCard`; never hand-author. Set `ScopeIdentifier` to target card `ScopeGuid`. Keep GUIDs unique: unmatched usually fails at runtime; duplicate may bind wrong card. Validation may miss either.

#### Cross-Process Helper Dialogs (Sign-in, OAuth, System Pop-ups)

Some sign-in/consent/system dialogs spawn **separate processes**:

- Microsoft Store sign-in opens in `WWAHost.exe` (not `WinStore.App.exe`)
- Office desktop sign-in / Microsoft Account flows hosted in `WWAHost.exe` or `Microsoft.AAD.BrokerPlugin`
- OAuth pop-ups launched by an enterprise app into the system browser
- Save / Open / Print / UAC dialogs hosted by `consent.exe`, `dllhost.exe`, etc.

Helper-process activity inside original-app card fails validation:

```
The indicated element does not belong to the target application/browser.
```

Validator compares child `ScopeSelectorArgument` to selected card `TargetApp`; different `app=` always triggers error despite correct runtime selectors.

> **Identify attachment boundary.** Different `app=` requires another card; matching `app=` passes validation but does not prove same runtime instance. Reuse only confirmed same instance; otherwise add card. Top-level-window status adds none.

#### Same-Instance Secondary Windows — Reuse the Card (Do NOT Nest)

Most dialogs/property sheets/popups/children, including Win32 `#32770` Open/Save/Print/Properties, belong to same instance: same `app=`, different `cls=`/`title=`. Reuse its card; another instance needs another card.

Default `AttachMode="ByInstance"` attaches whole instance. Child `ScopeSelectorArgument` finds target window, including dialog when card `TargetApp` names main window. Second same-instance card adds only scope ([§ One application instance = one card](#one-application-instance--one-card-even-with-multiple-object-repository-screens)).

Matching child/card `app=` passes compatibility validation; difference triggers "does not belong...". Passing does not establish instance attachment.

**MS Paint File ▸ Open ▸ Cancel:** *Open* creates top-level Win32 `#32770`, captured as separate Object Repository screen in same attached Paint instance. Cancel `ScopeSelectorArgument`: `<wnd app='mspaint.exe' cls='#32770' title='Open' />`; card `TargetApp`: `<wnd app='mspaint.exe' cls='MSPaintApp' title='*Paint*' />`. `ByInstance` spans File/Open/Cancel; neither File menu nor dialog needs another card. Matching `app=` passes compatibility validation.

Use nested pattern for another attached instance/application/process or proven `ByInstance` failure.

#### Pattern: Nest a Second `NApplicationCard` for the Helper Process

Wrap helper-process activities in helper-scoped `NApplicationCard`. One card may span same-instance subdialogs using `uia-configure-target` CLI-stabilized/evaluated `title='*'`. Never hand-edit returned XAML; example shows final artifact.

```xml
<!-- Outer: original app -->
<uix:NApplicationCard ScopeGuid="<outer-guid>" Version="V2" HealingAgentBehavior="Job" ...>
  <uix:NApplicationCard.TargetApp>
    <uix:TargetApp Selector="&lt;wnd app='WinStore.App.exe' title='Microsoft Store' /&gt;" Version="V3" />
  </uix:NApplicationCard.TargetApp>
  <uix:NApplicationCard.Body>
    <ActivityAction x:TypeArguments="x:Object">
      <ActivityAction.Argument>
        <DelegateInArgument x:TypeArguments="x:Object" Name="WSSessionData" />
      </ActivityAction.Argument>
      <Sequence>
        <!-- Activity that triggers the helper-process launch (still in outer scope) -->
        <uix:NClick ScopeIdentifier="<outer-guid>" ... DisplayName="Click Sign In" ... />

        <!-- Inner: helper process (nested card) -->
        <uix:NApplicationCard ScopeGuid="<inner-guid>" Version="V2" HealingAgentBehavior="Job" ...>
          <uix:NApplicationCard.TargetApp>
            <uix:TargetApp Selector="&lt;wnd app='WWAHost.exe' title='*' /&gt;" Version="V3" />
          </uix:NApplicationCard.TargetApp>
          <uix:NApplicationCard.Body>
            <ActivityAction x:TypeArguments="x:Object">
              <ActivityAction.Argument>
                <DelegateInArgument x:TypeArguments="x:Object" Name="WSSessionDataInner" />
              </ActivityAction.Argument>
              <Sequence>
                <!-- Activities here use ScopeIdentifier="<inner-guid>" -->
                <uix:NTypeInto ScopeIdentifier="<inner-guid>" ... />
                <uix:NClick   ScopeIdentifier="<inner-guid>" ... />
              </Sequence>
            </ActivityAction>
          </uix:NApplicationCard.Body>
        </uix:NApplicationCard>

        <!-- Back in outer scope after the helper closes -->
        <uix:NCheckState ScopeIdentifier="<outer-guid>" ... DisplayName="Verify Signed In" ... />
      </Sequence>
    </ActivityAction>
  </uix:NApplicationCard.Body>
</uix:NApplicationCard>
```

**Rules:**

1. **One card per attached instance, not window.** Another instance/application/process needs another card; same-instance windows share one `ByInstance` card. Top-level status adds none.
2. **Target selected card.** `ScopeIdentifier` chooses exact `ScopeGuid`; omission chooses nearest card. Update when moving activity. Keep GUIDs unique; validation may miss unmatched/duplicate values.
3. **Card-level `HealingAgentBehavior`** uses `NHealingAgentBehavior` (`Job`/`Disabled`/`RecommendationOnly`) — not `SameAsCard` ([ui-automation-guide.md § Common UIA Pitfalls](../ui-automation-guide.md#common-uia-pitfalls)).
4. **Use helper-card `title='*'`** only for multiple same-instance subdialogs, after CLI stabilization and evaluation. Stable titles improve selectors but never determine card count.

Capture helper targets per [uia-configure-target-guide.md § Capturing Targets for Helper Processes](uia-configure-target-guide.md).

### Target Configuration

First read [uia-configure-target-guide.md](uia-configure-target-guide.md) IN FULL; register card screen and activity elements. Then write plain NApplicationCard/NClick/NTypeInto/... with unique `sap2010:WorkflowViewState.IdRef`, no `.Target` children; attach via [uia-target-attachment-guide.md](uia-target-attachment-guide.md).

Never hand-write `<uix:TargetApp>`/`<uix:TargetAnchorable>`; attach per [uia-target-attachment-guide.md](uia-target-attachment-guide.md).

A CV-resolved target is still an ordinary `TargetAnchorable` (`SearchSteps=CV`) and attaches via the `.Target` property to any activity that supports a target (e.g. `NClick`, `NGetText`, `NTypeInto`), like any other target. Never switch to the legacy `UiPath.CV.Activities` package for CV-resolved elements — it bypasses the Object Repository and is a separate, unsupported model here.

## Common Activities

Common: **Use Application/Browser** (required UI scope), **Click**, **Type Into**, **Get Text**, **Select Item**, **Check/Uncheck**, **Keyboard Shortcuts**, **Check App State** (branching), **Take Screenshot**, **Extract Table Data**, **ScreenPlay** (slow/non-deterministic last resort). Catalog: [§ Activities](#activities).

> **Before authoring `TypeInto` / `SelectItem` / `Click`:** reading [ui-automation-guide.md § Control-Specific Interaction Patterns](../ui-automation-guide.md#control-specific-interaction-patterns) is mandatory.
>
> **Before authoring `Get Text` / `Get Attribute`:** reading [ui-automation-guide.md § Reading Values from the UI](../ui-automation-guide.md#reading-values-from-the-ui) is mandatory.

## XAML-Specific Pitfalls

- **Missing `xmlns:uix`** — every UIA workflow needs `xmlns:uix="http://schemas.uipath.com/workflow/activities/uix"` on the root `<Activity>` element
- **`UiElement` is in the `ui:` namespace, not in the `uix:` namespace** — variables and arguments of type [`UiElement`](../activities/common/UiElement.md) are declared as `x:TypeArguments="ui:UiElement"` with `xmlns:ui="http://schemas.uipath.com/workflow/activities"`. The type is `UiPath.Core.UiElement` in assembly `UiPath.UiAutomation.Activities` (Windows) or `UiPath.UIAutomationNext.Activities` (portable). A `clr-namespace:UiPath.Core` declaration pointing at another assembly that also declares `UiPath.Core` (for example `UiPath.System.Activities`) loads the assembly successfully but then fails with a type-resolution error for `UiElement`; pointing at a missing or misspelled assembly instead fails with a `FileNotFoundException`/`FileLoadException` at XAML load time

## Activities

### UI Automation.Application

- [Use Application/Browser](../activities/ApplicationCard.md) — Opens desktop app/browser page.
- [Click](../activities/Click.md) — Clicks UI element.
- [Type Into](../activities/TypeInto.md) — Enters element text.
- [Get Text](../activities/GetText.md) — Extracts element text.
- [Select Item](../activities/SelectItem.md) — Selects dropdown item.
- [Check/Uncheck](../activities/CheckUncheck.md) — Checks, unchecks, or toggles checkbox.
- [Accessibility Check](../activities/AccessibilityCheck.md) — Checks accessibility issues.
- [Get Attribute](../activities/GetAttribute.md) — Gets element attribute value.
- [Check Element](../activities/CheckElement.md) — Checks enabled/disabled state.
- [Hover](../activities/Hover.md) — Hovers over element.
- [Highlight](../activities/Highlight.md) — Boxes element visually.
- [Keyboard Shortcuts](../activities/KeyboardShortcuts.md) — Sends one or more shortcuts to element.
- [Check App State](../activities/CheckAppState.md) — Branches user-defined actions on element existence.
- [Take Screenshot](../activities/TakeScreenshot.md) — Captures app/element image.
- [Save Image](../activities/SaveImage.md) — Writes an in-memory image to a file.
- [Mouse Scroll](../activities/MouseScroll.md) — Sends element scroll events.
- [Extract Table Data](../activities/ExtractData.md) — Extracts tabular data from page/app.
- [ScreenPlay](../activities/ScreenPlay.md) — Performs AI UI task on attached app.
- [Window Operation](../activities/WindowOperations.md) — Operates on window element.
- [Element Scope](../activities/ElementScope.md) — Attaches to element; contains multiple actions.
- [Block User Input](../activities/BlockUserInput.md) — Suppresses keyboard/mouse until configured key combination or timeout.
- [Unblock User Input](../activities/UnblockUserInput.md) — Reverses Block User Input.
- [Set Focus](../activities/SetFocus.md) — Sets element keyboard focus.
- [Get Clipboard](../activities/GetClipboard.md) — Gets system Clipboard data.
- [Set Clipboard](../activities/SetClipboard.md) — Sets Clipboard text.
- [Find Elements](../activities/FindElements.md) — Gets child elements.
- [For Each UI Element](../activities/ForEachUiElement.md) — Iterates structured `UiElements` set.
- [Set Text](../activities/SetText.md) — Enters element text.
- [Drag and Drop](../activities/DragAndDrop.md) — Drags source element to destination.
- [Keypress Event Trigger](../activities/KeyboardTrigger.md) — Triggers on indicated-element keypress.
- [Click Event Trigger](../activities/ClickTrigger.md) — Triggers on indicated-element click.
- [Application Event Trigger](../activities/ApplicationEventTrigger.md) — Triggers on indicated-element event.
- [Set Project Setting](../activities/SetProjectSetting.md) — Overrides a UI Automation project setting for the rest of the process.
- [Set CV Server](../activities/SetCVServer.md) — Overrides the Computer Vision server URL, API key and local-server usage at runtime.

### UI Automation.Browser

- [Go To URL](../activities/GoToURL.md) — Navigates indicated browser to URL.
- [Navigate Browser](../activities/NavigateBrowser.md) — Goes back/forward, closes, refreshes, or goes Home.
- [Get URL](../activities/GetURL.md) — Returns current browser URL.
- [Inject Js Script](../activities/InjectJsScript.md) — Runs JavaScript in `UiElement` page context.
- [Browser Dialog Scope](../activities/BrowserDialogScope.md) — Captures/handles alert, confirm, prompt dialogs.
- [Browser File Picker Scope](../activities/BrowserFilePickerScope.md) — Captures/handles browser file picker.
- [Set Runtime Browser](../activities/SetRuntimeBrowser.md) — Sets active runtime browser.
- [Get Browser Data](../activities/GetBrowserData.md) — Exports browser-instance session data.
- [Set Browser Data](../activities/SetBrowserData.md) — Imports session data into browser instance.

### UI Automation.OCR.Engine

- [Google Cloud Vision OCR](../activities/GoogleCloudOCR.md) — Extracts indicated-element text/data via Google Cloud Vision OCR. Use with Click OCR Text, Hover OCR Text, Double Click OCR Text, Get OCR Text, and Find OCR Text Position.
- [Tesseract OCR](../activities/TesseractOCR.md) — Extracts indicated-element text/data via Tesseract OCR. Use with Click OCR Text, Hover OCR Text, Double Click OCR Text, Get OCR Text, and Find OCR Text Position.
- [Microsoft Azure Computer Vision OCR](../activities/MicrosoftAzureComputerVisionOCR.md) — Microsoft Azure Computer Vision OCR

### UI Automation.SAP

- [Call Transaction](../activities/SAPCallTransaction.md) — Runs transaction code in current SAP GUI window.
- [SAP Login](../activities/SAPLogin.md) — Logs into SAP system.
- [Read Status Bar](../activities/SAPReadStatusbar.md) — Reads bottom SAP GUI Status Bar message.
- [Click Toolbar Button](../activities/SAPClickToolbarButton.md) — Lists available buttons after toolbar indication; clicks selected system/application toolbar button.
- [Select Menu Item](../activities/SAPSelectMenuItem.md) — Lists available items after main-window indication; selects one.
- [Expand Tree](../activities/SAPExpandTree.md) — Lists nodes/items after SAP Tree indication; expands parent to active node/item.
- [Table Cell Scope](../activities/SAPTableCellScope.md) — Attaches to Table element; contains multiple actions.
