# Selector Improvement Guide

Improving a selector means identifying the **same** target node more reliably. Read the three must-read
references below plus the tag-type file for every tag in the selector; consult the rules and the success criteria.

## Reference files

### Must read

These three are part of the guide, not optional background. Read all of them before changing a selector.

| Reference | Covers |
| --- | --- |
| [advanced-features.md](advanced-features.md) | Wildcards, regex, case-insensitive matching, `<nav up>` |
| [element-purpose.md](element-purpose.md) | Attribute limits per activity — GetText, TypeInto, Check, SelectItem |
| [screenshot-instructions.md](screenshot-instructions.md) | Reading a screenshot for attribute candidates |

### Per tag type

Attribute reliability is per tag type. Read the file for every tag type present in the selector.

| Tag type | Reference |
| --- | --- |
| `wnd` | [wnd-instructions.md](tag-names-instructions/wnd-instructions.md) |
| `html` | [html-instructions.md](tag-names-instructions/html-instructions.md) |
| `webctrl` | [webctrl-instructions.md](tag-names-instructions/webctrl-instructions.md) |
| `uia` | [uia-instructions.md](tag-names-instructions/uia-instructions.md) |
| `ctrl` | [ctrl-instructions.md](tag-names-instructions/ctrl-instructions.md) |
| `java` | [java-instructions.md](tag-names-instructions/java-instructions.md) |

## Hard rules

A selector violating any of these is wrong, not merely weak.

1. **Never change the target.** The improved selector must still match the target node it was given.
2. **Never change a tag's type.** Tag type is bound to the node in the application; changing it invalidates the selector.
3. **Additional tags must come from the target's ancestry.** A tag matching a node outside the ancestor chain cannot resolve.
4. **Never add `idx`.** It is recomputed afterwards by a deterministic tool. Do not reason about it.
5. **Never trim an attribute value** unless the removed part is replaced by a wildcard or a regex. Trimming silently changes what the selector matches.

## Do

- Prefer semantic attributes over language-dependent or framework-generated ones. Which attributes are semantic, and how they rank, is per tag type — see the tag-type reference.
- Aim for 2-3 attributes per tag, and 2-4 tags overall.
- Add a tag when the target needs more context to be distinguished from similar elements.
- Prefer ancestors closest to the target — they are the most stable and the most informative.
- Anchor a table cell to its row or column, never a numeric row index. The attributes that do this differ per tag type.

## Don't

- Don't add an unreliable attribute that adds no differentiation.
- Don't keep every ancestry tag when the intermediate containers add no reliability.
- Don't repeat the same value across attributes. Text-carrying attributes often derive from each other and hold the same string for a node; when several carry the same value, keep only the highest-priority one. Priority, highest first, across all subsystems: `aria-label`, `ctrlname`, `name`, `title`, `aaname`, `text`, `visibleinnertext`, `innertext`.

  Example of redundancy — `visibleinnertext` and `aaname` carry the same string:

  ```xml
  <webctrl tag='DIV' visibleinnertext='This is a dummy text representation' />
  <webctrl tag='SPAN' aaname='This is a dummy text representation' />
  ```

## Success criteria

An improved selector:

- breaks no hard rule
- matches the target and nothing else, or matches as few similar elements as possible
- uses only attributes rated reliable for that tag type
- respects the element purpose
