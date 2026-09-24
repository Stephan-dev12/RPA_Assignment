$ErrorActionPreference = 'Stop'
$workflow = 'C:\Users\naina\OneDrive\Desktop\Software Engineering Year 3\RPA_Assignment\Assignment 1\ExtractandValidate.xaml'
$out = 'C:\Users\naina\OneDrive\Desktop\Software Engineering Year 3\RPA_Assignment\Assignment 1\DiagnoseAttrs.log'
$doc = New-Object System.Xml.XmlDocument
$doc.Load($workflow)
$node = $doc.SelectSingleNode("//*[local-name()='Sequence' and @DisplayName='ExtractAndValidate']/*[local-name()='ReadPDFText']")
$assign = $doc.SelectSingleNode("//*[local-name()='Sequence' and @DisplayName='ExtractAndValidate']/*[local-name()='Assign']")
$lines = @()
foreach ($item in @($node, $assign)) {
  if ($null -ne $item) {
    $lines += 'NODE=' + $item.LocalName
    foreach ($a in $item.Attributes) { $lines += ('ATTR Name=' + $a.Name + ' Local=' + $a.LocalName + ' Prefix=' + $a.Prefix + ' NS=' + $a.NamespaceURI + ' Value=' + $a.Value) }
  }
}
[System.IO.File]::WriteAllLines($out, $lines)
