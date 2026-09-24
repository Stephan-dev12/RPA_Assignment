$ErrorActionPreference = 'Stop'

$workflowPath = 'C:\Users\naina\OneDrive\Desktop\Software Engineering Year 3\RPA_Assignment\Assignment 1\ExtractandValidate.xaml'
$activityNs = 'http://schemas.microsoft.com/netfx/2009/xaml/activities'
$xNs = 'http://schemas.microsoft.com/winfx/2006/xaml'
$sap2010Ns = 'http://schemas.microsoft.com/netfx/2010/xaml/activities/presentation'
$uiNs = 'http://schemas.uipath.com/workflow/activities'
$xmlnsNs = 'http://www.w3.org/2000/xmlns/'
$sysNs = 'clr-namespace:System;assembly=System.Private.CoreLib'
$ioNs = 'clr-namespace:System.IO;assembly=System.Private.CoreLib'

$doc = New-Object System.Xml.XmlDocument
$doc.PreserveWhitespace = $true
$doc.Load($workflowPath)
$root = $doc.DocumentElement

function Ensure-Namespace([string]$prefix, [string]$uri) {
    if (-not $root.GetNamespaceOfPrefix($prefix)) {
        $attribute = $doc.CreateAttribute('xmlns', $prefix, $xmlnsNs)
        $attribute.Value = $uri
        $root.Attributes.Append($attribute) | Out-Null
    }
}

Ensure-Namespace 'sys' $sysNs
Ensure-Namespace 'io' $ioNs

function New-Activity([string]$name) {
    return $doc.CreateElement($name, $activityNs)
}

function New-UiActivity([string]$name) {
    return $doc.CreateElement('ui', $name, $uiNs)
}

function Set-PlainAttribute([System.Xml.XmlElement]$node, [string]$name, [string]$value) {
    $node.SetAttribute($name, $value)
}

function Set-NamespaceAttribute([System.Xml.XmlElement]$node, [string]$localName, [string]$namespaceUri, [string]$value) {
    $node.SetAttribute($localName, $namespaceUri, $value)
}

function Add-Assign([System.Xml.XmlElement]$sequence, [string]$target, [string]$targetType, [string]$value, [string]$valueType) {
    $assign = New-Activity 'Assign'
    $to = New-Activity 'Assign.To'
    $out = New-Activity 'OutArgument'
    Set-NamespaceAttribute $out 'TypeArguments' $xNs $targetType
    $out.InnerText = $target
    $to.AppendChild($out) | Out-Null
    $assign.AppendChild($to) | Out-Null

    $valueProperty = New-Activity 'Assign.Value'
    $in = New-Activity 'InArgument'
    Set-NamespaceAttribute $in 'TypeArguments' $xNs $valueType
    $in.InnerText = $value
    $valueProperty.AppendChild($in) | Out-Null
    $assign.AppendChild($valueProperty) | Out-Null
    $sequence.AppendChild($assign) | Out-Null
}

function Add-Log([System.Xml.XmlElement]$sequence, [string]$displayName, [string]$level, [string]$messageExpression) {
    $log = New-UiActivity 'LogMessage'
    Set-PlainAttribute $log 'DisplayName' $displayName
    Set-PlainAttribute $log 'Level' $level
    Set-PlainAttribute $log 'Message' $messageExpression
    $sequence.AppendChild($log) | Out-Null
}

function New-Catch([string]$catchType, [string]$argumentName, [string]$displayName, [string]$messageExpression, [string]$logLevel) {
    $catch = New-Activity 'Catch'
    Set-NamespaceAttribute $catch 'TypeArguments' $xNs $catchType

    $action = New-Activity 'ActivityAction'
    Set-NamespaceAttribute $action 'TypeArguments' $xNs $catchType

    $argumentProperty = New-Activity 'ActivityAction.Argument'
    $delegateArgument = New-Activity 'DelegateInArgument'
    Set-NamespaceAttribute $delegateArgument 'TypeArguments' $xNs $catchType
    Set-PlainAttribute $delegateArgument 'Name' $argumentName
    $argumentProperty.AppendChild($delegateArgument) | Out-Null
    $action.AppendChild($argumentProperty) | Out-Null

    $body = New-Activity 'Sequence'
    Set-PlainAttribute $body 'DisplayName' $displayName
    Add-Log $body $displayName $logLevel $messageExpression
    Add-Assign $body '[g_HasProcessingError]' 'x:Boolean' '[True]' 'x:Boolean'
    Add-Assign $body '[g_ErrorMessage]' 'x:String' $messageExpression 'x:String'
    $action.AppendChild($body) | Out-Null
    $catch.AppendChild($action) | Out-Null
    return $catch
}

function Add-Catches([System.Xml.XmlElement]$tryCatch, [array]$catchDefinitions) {
    $catchesProperty = New-Activity 'TryCatch.Catches'
    foreach ($definition in $catchDefinitions) {
        $catch = New-Catch $definition.Type $definition.Argument $definition.DisplayName $definition.Message $definition.Level
        $catchesProperty.AppendChild($catch) | Out-Null
    }
    $tryCatch.AppendChild($catchesProperty) | Out-Null
}

function Wrap-Activities([System.Xml.XmlElement]$parent, [System.Xml.XmlElement[]]$nodes, [string]$displayName, [string]$idRef, [array]$catchDefinitions) {
    if ($null -eq $nodes -or $nodes.Count -eq 0) {
        throw "No activities were found for wrapper '$displayName'."
    }

    $wrapper = New-Activity 'TryCatch'
    Set-PlainAttribute $wrapper 'DisplayName' $displayName
    Set-NamespaceAttribute $wrapper 'WorkflowViewState.IdRef' $sap2010Ns $idRef

    $tryProperty = New-Activity 'TryCatch.Try'
    $trySequence = New-Activity 'Sequence'
    Set-PlainAttribute $trySequence 'DisplayName' ($displayName + ' - Try')
    $tryProperty.AppendChild($trySequence) | Out-Null
    $wrapper.AppendChild($tryProperty) | Out-Null

    $parent.InsertBefore($wrapper, $nodes[0]) | Out-Null
    foreach ($node in $nodes) {
        $trySequence.AppendChild($node) | Out-Null
    }

    Add-Catches $wrapper $catchDefinitions
    return $wrapper
}

function Add-MissingFieldGuard([System.Xml.XmlElement]$parent, [System.Xml.XmlElement]$afterNode) {
    $if = New-Activity 'If'
    Set-PlainAttribute $if 'DisplayName' 'Handle Missing Regex Data'
    Set-PlainAttribute $if 'Condition' '[String.IsNullOrWhiteSpace(g_InvoiceNumber) OrElse String.IsNullOrWhiteSpace(g_InvoiceDate) OrElse String.IsNullOrWhiteSpace(g_PONumber) OrElse String.IsNullOrWhiteSpace(g_PaymentTerms) OrElse String.IsNullOrWhiteSpace(g_CustomerName) OrElse String.IsNullOrWhiteSpace(g_CustomerAddress)]'

    $thenProperty = New-Activity 'If.Then'
    $thenSequence = New-Activity 'Sequence'
    Set-PlainAttribute $thenSequence 'DisplayName' 'Regex Extraction Missing Data'
    Add-Log $thenSequence 'Regex Extraction - Missing Data' 'Warn' '["Regex extraction returned missing invoice data."]'
    Add-Assign $thenSequence '[g_HasProcessingError]' 'x:Boolean' '[True]' 'x:Boolean'
    Add-Assign $thenSequence '[g_ErrorMessage]' 'x:String' '[g_ErrorMessage + "Regex extraction returned missing invoice data. "]' 'x:String'
    $thenProperty.AppendChild($thenSequence) | Out-Null
    $if.AppendChild($thenProperty) | Out-Null

    $parent.InsertAfter($if, $afterNode) | Out-Null
}

function Add-MissingItemsGuard([System.Xml.XmlElement]$parent, [System.Xml.XmlElement]$afterNode) {
    $if = New-Activity 'If'
    Set-PlainAttribute $if 'DisplayName' 'Handle Missing Item Regex Data'
    Set-PlainAttribute $if 'Condition' '[g_ItemMatches Is Nothing OrElse g_ItemMatches.Count = 0]'

    $thenProperty = New-Activity 'If.Then'
    $thenSequence = New-Activity 'Sequence'
    Set-PlainAttribute $thenSequence 'DisplayName' 'Item Regex Extraction Missing Data'
    Add-Log $thenSequence 'Item Regex Extraction - Missing Data' 'Warn' '["No line-item matches were found in the PDF."]'
    Add-Assign $thenSequence '[g_HasProcessingError]' 'x:Boolean' '[True]' 'x:Boolean'
    Add-Assign $thenSequence '[g_ErrorMessage]' 'x:String' '[g_ErrorMessage + "No line-item matches were found in the PDF. "]' 'x:String'
    $thenProperty.AppendChild($thenSequence) | Out-Null
    $if.AppendChild($thenProperty) | Out-Null

    $parent.InsertAfter($if, $afterNode) | Out-Null
}

function Add-ProcessingErrorGuard([System.Xml.XmlElement]$parent, [System.Xml.XmlElement]$beforeNode) {
    $if = New-Activity 'If'
    Set-PlainAttribute $if 'DisplayName' 'Apply Processing Errors'
    Set-PlainAttribute $if 'Condition' '[g_HasProcessingError]'

    $thenProperty = New-Activity 'If.Then'
    $thenSequence = New-Activity 'Sequence'
    Set-PlainAttribute $thenSequence 'DisplayName' 'Mark Workflow Invalid'
    Add-Assign $thenSequence '[g_IsValid]' 'x:Boolean' '[False]' 'x:Boolean'
    Add-Assign $thenSequence '[g_ValidationMessage]' 'x:String' '[g_ErrorMessage + g_ValidationMessage]' 'x:String'
    $thenProperty.AppendChild($thenSequence) | Out-Null
    $if.AppendChild($thenProperty) | Out-Null

    $parent.InsertBefore($if, $beforeNode) | Out-Null
}

$inner = $doc.SelectSingleNode("//*[local-name()='Sequence' and @DisplayName='ExtractAndValidate']")
if ($null -eq $inner) {
    throw 'The ExtractAndValidate sequence was not found.'
}

if ($null -ne $inner.SelectSingleNode("./*[local-name()='TryCatch']")) {
    throw 'The workflow already contains a top-level Try Catch wrapper.'
}

$variables = $inner.SelectSingleNode("./*[local-name()='Sequence.Variables']")
if ($null -eq $variables) {
    throw 'The workflow variable collection was not found.'
}

if ($null -eq $variables.SelectSingleNode("./*[local-name()='Variable' and @Name='g_HasProcessingError']")) {
    $hasErrorVariable = New-Activity 'Variable'
    Set-NamespaceAttribute $hasErrorVariable 'TypeArguments' $xNs 'x:Boolean'
    Set-PlainAttribute $hasErrorVariable 'Default' 'False'
    Set-PlainAttribute $hasErrorVariable 'Name' 'g_HasProcessingError'
    $variables.AppendChild($hasErrorVariable) | Out-Null
}

if ($null -eq $variables.SelectSingleNode("./*[local-name()='Variable' and @Name='g_ErrorMessage']")) {
    $errorMessageVariable = New-Activity 'Variable'
    Set-NamespaceAttribute $errorMessageVariable 'TypeArguments' $xNs 'x:String'
    Set-PlainAttribute $errorMessageVariable 'Default' ''
    Set-PlainAttribute $errorMessageVariable 'Name' 'g_ErrorMessage'
    $variables.AppendChild($errorMessageVariable) | Out-Null
}

$bodyNodes = @($inner.ChildNodes | Where-Object {
    ($_ -is [System.Xml.XmlElement]) -and
    ($_.NamespaceURI -eq $activityNs) -and
    ($_.LocalName -ne 'Sequence.Variables')
})
if ($bodyNodes.Count -eq 0) {
    throw 'No workflow activities were found to wrap.'
}

$topTryCatch = New-Activity 'TryCatch'
Set-PlainAttribute $topTryCatch 'DisplayName' 'Entire Workflow - Try Catch'
Set-NamespaceAttribute $topTryCatch 'WorkflowViewState.IdRef' $sap2010Ns 'TryCatch_EntireWorkflow'
$topTryProperty = New-Activity 'TryCatch.Try'
$topSequence = New-Activity 'Sequence'
Set-PlainAttribute $topSequence 'DisplayName' 'Workflow Processing'
$topTryProperty.AppendChild($topSequence) | Out-Null
$topTryCatch.AppendChild($topTryProperty) | Out-Null
$inner.InsertBefore($topTryCatch, $bodyNodes[0]) | Out-Null
foreach ($node in $bodyNodes) {
    $topSequence.AppendChild($node) | Out-Null
}

$readNodes = @($topSequence.ChildNodes | Where-Object { $_ -is [System.Xml.XmlElement] -and $_.LocalName -eq 'ReadPDFText' })
Wrap-Activities $topSequence ([System.Xml.XmlElement[]]$readNodes) 'Read PDF - Try Catch' 'TryCatch_PdfRead' @(
    [pscustomobject]@{ Type = 'io:FileNotFoundException'; Argument = 'pdfNotFound'; DisplayName = 'PDF File Not Found'; Level = 'Error'; Message = '["PDF file not found: " + g_PdfPath]' },
    [pscustomobject]@{ Type = 'sys:Exception'; Argument = 'pdfException'; DisplayName = 'PDF Read Error'; Level = 'Error'; Message = '["PDF could not be read because the file is missing, corrupt, or inaccessible: " + pdfException.Message]' }
) | Out-Null

$headerNodes = @()
foreach ($id in @('Assign_1','Assign_2','Assign_3','Assign_4','Assign_5','Assign_6')) {
    $node = @($topSequence.ChildNodes | Where-Object {
        $_ -is [System.Xml.XmlElement] -and $_.GetAttribute('WorkflowViewState.IdRef', $sap2010Ns) -eq $id
    }) | Select-Object -First 1
    if ($null -ne $node) { $headerNodes += $node }
}
$headerWrapper = Wrap-Activities $topSequence ([System.Xml.XmlElement[]]$headerNodes) 'Regex Header Extraction - Try Catch' 'TryCatch_RegexExtraction' @(
    [pscustomobject]@{ Type = 'sys:Exception'; Argument = 'regexException'; DisplayName = 'Regex Extraction Error'; Level = 'Error'; Message = '["Regex extraction failed: " + regexException.Message]' }
)
Add-MissingFieldGuard $topSequence $headerWrapper

$conversionNodes = @()
foreach ($id in @('Assign_7','Assign_8','Assign_9')) {
    $node = @($topSequence.ChildNodes | Where-Object {
        $_ -is [System.Xml.XmlElement] -and $_.GetAttribute('WorkflowViewState.IdRef', $sap2010Ns) -eq $id
    }) | Select-Object -First 1
    if ($null -ne $node) { $conversionNodes += $node }
}
Wrap-Activities $topSequence ([System.Xml.XmlElement[]]$conversionNodes) 'Double.Parse Conversion - Try Catch' 'TryCatch_DoubleParse' @(
    [pscustomobject]@{ Type = 'sys:Exception'; Argument = 'conversionException'; DisplayName = 'Data Conversion Error'; Level = 'Error'; Message = '["Data conversion error in Double.Parse: " + conversionException.Message]' }
) | Out-Null

$itemAssignment = @($topSequence.ChildNodes | Where-Object {
    $_ -is [System.Xml.XmlElement] -and $_.GetAttribute('WorkflowViewState.IdRef', $sap2010Ns) -eq 'Assign_10'
}) | Select-Object -First 1
if ($null -eq $itemAssignment) {
    throw 'The item regex assignment was not found.'
}
$itemRegexWrapper = Wrap-Activities $topSequence ([System.Xml.XmlElement[]]@($itemAssignment)) 'Item Regex Extraction - Try Catch' 'TryCatch_ItemRegex' @(
    [pscustomobject]@{ Type = 'sys:Exception'; Argument = 'itemRegexException'; DisplayName = 'Item Regex Extraction Error'; Level = 'Error'; Message = '["Line-item regex extraction failed: " + itemRegexException.Message]' }
)
Add-MissingItemsGuard $topSequence $itemRegexWrapper

$itemLoopNodes = @($topSequence.ChildNodes | Where-Object {
    $_ -is [System.Xml.XmlElement] -and $_.LocalName -eq 'ForEach' -and $_.GetAttribute('DisplayName') -eq 'For Each itemMatch'
})
Wrap-Activities $topSequence ([System.Xml.XmlElement[]]$itemLoopNodes) 'Item Extraction For Each - Try Catch' 'TryCatch_ItemExtraction' @(
    [pscustomobject]@{ Type = 'sys:Exception'; Argument = 'itemException'; DisplayName = 'Item Extraction Loop Error'; Level = 'Error'; Message = '["For Each item extraction failed: " + itemException.Message]' }
) | Out-Null

$validationIf = @($topSequence.ChildNodes | Where-Object {
    $_ -is [System.Xml.XmlElement] -and $_.LocalName -eq 'If' -and $_.GetAttribute('Condition') -eq '[String.IsNullOrWhiteSpace(g_InvoiceNumber)]'
}) | Select-Object -First 1
if ($null -eq $validationIf) {
    throw 'The existing invoice validation block was not found.'
}
Add-ProcessingErrorGuard $topSequence $validationIf

Add-Catches $topTryCatch @(
    [pscustomobject]@{ Type = 'sys:Exception'; Argument = 'workflowException'; DisplayName = 'Unhandled Workflow Error'; Level = 'Error'; Message = '["Unhandled workflow error: " + workflowException.Message]' }
)

$finallyProperty = New-Activity 'TryCatch.Finally'
$finallySequence = New-Activity 'Sequence'
Set-PlainAttribute $finallySequence 'DisplayName' 'Finally - Cleanup'
Add-Log $finallySequence 'Workflow Cleanup' 'Info' '["Finally block executed. Cleaning up workflow data."]'
Add-Assign $finallySequence '[g_PdfText]' 'x:String' '[String.Empty]' 'x:String'
Add-Assign $finallySequence '[g_ItemMatches]' 'str:MatchCollection' '[Nothing]' 'str:MatchCollection'
Add-Assign $finallySequence '[g_Items]' 'sd:DataTable' '[Nothing]' 'sd:DataTable'
Add-Assign $finallySequence '[dtReport]' 'sd:DataTable' '[Nothing]' 'sd:DataTable'
$finallyProperty.AppendChild($finallySequence) | Out-Null
$topTryCatch.AppendChild($finallyProperty) | Out-Null

$settings = New-Object System.Xml.XmlWriterSettings
$settings.Indent = $true
$settings.OmitXmlDeclaration = $true
$settings.Encoding = New-Object System.Text.UTF8Encoding($false)
$writer = [System.Xml.XmlWriter]::Create($workflowPath, $settings)
$doc.Save($writer)
$writer.Close()
Write-Output "Updated $workflowPath"
