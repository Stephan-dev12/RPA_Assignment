$ErrorActionPreference = 'Stop'

$work = 'C:\Users\naina\OneDrive\Desktop\Software Engineering Year 3\RPA_Assignment\Assignment 1'
$workflowPath = Join-Path $work 'ExtractandValidate.xaml'
$backupPath = Join-Path $work 'ExtractandValidate.xaml.before-error-handling.bak'
$logPath = Join-Path $work 'ApplyErrorHandling.log'

$activityNs = 'http://schemas.microsoft.com/netfx/2009/xaml/activities'
$xNs = 'http://schemas.microsoft.com/winfx/2006/xaml'
$sap2010Ns = 'http://schemas.microsoft.com/netfx/2010/xaml/activities/presentation'
$uiNs = 'http://schemas.uipath.com/workflow/activities'
$xmlnsNs = 'http://www.w3.org/2000/xmlns/'

function New-Activity([string]$localName) {
    return $doc.CreateElement($localName, $activityNs)
}

function New-UiActivity([string]$localName) {
    return $doc.CreateElement('ui', $localName, $uiNs)
}

function Set-AttributeValue([System.Xml.XmlElement]$node, [string]$name, [string]$value) {
    $node.SetAttribute($name, $value)
}

function Set-NamespaceAttributeValue([System.Xml.XmlElement]$node, [string]$localName, [string]$namespaceUri, [string]$value) {
    $node.SetAttribute($localName, $namespaceUri, $value)
}

function Get-DirectChildByLocalName([System.Xml.XmlElement]$parent, [string]$localName) {
    for ($i = 0; $i -lt $parent.ChildNodes.Count; $i++) {
        $child = $parent.ChildNodes.Item($i)
        if (($child -is [System.Xml.XmlElement]) -and $child.LocalName -eq $localName) {
            return $child
        }
    }
    return $null
}

function Get-DirectChildById([System.Xml.XmlElement]$parent, [string]$id) {
    for ($i = 0; $i -lt $parent.ChildNodes.Count; $i++) {
        $child = $parent.ChildNodes.Item($i)
        if (($child -is [System.Xml.XmlElement]) -and $child.GetAttribute('WorkflowViewState.IdRef', $sap2010Ns) -eq $id) {
            return $child
        }
    }
    return $null
}

function Add-LogMessage([System.Xml.XmlElement]$sequence, [string]$displayName, [string]$level, [string]$message) {
    $log = New-UiActivity 'LogMessage'
    Set-AttributeValue $log 'DisplayName' $displayName
    Set-AttributeValue $log 'Level' $level
    Set-AttributeValue $log 'Message' $message
    [void]$sequence.AppendChild($log)
}

function Add-Assign([System.Xml.XmlElement]$sequence, [string]$target, [string]$targetType, [string]$value, [string]$valueType) {
    $assign = New-Activity 'Assign'
    $to = New-Activity 'Assign.To'
    $outArgument = New-Activity 'OutArgument'
    Set-NamespaceAttributeValue $outArgument 'TypeArguments' $xNs $targetType
    $outArgument.InnerText = $target
    [void]$to.AppendChild($outArgument)
    [void]$assign.AppendChild($to)

    $valueProperty = New-Activity 'Assign.Value'
    $inArgument = New-Activity 'InArgument'
    Set-NamespaceAttributeValue $inArgument 'TypeArguments' $xNs $valueType
    $inArgument.InnerText = $value
    [void]$valueProperty.AppendChild($inArgument)
    [void]$assign.AppendChild($valueProperty)
    [void]$sequence.AppendChild($assign)
}

function New-Catch([string]$typeArgument, [string]$argumentName, [string]$displayName, [string]$message) {
    $catch = New-Activity 'Catch'
    Set-NamespaceAttributeValue $catch 'TypeArguments' $xNs $typeArgument

    $action = New-Activity 'ActivityAction'
    Set-NamespaceAttributeValue $action 'TypeArguments' $xNs $typeArgument

    $argumentProperty = New-Activity 'ActivityAction.Argument'
    $delegateArgument = New-Activity 'DelegateInArgument'
    Set-NamespaceAttributeValue $delegateArgument 'TypeArguments' $xNs $typeArgument
    Set-AttributeValue $delegateArgument 'Name' $argumentName
    [void]$argumentProperty.AppendChild($delegateArgument)
    [void]$action.AppendChild($argumentProperty)

    $body = New-Activity 'Sequence'
    Set-AttributeValue $body 'DisplayName' $displayName
    Add-LogMessage $body $displayName 'Error' $message
    Add-Assign $body '[g_HasProcessingError]' 'x:Boolean' '[True]' 'x:Boolean'
    Add-Assign $body '[g_ErrorMessage]' 'x:String' $message 'x:String'
    [void]$action.AppendChild($body)
    [void]$catch.AppendChild($action)
    return $catch
}

function Add-Catches([System.Xml.XmlElement]$tryCatch, [object[]]$definitions) {
    $catchesProperty = New-Activity 'TryCatch.Catches'
    foreach ($definition in $definitions) {
        [void]$catchesProperty.AppendChild((New-Catch $definition.Type $definition.Argument $definition.DisplayName $definition.Message))
    }
    [void]$tryCatch.AppendChild($catchesProperty)
}

function Wrap-Activities([System.Xml.XmlElement]$parent, [object[]]$nodes, [string]$displayName, [string]$idRef, [object[]]$definitions) {
    $nodeArray = @($nodes | Where-Object { $null -ne $_ })
    if ($nodeArray.Count -eq 0) {
        throw "No activities were found for wrapper '$displayName'."
    }

    $wrapper = New-Activity 'TryCatch'
    Set-AttributeValue $wrapper 'DisplayName' $displayName
    Set-NamespaceAttributeValue $wrapper 'WorkflowViewState.IdRef' $sap2010Ns $idRef

    $tryProperty = New-Activity 'TryCatch.Try'
    $trySequence = New-Activity 'Sequence'
    Set-AttributeValue $trySequence 'DisplayName' ($displayName + ' - Try')
    [void]$tryProperty.AppendChild($trySequence)
    [void]$wrapper.AppendChild($tryProperty)

    [void]$parent.InsertBefore($wrapper, $nodeArray[0])
    foreach ($node in $nodeArray) {
        [void]$trySequence.AppendChild($node)
    }

    Add-Catches $wrapper $definitions
    return $wrapper
}

function Add-MissingDataGuard([System.Xml.XmlElement]$parent, [System.Xml.XmlElement]$afterNode, [string]$condition, [string]$displayName, [string]$message) {
    $if = New-Activity 'If'
    Set-AttributeValue $if 'DisplayName' $displayName
    Set-AttributeValue $if 'Condition' $condition

    $thenProperty = New-Activity 'If.Then'
    $thenSequence = New-Activity 'Sequence'
    Set-AttributeValue $thenSequence 'DisplayName' ($displayName + ' - Handler')
    Add-LogMessage $thenSequence $displayName 'Warn' ('["' + $message + '"]')
    Add-Assign $thenSequence '[g_HasProcessingError]' 'x:Boolean' '[True]' 'x:Boolean'
    Add-Assign $thenSequence '[g_ErrorMessage]' 'x:String' ('[g_ErrorMessage + "' + $message + ' "]') 'x:String'
    [void]$thenProperty.AppendChild($thenSequence)
    [void]$if.AppendChild($thenProperty)
    [void]$parent.InsertAfter($if, $afterNode)
}

function Add-ProcessingErrorGuard([System.Xml.XmlElement]$parent, [System.Xml.XmlElement]$beforeNode) {
    $if = New-Activity 'If'
    Set-AttributeValue $if 'DisplayName' 'Apply Processing Errors'
    Set-AttributeValue $if 'Condition' '[g_HasProcessingError]'

    $thenProperty = New-Activity 'If.Then'
    $thenSequence = New-Activity 'Sequence'
    Set-AttributeValue $thenSequence 'DisplayName' 'Mark Workflow Invalid'
    Add-Assign $thenSequence '[g_IsValid]' 'x:Boolean' '[False]' 'x:Boolean'
    Add-Assign $thenSequence '[g_ValidationMessage]' 'x:String' '[g_ErrorMessage + g_ValidationMessage]' 'x:String'
    [void]$thenProperty.AppendChild($thenSequence)
    [void]$if.AppendChild($thenProperty)
    [void]$parent.InsertBefore($if, $beforeNode)
}

try {
    Copy-Item -LiteralPath $backupPath -Destination $workflowPath -Force

    $doc = New-Object System.Xml.XmlDocument
    $doc.PreserveWhitespace = $true
    $doc.Load($workflowPath)
    $root = $doc.DocumentElement

    if (-not $root.GetNamespaceOfPrefix('sys')) {
        $attribute = $doc.CreateAttribute('xmlns', 'sys', $xmlnsNs)
        $attribute.Value = 'clr-namespace:System;assembly=System.Private.CoreLib'
        [void]$root.Attributes.Append($attribute)
    }
    if (-not $root.GetNamespaceOfPrefix('io')) {
        $attribute = $doc.CreateAttribute('xmlns', 'io', $xmlnsNs)
        $attribute.Value = 'clr-namespace:System.IO;assembly=System.Private.CoreLib'
        [void]$root.Attributes.Append($attribute)
    }

    $inner = $doc.SelectSingleNode("//*[local-name()='Sequence' and @DisplayName='ExtractAndValidate']")
    if ($null -eq $inner) { throw 'ExtractAndValidate sequence not found.' }
    if ($null -ne (Get-DirectChildByLocalName $inner 'TryCatch')) { throw 'Top-level Try Catch already exists.' }

    $variables = $inner.SelectSingleNode("./*[local-name()='Sequence.Variables']")
    if ($null -eq $variables) { throw 'Sequence.Variables not found.' }

    if ($null -eq $variables.SelectSingleNode("./*[local-name()='Variable' and @Name='g_HasProcessingError']")) {
        $variable = New-Activity 'Variable'
        Set-NamespaceAttributeValue $variable 'TypeArguments' $xNs 'x:Boolean'
        Set-AttributeValue $variable 'Default' 'False'
        Set-AttributeValue $variable 'Name' 'g_HasProcessingError'
        [void]$variables.AppendChild($variable)
    }
    if ($null -eq $variables.SelectSingleNode("./*[local-name()='Variable' and @Name='g_ErrorMessage']")) {
        $variable = New-Activity 'Variable'
        Set-NamespaceAttributeValue $variable 'TypeArguments' $xNs 'x:String'
        Set-AttributeValue $variable 'Default' ''
        Set-AttributeValue $variable 'Name' 'g_ErrorMessage'
        [void]$variables.AppendChild($variable)
    }

    $bodyNodes = @()
    for ($i = 0; $i -lt $inner.ChildNodes.Count; $i++) {
        $child = $inner.ChildNodes.Item($i)
        if (($child -is [System.Xml.XmlElement]) -and ($child.LocalName -ne 'Sequence.Variables') -and ($child.NamespaceURI -eq $activityNs)) {
            $bodyNodes += $child
        }
    }
    if ($bodyNodes.Count -eq 0) { throw 'No workflow activities found to wrap.' }

    $topTryCatch = New-Activity 'TryCatch'
    Set-AttributeValue $topTryCatch 'DisplayName' 'Entire Workflow - Try Catch'
    Set-NamespaceAttributeValue $topTryCatch 'WorkflowViewState.IdRef' $sap2010Ns 'TryCatch_EntireWorkflow'
    $topTryProperty = New-Activity 'TryCatch.Try'
    $topSequence = New-Activity 'Sequence'
    Set-AttributeValue $topSequence 'DisplayName' 'Workflow Processing'
    [void]$topTryProperty.AppendChild($topSequence)
    [void]$topTryCatch.AppendChild($topTryProperty)
    [void]$inner.InsertBefore($topTryCatch, $bodyNodes[0])
    foreach ($node in $bodyNodes) { [void]$topSequence.AppendChild($node) }

    $readNode = Get-DirectChildByLocalName $topSequence 'ReadPDFText'
    $pdfWrapper = Wrap-Activities $topSequence @($readNode) 'Read PDF - Try Catch' 'TryCatch_PdfRead' @(
        [pscustomobject]@{ Type = 'io:FileNotFoundException'; Argument = 'pdfNotFound'; DisplayName = 'PDF File Not Found'; Message = '["PDF file not found: " + g_PdfPath]' },
        [pscustomobject]@{ Type = 'sys:Exception'; Argument = 'pdfException'; DisplayName = 'PDF Read Error'; Message = '["PDF could not be read because the file is missing, corrupt, or inaccessible: " + pdfException.Message]' }
    )

    $headerNodes = @()
    foreach ($id in @('Assign_1','Assign_2','Assign_3','Assign_4','Assign_5','Assign_6')) { $headerNodes += Get-DirectChildById $topSequence $id }
    $headerWrapper = Wrap-Activities $topSequence $headerNodes 'Regex Header Extraction - Try Catch' 'TryCatch_RegexExtraction' @(
        [pscustomobject]@{ Type = 'sys:Exception'; Argument = 'regexException'; DisplayName = 'Regex Extraction Error'; Message = '["Regex extraction failed: " + regexException.Message]' }
    )
    Add-MissingDataGuard $topSequence $headerWrapper '[String.IsNullOrWhiteSpace(g_InvoiceNumber) OrElse String.IsNullOrWhiteSpace(g_InvoiceDate) OrElse String.IsNullOrWhiteSpace(g_PONumber) OrElse String.IsNullOrWhiteSpace(g_PaymentTerms) OrElse String.IsNullOrWhiteSpace(g_CustomerName) OrElse String.IsNullOrWhiteSpace(g_CustomerAddress)]' 'Handle Missing Regex Data' 'Regex extraction returned missing invoice data.'

    $conversionNodes = @()
    foreach ($id in @('Assign_7','Assign_8','Assign_9')) { $conversionNodes += Get-DirectChildById $topSequence $id }
    Wrap-Activities $topSequence $conversionNodes 'Double.Parse Conversion - Try Catch' 'TryCatch_DoubleParse' @(
        [pscustomobject]@{ Type = 'sys:FormatException'; Argument = 'formatException'; DisplayName = 'Invalid Numeric Format'; Message = '["Double.Parse received invalid numeric data: " + formatException.Message]' },
        [pscustomobject]@{ Type = 'sys:OverflowException'; Argument = 'overflowException'; DisplayName = 'Numeric Overflow'; Message = '["Double.Parse numeric overflow: " + overflowException.Message]' },
        [pscustomobject]@{ Type = 'sys:Exception'; Argument = 'conversionException'; DisplayName = 'Data Conversion Error'; Message = '["Data conversion error in Double.Parse: " + conversionException.Message]' }
    ) | Out-Null

    $itemAssignment = Get-DirectChildById $topSequence 'Assign_10'
    $itemRegexWrapper = Wrap-Activities $topSequence @($itemAssignment) 'Item Regex Extraction - Try Catch' 'TryCatch_ItemRegex' @(
        [pscustomobject]@{ Type = 'sys:Exception'; Argument = 'itemRegexException'; DisplayName = 'Item Regex Extraction Error'; Message = '["Line-item regex extraction failed: " + itemRegexException.Message]' }
    )
    Add-MissingDataGuard $topSequence $itemRegexWrapper '[g_ItemMatches Is Nothing OrElse g_ItemMatches.Count = 0]' 'Handle Missing Item Regex Data' 'No line-item matches were found in the PDF.'

    $itemLoop = Get-DirectChildByLocalName $topSequence 'ForEach'
    $itemLoopWrapper = Wrap-Activities $topSequence @($itemLoop) 'Item Extraction For Each - Try Catch' 'TryCatch_ItemExtraction' @(
        [pscustomobject]@{ Type = 'sys:Exception'; Argument = 'itemException'; DisplayName = 'Item Extraction Loop Error'; Message = '["For Each item extraction failed: " + itemException.Message]' }
    )

    $validIf = $null
    for ($i = 0; $i -lt $topSequence.ChildNodes.Count; $i++) {
        $child = $topSequence.ChildNodes.Item($i)
        if (($child -is [System.Xml.XmlElement]) -and $child.LocalName -eq 'If' -and $child.GetAttribute('Condition') -eq '[g_IsValid]') { $validIf = $child; break }
    }
    if ($null -eq $validIf) { throw 'The main validation If block was not found.' }
    Add-ProcessingErrorGuard $topSequence $validIf

    Add-Catches $topTryCatch @(
        [pscustomobject]@{ Type = 'sys:Exception'; Argument = 'workflowException'; DisplayName = 'Unhandled Workflow Error'; Message = '["Unhandled workflow error: " + workflowException.Message]' }
    )

    $finallyProperty = New-Activity 'TryCatch.Finally'
    $finallySequence = New-Activity 'Sequence'
    Set-AttributeValue $finallySequence 'DisplayName' 'Finally - Cleanup'
    Add-LogMessage $finallySequence 'Workflow Cleanup' 'Info' '["Finally block executed. Cleaning up workflow data."]'
    Add-Assign $finallySequence '[g_PdfText]' 'x:String' '[String.Empty]' 'x:String'
    Add-Assign $finallySequence '[g_ItemMatches]' 'str:MatchCollection' '[Nothing]' 'str:MatchCollection'
    Add-Assign $finallySequence '[g_Items]' 'sd:DataTable' '[Nothing]' 'sd:DataTable'
    Add-Assign $finallySequence '[dtReport]' 'sd:DataTable' '[Nothing]' 'sd:DataTable'
    [void]$finallyProperty.AppendChild($finallySequence)
    [void]$topTryCatch.AppendChild($finallyProperty)

    $settings = New-Object System.Xml.XmlWriterSettings
    $settings.Indent = $true
    $settings.OmitXmlDeclaration = $true
    $settings.Encoding = New-Object System.Text.UTF8Encoding($false)
    $writer = [System.Xml.XmlWriter]::Create($workflowPath, $settings)
    $doc.Save($writer)
    $writer.Close()
    [System.IO.File]::WriteAllText($logPath, 'SUCCESS')
} catch {
    [System.IO.File]::WriteAllText($logPath, 'ERROR: ' + $_.Exception.ToString())
    throw
}
