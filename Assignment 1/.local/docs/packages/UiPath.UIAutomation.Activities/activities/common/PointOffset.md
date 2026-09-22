# PointOffset

The point an action is performed at, expressed as an anchoring point of the UI element's rectangle plus a horizontal and vertical displacement.

The same shape exists in two forms — in the activity (XAML) form `X` and `Y` are expressions (`InArgument<int>`), while the coded API takes plain values. `Position` is a plain `NPosition` in both and cannot be an expression.

- **Activity:** `UiPath.UIAutomationNext.PointOffset`
- **Coded API:** `UiPath.UIAutomationNext.API.Models.PointOffsetModel`

## Properties

| Property | Display Name | Activity Type | Coded API Type | Description |
|----------|-------------|---------------|----------------|-------------|
| `Position` | Anchoring point | `NPosition` | `NPosition` | Describes the starting point of the cursor to which offsets from `X` and `Y` properties are added. The following options are available: `TopLeft`, `TopRight`, `BottomLeft`, `BottomRight` and `Center`. The default option is `Center`. |
| `X` | Offset X | `InArgument<int>` | `int` | Horizontal displacement of the cursor position according to the option selected in the Anchoring point field. |
| `Y` | Offset Y | `InArgument<int>` | `int` | Vertical displacement of the cursor position according to the option selected in the Anchoring point field. |

On Drag and Drop the fields are labelled `Source anchoring point` / `Source X` / `Source Y` and `Destination anchoring point` / `Destination X` / `Destination Y`.

## Where to set the offset

Without an offset, an action happens at the center of the target element. The offset can be set in two places:

| Level | Activity (XAML) | Coded API | Shown in Studio as |
|-------|-----------------|-----------|--------------------|
| Activity | `PointOffset` (`SecondaryPointOffset` for the Drag and Drop destination) | `PointOffset` / `SecondaryPointOffset` on the options object | Enable offset point (Enable source / destination offset point on Drag and Drop) |
| Target | [`TargetAnchorable.PointOffset`](Target.md#targetanchorable) | `TargetAnchorableModel.PointOffset` | Click offset |

Set the offset in one place only. When both are set, the activity-level offset is used and the one on the target is ignored.

## XAML (activity)

```xml
<uix:PointOffset Position="Center">
  <uix:PointOffset.X>
    <InArgument x:TypeArguments="x:Int32">10</InArgument>
  </uix:PointOffset.X>
  <uix:PointOffset.Y>
    <InArgument x:TypeArguments="x:Int32">5</InArgument>
  </uix:PointOffset.Y>
</uix:PointOffset>
```

## Coded API

```csharp
var options = new ClickOptions
{
    PointOffset = new PointOffsetModel { Position = NPosition.TopLeft, X = 10, Y = 5 }
};
```
