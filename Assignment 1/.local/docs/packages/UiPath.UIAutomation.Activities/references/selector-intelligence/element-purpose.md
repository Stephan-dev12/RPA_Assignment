# Element Purpose

Element purpose is the activity the selector will be used by. It constrains which attributes are safe on
the **target** tag. Reference for [selector-improvement-guide.md](selector-improvement-guide.md).

## GetText / ExtractData / TypeInto

Applies only to the TARGET tag — the element whose text is read or typed into.

- Avoid on target: `text`, `aaname`, `visibleinnertext`, `innertext`, `value`
- Use on target: stable structural attributes (`automationid`, `role`, `aria-label`, `id`, `labeledby`, `data-testid`, `tag`, `colName`)
- Why: filtering the target by the text about to be extracted is circular — the value may be unknown, dynamic, or user-entered at runtime.

Does NOT apply to ancestor tags:

- Ancestor `visibleinnertext`, `innertext`, `aaname` are usable when they add differentiation the target cannot provide — pinning the target inside a table row, card or section.
- An ancestor's text is different content from the target's, so there is no circularity.
- Do not add them when structural attributes already identify the target uniquely; prefer the minimal selector.

Bad — filters the target by its own content:

```xml
<webctrl aaname='RDP app cards : wrong runtime exception for Single window attach mode' tag='A' />
<webctrl data-testid='issue-field-summary-inline-edit-link.ui.read.content' tag='DIV' />
```

```xml
<webctrl tag='A' />
<webctrl data-testid='issue-field-summary-inline-edit-link.ui.read.content' visibleinnertext='RDP app cards : wrong runtime exception for Single window attach mode' tag='DIV' />
```

Good — target tag carries only structural identifiers:

```xml
<webctrl data-testid='software-backlog.card-list.accordion' tag='DIV' />
<webctrl data-testid='*UI-37551*' tag='DIV' />
<webctrl data-testid='*summary*content*' tag='DIV' />
```

Good — ancestor text pins the target inside a table row:

```xml
<html app='msedge.exe' title='Cryptocurrency Prices, Live Charts, Market Cap, News - Crypto.com EEA' />
<webctrl tag='TABLE' />
<webctrl parentid='cdc-market-body' tag='TR' visibleinnertext='*ETH*' />
<webctrl tag='TD' colName='Price' />
<webctrl tag='P' />
```

## Check / Uncheck

- Avoid: state-reflecting attributes (`checked`, `unchecked`, `aastate`)
- Use: stable identifiers independent of checkbox state
- Why: the state changes between checked and unchecked

## SelectItem

- Avoid: attributes reflecting the currently selected item (`selecteditem`, `value` with a specific selection)
- Use: stable identifiers of the dropdown/combobox itself
- Why: the selected item changes with user choice

## Other actions

Any reliable attribute appropriate for the element type. No special restrictions.
