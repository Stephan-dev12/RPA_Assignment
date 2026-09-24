$ErrorActionPreference = 'Stop'
$workflow = 'C:\Users\naina\OneDrive\Desktop\Software Engineering Year 3\RPA_Assignment\Assignment 1\ExtractandValidate.xaml'
$out = 'C:\Users\naina\OneDrive\Desktop\Software Engineering Year 3\RPA_Assignment\Assignment 1\DiagnoseWorkflow.log'
try {
  $doc = New-Object System.Xml.XmlDocument
  $doc.PreserveWhitespace = $true
  $doc.Load($workflow)
  $root = $doc.DocumentElement
  $inner = $doc.SelectSingleNode("//*[local-name()='Sequence' and @DisplayName='ExtractAndValidate']")
  $lines = @()
  $lines += 'Loaded=' + ($null -ne $root)
  $lines += 'Root=' + $root.LocalName
  $lines += 'Inner=' + ($null -ne $inner)
  if ($null -ne $inner) {
    $lines += 'InnerNS=' + $inner.NamespaceURI
    $lines += 'VariablesByLocal=' + $inner.SelectNodes("./*[local-name()='Sequence.Variables']").Count
    $lines += 'VariablesByName=' + $inner.SelectNodes("./*[local-name()='Variables']").Count
    $lines += 'ChildCount=' + $inner.ChildNodes.Count
    foreach ($child in $inner.ChildNodes) {
      if ($child -is [System.Xml.XmlElement]) { $lines += ('CHILD ' + $child.LocalName + ' NS=' + $child.NamespaceURI) }
    }
  }
  [System.IO.File]::WriteAllLines($out, $lines)
} catch {
  [System.IO.File]::WriteAllText($out, 'ERROR ' + $_.Exception.ToString())
}
