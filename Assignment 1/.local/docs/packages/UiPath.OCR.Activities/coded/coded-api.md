# UiPath OCR Activities — Coded Workflow API

`UiPath.OCR.Activities`

Provides UiPath's first-party OCR engines (UiPath Document OCR and UiPath Extended Languages OCR) to coded workflows. Each engine is available in two flavors: a factory method that returns a configured `IOCRActivity` (to specify the OCR engine used by a host operation such as `pdf.ReadPdfWithOcr`), and direct methods that run OCR on a single input — an `IResource` (local file, Orchestrator asset, storage-bucket attachment) or an in-memory `System.Drawing.Image` — and return an `OCRResult` synchronously.

**Service accessor:** `ocr` (type `IOcrService`)
**Required package:** `"UiPath.OCR.Activities": "[{Version}]"` in `project.json` dependencies.

> **Platform:** the `ocr` service is currently available only for Windows projects.

## Auto-Imported Namespaces

The coded-workflow runtime auto-imports the following namespaces when the `UiPath.OCR.Activities` package is referenced. You do **not** need `using` directives for the types they contain:

```
UiPath.OCR.Activities.Api
UiPath.OCR.Contracts.DataContracts
UiPath.OCR.Contracts.Activities
```

The `ocr` accessor is auto-injected by the coded-workflow runtime — just call `ocr.<Method>(…)`.

For types that live outside the auto-imported list, add a `using` yourself:

| Type | Namespace | Add `using` when |
|---|---|---|
| `OCRRotation` | `UiPath.OCR.Contracts` | You read `OCRResult.Rotation` |
| `IResource`, `ILocalResource`, `LocalResource` | `UiPath.Platform.ResourceHandling` | You call an `IResource` direct-OCR overload or build a resource via `LocalResource.FromPath(...)` |
| `Image` | `System.Drawing` | You call an `Image` direct-OCR overload |
| `CancellationToken` | `System.Threading` | You pass a token to a direct-OCR overload |

Per-type → namespace lookup for everything else (all in auto-imported namespaces):

| Type | Namespace |
|---|---|
| `IOCRActivity` | `UiPath.OCR.Contracts.Activities` |
| `OCRResult`, `Word`, `Character`, `OCRCapabilities`, `TextType` | `UiPath.OCR.Contracts.DataContracts` |

## Service Overview

The `ocr` service exposes **two engines** (UiPath Document OCR and Extended Languages OCR), each in **two flavors**:

| Flavor | Methods | Use when |
|---|---|---|
| **Engine factory** | `GetUiPathDocumentOcr(…)`, `GetExtendedLanguagesOcr(…)` | You have a *file* (PDF/XPS) and another method needs you to specify which OCR engine to use (e.g. `pdf.ReadPdfWithOcr` accepts an `ocrEngine` parameter). The factory returns a configured `IOCRActivity` you pass to that method. |
| **Direct OCR** | `UiPathDocumentOcr(resource, …)` / `UiPathDocumentOcr(image, …)`, `ExtendedLanguagesOcr(resource, …)` / `ExtendedLanguagesOcr(image, …)` | You have a single input to recognize and want the OCR text back in this call. Pass an `IResource` for a file on disk or a platform resource (cross-platform-friendly — no `System.Drawing`), or a `System.Drawing.Image` you already hold in memory (a screenshot, a rasterized page). Synchronous — blocks the calling thread until OCR completes. |

**Choosing between engines:**
- **UiPath Document OCR** — first-party engine optimized for printed documents (invoices, contracts, receipts) in Latin-script languages. Default endpoint: `https://du.uipath.com/ocr`.
- **Extended Languages OCR** — backed by **Microsoft Azure Computer Vision (Read API)** via a UiPath-hosted proxy, with handwriting recognition enabled and document-understanding detection mode. Best suited for CJK (Chinese, Japanese, Korean) scripts and handwriting-heavy content. Default endpoint: `https://du.uipath.com/extended-ocr`.

Both engines accept an `apiKey` (required), optional `endpoint`, `language`, and `timeout` (ms). Direct-OCR methods additionally take a `CancellationToken`.

**API keys:** Obtain from **Admin → Licenses → Consumables** in your UiPath organization. Read the key from an Orchestrator asset/credential or a secrets manager at runtime — never hardcode it in source.

---

## Engine Factory Methods

These return a configured OCR engine (as an `IOCRActivity`) that other methods accept as their `ocrEngine` parameter — commonly `pdf.ReadPdfWithOcr` / `pdf.ReadXpsWithOcr`. The returned engine is stateless and reusable — instantiate once per workflow scope and reuse it across calls.

### `IOCRActivity GetUiPathDocumentOcr(string apiKey, string endpoint = "https://du.uipath.com/ocr", string language = "auto", int timeout = 100000)`

Creates a configured UiPath Document OCR engine.

**Parameters:**
- `apiKey` (`string`) — API key for the OCR service. See "API keys" in the Service Overview for sourcing.
- `endpoint` (`string`) — OCR service endpoint URL (default: `"https://du.uipath.com/ocr"`). Override for region-specific or on-prem endpoints.
- `language` (`string`) — Language hint for OCR (default: `"auto"`). Use BCP-47 codes (`"en"`, `"de"`, `"fr"`, etc.) or `"auto"` for automatic detection.
- `timeout` (`int`) — Per-request timeout in milliseconds (default: `100000` = 100 s).

**Returns:** `IOCRActivity` — A configured UiPath Document OCR engine. Pass it as the `ocrEngine` parameter to methods like `pdf.ReadPdfWithOcr` or `pdf.ReadXpsWithOcr` to specify the OCR engine to be used for the operation. If instead you already have an image in memory and want the OCR result directly, use `UiPathDocumentOcr(image, …)` below.

---

### `IOCRActivity GetExtendedLanguagesOcr(string apiKey, string endpoint = "https://du.uipath.com/extended-ocr", string language = "auto", int timeout = 100000)`

Creates a configured Extended Languages OCR engine. Same shape as `GetUiPathDocumentOcr`, different engine and endpoint default.

**Parameters:** Same as `GetUiPathDocumentOcr`, except the default `endpoint` is `"https://du.uipath.com/extended-ocr"`.

**Returns:** `IOCRActivity` — A configured Extended Languages OCR engine. Pass it as the `ocrEngine` parameter to a method that needs to specify which OCR engine to use.

---

## Direct OCR Methods

These run OCR on a single input and return an `OCRResult` synchronously. Each engine has two overloads:

- **`IResource` overload** — pass a resource (local file via `LocalResource.FromPath(...)`, an `ILocalResource` produced by another service such as `pdf.ExportPdfPageAsImage`, an Orchestrator asset, or a storage-bucket attachment). The resource is resolved to a local file and read into bytes internally, so no `System.Drawing` types appear in your code — this is the cross-platform-friendly flavor and the right default when your input is a file.
- **`Image` overload** — pass an in-memory `System.Drawing.Image` when you already have a bitmap loaded (e.g. a screenshot or a page you rasterized yourself). **Caller owns the `Image` lifetime** — dispose it after the call if you loaded it yourself.

### `OCRResult UiPathDocumentOcr(IResource resource, string apiKey, string endpoint = "https://du.uipath.com/ocr", string language = "auto", int timeout = 100000, CancellationToken ct = default)`

Runs UiPath Document OCR on the supplied resource. Synchronous — blocks the calling thread until OCR completes or the cancellation token fires.

**Parameters:**
- `resource` (`IResource`) — The image resource to process. Common producers: `LocalResource.FromPath(@"C:\scans\page.png")`, the `ILocalResource` returned by `pdf.ExportPdfPageAsImage(...)`, an Orchestrator asset or storage-bucket attachment.
- `apiKey` (`string`) — API key for the OCR service. See "API keys" in the Service Overview for sourcing.
- `endpoint` (`string`) — Endpoint URL (default: `"https://du.uipath.com/ocr"`).
- `language` (`string`) — Language hint (default: `"auto"`).
- `timeout` (`int`) — Per-request timeout in milliseconds (default: `100000`).
- `ct` (`CancellationToken`) — Cancellation token (default: `default` / `CancellationToken.None`).

**Returns:** `OCRResult` — Same shape as the `Image` overload below.

---

### `OCRResult ExtendedLanguagesOcr(IResource resource, string apiKey, string endpoint = "https://du.uipath.com/extended-ocr", string language = "auto", int timeout = 100000, CancellationToken ct = default)`

Runs Extended Languages OCR on the supplied resource. Synchronous. Same shape as `UiPathDocumentOcr(IResource, …)`, different engine and default endpoint.

**Returns:** `OCRResult`.

---

### `OCRResult UiPathDocumentOcr(Image image, string apiKey, string endpoint = "https://du.uipath.com/ocr", string language = "auto", int timeout = 100000, CancellationToken ct = default)`

Runs UiPath Document OCR on a single image. Synchronous — blocks the calling thread until OCR completes or the cancellation token fires.

**Parameters:**
- `image` (`System.Drawing.Image`) — The image to process. Common producers: `Image.FromFile("page.png")`, `Bitmap` from a screenshot.
- `apiKey` (`string`) — API key for the OCR service. See "API keys" in the Service Overview for sourcing.
- `endpoint` (`string`) — Endpoint URL (default: `"https://du.uipath.com/ocr"`).
- `language` (`string`) — Language hint (default: `"auto"`).
- `timeout` (`int`) — Per-request timeout in milliseconds (default: `100000`).
- `ct` (`CancellationToken`) — Cancellation token (default: `default` / `CancellationToken.None`). Honored at request granularity.

**Returns:** `OCRResult` — The recognition result. See "Return Types" below for field details. Returns `OCRResult.Empty` semantics on no-text images (empty `Text`, empty `Words[]`, `Confidence = 0`).

---

### `OCRResult ExtendedLanguagesOcr(Image image, string apiKey, string endpoint = "https://du.uipath.com/extended-ocr", string language = "auto", int timeout = 100000, CancellationToken ct = default)`

Runs Extended Languages OCR on a single image. Synchronous. Same shape as `UiPathDocumentOcr`, different engine.

**Parameters:** Same as `UiPathDocumentOcr`, except the default `endpoint` is `"https://du.uipath.com/extended-ocr"`.

**Returns:** `OCRResult` — Same shape as `UiPathDocumentOcr`.

---

## Return Types

### `IOCRActivity`

The configured OCR engine instance returned by `Get*Ocr` — opaque from your code's perspective. Pass it as the `ocrEngine` parameter of whatever method needs to know which OCR engine to use; you don't invoke its members directly. Namespace: `UiPath.OCR.Contracts.Activities`.

### `OCRResult` (namespace `UiPath.OCR.Contracts.DataContracts`)

The recognition result. Public properties:

| Property | Type | Description |
|---|---|---|
| `Text` | `string` | Concatenated recognized text. Empty string if no text was detected. |
| `Words` | `Word[]` | Per-word entries with text, polygon, confidence, character breakdown, and `TextType` (`Text`, `Checkbox`, `Handwriting`, `Barcode`, `QRcode`, `Stamp`, `Logo`, etc.). |
| `Confidence` | `int` | Aggregate confidence (0–100). |
| `SkewAngle` | `float` | Detected page skew angle in degrees (if the engine reports it; otherwise 0). |
| `Rotation` | `OCRRotation?` | Detected rotation (`None`, `Rotated90`, `Rotated180`, `Rotated270`, `Other`), or `null` if the engine doesn't compute it. |
| `OCRCapabilities` | `OCRCapabilities` | Flags describing what the engine actually computed: `CheckboxDetectionSupport`, `SkewAngleDetection`, `RotationDetection`. |
| `ImageHash` | `string` | Stable hash of the input image — useful for caching. |
| `OcrModelInfo` | `OcrModelInfo` | Model metadata; populated only by UiPath Document OCR. `null` for Extended Languages OCR. |

A static `OCRResult.Empty` is also exposed for convenience.

### `Word` (namespace `UiPath.OCR.Contracts.DataContracts`)

| Property | Type | Description |
|---|---|---|
| `Text` | `string` | The word's text content. |
| `PolygonPoints` | `PointF[]` | Exactly 4 points in clockwise order from top-left — the word's bounding quadrilateral. |
| `Confidence` | `int` | Word-level confidence (0–100). |
| `Characters` | `Character[]` | Per-character detail (text, polygon, confidence, font hints). |
| `TextType` | `TextType` | One of: `Unknown`, `Text`, `Checkbox`, `Handwriting`, `Barcode`, `QRcode`, `Stamp`, `Logo`, `Circle`, `Underline`, `Cut`. |

---

## Common Patterns

### 1. Hand an engine to PDF for OCR-driven reading (cross-package)

This is the most common use of the engine-factory flavor. Add both packages to `project.json`:
```json
"UiPath.OCR.Activities": "*",
"UiPath.PDF.Activities":  "*"
```

```csharp
public class ReadScannedInvoice : CodedWorkflow
{
    [Workflow]
    public void Execute()
    {
        // Resolve an OCR engine from the OCR service
        var engine = ocr.GetUiPathDocumentOcr(
            apiKey: Config["DocumentOcrApiKey"].ToString(),
            language: "en");

        // Hand it to the PDF service
        string text = pdf.ReadPdfWithOcr(
            fileName: @"C:\scans\invoice.pdf",
            ocrEngine: engine,
            degreeOfParallelism: 2,
            imageDpi: ImageDpi.High);

        Log($"Recognized {text.Length} characters");
    }
}
```

### 2. Direct OCR on a single image you loaded

```csharp
public class OcrScreenshot : CodedWorkflow
{
    [Workflow]
    public void Execute()
    {
        using var img = Image.FromFile(@"C:\captures\dialog.png");

        OCRResult result = ocr.UiPathDocumentOcr(
            image: img,
            apiKey: Config["DocumentOcrApiKey"].ToString(),
            language: "en");

        Log($"Text: {result.Text}");
        Log($"Confidence: {result.Confidence}");
        Log($"Words: {result.Words.Length}");
    }
}
```

### 2b. Direct OCR on a file — IResource overload, no System.Drawing

The file-input variant of Pattern 2. Also the flavor to prefer for cross-platform-leaning code, or when `System.Drawing` types are unavailable to the coded-workflow compiler.

```csharp
public class OcrScannedPage : CodedWorkflow
{
    [Workflow]
    public void Execute()
    {
        IResource page = LocalResource.FromPath(@"C:\scans\page-001.png");

        OCRResult result = ocr.UiPathDocumentOcr(
            resource: page,
            apiKey: Config["DocumentOcrApiKey"].ToString(),
            language: "en");

        Log($"Text: {result.Text} (confidence {result.Confidence})");
    }
}
```

An `ILocalResource` produced by another service passes straight in — e.g. rasterize a PDF page with `pdf.ExportPdfPageAsImage(...)` and hand its return value to `ocr.UiPathDocumentOcr(pageImage, apiKey)`.

### 3. CJK (Chinese / Japanese / Korean) or handwriting-heavy content — use Extended Languages OCR

```csharp
public class OcrJapaneseReceipt : CodedWorkflow
{
    [Workflow]
    public void Execute()
    {
        using var img = Image.FromFile(@"C:\receipts\receipt-ja.png");

        OCRResult result = ocr.ExtendedLanguagesOcr(
            image: img,
            apiKey: Config["ExtendedLanguagesOcrApiKey"].ToString(),
            language: "ja");

        Log(result.Text);
    }
}
```

### 4. Iterate the words to find barcodes and checkboxes

`Word.TextType` lets you filter by what the engine detected.

```csharp
public class FindCheckboxes : CodedWorkflow
{
    [Workflow]
    public void Execute()
    {
        using var img = Image.FromFile(@"C:\forms\application.png");

        OCRResult result = ocr.UiPathDocumentOcr(
            image: img,
            apiKey: Config["DocumentOcrApiKey"].ToString());

        foreach (var w in result.Words.Where(w => w.TextType == TextType.Checkbox))
        {
            // PolygonPoints[0] is the top-left corner
            Log($"Checkbox '{w.Text}' at ({w.PolygonPoints[0].X}, {w.PolygonPoints[0].Y})");
        }
    }
}
```

### 5. Direct OCR with a cancellation token (long-running workflows)

```csharp
public class TimedOcr : CodedWorkflow
{
    [Workflow]
    public void Execute()
    {
        using var cts = new CancellationTokenSource(TimeSpan.FromSeconds(30));
        using var img = Image.FromFile(@"C:\scans\big-page.png");

        try
        {
            OCRResult result = ocr.UiPathDocumentOcr(
                image: img,
                apiKey: Config["DocumentOcrApiKey"].ToString(),
                timeout: 60000,
                ct: cts.Token);

            Log(result.Text);
        }
        catch (OperationCanceledException)
        {
            Log("OCR timed out after 30 s — moving on.");
        }
    }
}
```

### 6. Custom endpoint (on-prem / alternate region)

```csharp
public class OnPremOcr : CodedWorkflow
{
    [Workflow]
    public void Execute()
    {
        var engine = ocr.GetUiPathDocumentOcr(
            apiKey: Config["OnPremOcrApiKey"].ToString(),
            endpoint: "https://ocr.internal.contoso.com/ocr",
            language: "auto",
            timeout: 180000);   // larger timeout for slower on-prem service

        // ... hand 'engine' to pdf.ReadPdfWithOcr or similar
    }
}
```

---

## Notes for Coding Agents

- **Windows only.** The `ocr` service is currently available only for Windows projects.
- **No `using` blocks needed on `IOCRActivity` or `OCRResult`.** Neither return type is `IDisposable`. The `System.Drawing.Image` *you* pass to direct-OCR methods, however, **is** disposable — wrap it in `using` if you loaded it yourself. `IResource` inputs need no disposal.
- **Prefer the `IResource` overloads when the input is a file or platform resource.** They keep `System.Drawing` types out of user code (cross-platform-friendly, and immune to hosts where `System.Drawing.Common` is not on the coded-workflow compile reference list), and compose directly with resources returned by other services (e.g. `pdf.ExportPdfPageAsImage`). Add `using UiPath.Platform.ResourceHandling;` for `IResource` / `LocalResource`. Reserve the `Image` overloads for bitmaps you already hold in memory.
- **The engines returned by the factory methods are reusable.** `GetUiPathDocumentOcr(...)` returns a configured, stateless OCR engine. Call the factory once per workflow scope and pass the same `IOCRActivity` to as many methods as need to share the same configuration.
- **Pass — don't invoke — the configured engine.** `IOCRActivity` is meant to be handed to a method that takes an `ocrEngine` parameter (e.g. `pdf.ReadPdfWithOcr`). If you have an image in memory and want the OCR result yourself, call `UiPathDocumentOcr(image, …)` / `ExtendedLanguagesOcr(image, …)` directly.
- **API keys come from Admin → Licenses → Consumables in your UiPath organization.** Read them via `Config[...]`, an Orchestrator asset/credential, or a keyvault — never hardcode them in the source.
- **Direct OCR is synchronous.** Both `*Ocr(image, …)` methods block the calling thread until the HTTP call returns or the timeout fires. They do **not** offer async overloads — pass a `CancellationToken` if you need to cancel cooperatively.
- **`Word.PolygonPoints` is always 4 points clockwise from top-left.** If you only need a bounding box, the top-left is `PolygonPoints[0]` and the bottom-right is `PolygonPoints[2]`.
- **Default timeout is 100 seconds.** Increase via the `timeout` parameter for slow networks or larger images; decrease if your workflow has its own retry/SLA budget.
