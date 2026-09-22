# Advanced Selector Features

Matching modifiers and navigation available in any tag. Reference for
[selector-improvement-guide.md](selector-improvement-guide.md).

## Wildcard matching

Inside attribute values, for flexibility:

- `*` matches 0+ characters: `'*Excel 12.10.2025 - user *'` matches `'Editable Excel 12.10.2025 - user john.doe'`
- `?` matches exactly 1 character: `'FinalVersion?.xlsx'` matches `'FinalVersion3.xlsx'` but not `'FinalVersion10.xlsx'`

**When to use**

- Session/time-dependent data in values
- Values with useless info (spaces, symbols)
- Long attribute values — keep keywords, hide noise with `*`
- Non-standard characters — replace with `?`

## Regex matching

Apply with `matching:attributeName='regex'`:

```xml
<uia automationid='CalculatorResults' name='Display is \d' role='text' matching:name='regex' />
```

**When to use**

- Predictable patterns (emails, dates, IDs)
- Session/time-dependent data with consistent structure

**Critical:** update the attribute value so the regex pattern matches the original.

## Case-insensitive matching

Apply with `casesensitive:attributeName='false'`:

```xml
<uia name='Display is red' casesensitive:name='false' />
```

**When to use:** attributes varying in case (Red/RED/red). Rarely needed.

## Navigate up

Navigate to an ancestor before continuing the search:

```xml
<ctrl name='Configuration' /><nav up='2'/><ctrl name='One piece' />
```

**When to use:** anchoring to a related element for robustness. Never use `<nav up='0'/>` — it does nothing.
