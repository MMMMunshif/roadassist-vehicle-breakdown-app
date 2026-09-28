param(
  [string]$InputPath = "ROADASSIST_PROJECT_HISTORY.md",
  [string]$OutputPath = "RoadAssist_Project_History.docx"
)

$ErrorActionPreference = "Stop"
$source = (Resolve-Path -LiteralPath $InputPath).Path
$destination = [System.IO.Path]::GetFullPath((Join-Path (Get-Location) $OutputPath))

function Escape-Xml([string]$Text) {
  return [System.Security.SecurityElement]::Escape($Text)
}

function Paragraph-Xml {
  param(
    [string]$Text,
    [string]$Style = "Normal",
    [bool]$Bullet = $false
  )
  $escaped = Escape-Xml $Text
  $styleXml = if ($Style) { "<w:pStyle w:val=`"$Style`"/>" } else { "" }
  $numberingXml = if ($Bullet) {
    '<w:numPr><w:ilvl w:val="0"/><w:numId w:val="1"/></w:numPr>'
  } else { "" }
  return "<w:p><w:pPr>$styleXml$numberingXml</w:pPr><w:r><w:t xml:space=`"preserve`">$escaped</w:t></w:r></w:p>"
}

$body = [System.Text.StringBuilder]::new()
$inCode = $false
foreach ($line in [System.IO.File]::ReadAllLines($source, [System.Text.Encoding]::UTF8)) {
  if ($line.Trim().StartsWith('```')) {
    $inCode = -not $inCode
    continue
  }
  if ($inCode) {
    [void]$body.Append((Paragraph-Xml -Text $line -Style "Code"))
  } elseif ($line.StartsWith('# ')) {
    [void]$body.Append((Paragraph-Xml -Text $line.Substring(2) -Style "Title"))
  } elseif ($line.StartsWith('## ')) {
    [void]$body.Append((Paragraph-Xml -Text $line.Substring(3) -Style "Heading1"))
  } elseif ($line.StartsWith('### ')) {
    [void]$body.Append((Paragraph-Xml -Text $line.Substring(4) -Style "Heading2"))
  } elseif ($line -match '^\s*-\s+(.*)$') {
    [void]$body.Append((Paragraph-Xml -Text $Matches[1] -Style "Normal" -Bullet $true))
  } elseif ($line -match '^\s*\d+\.\s+(.*)$') {
    [void]$body.Append((Paragraph-Xml -Text $line.Trim() -Style "Normal"))
  } elseif ($line.StartsWith('> ')) {
    [void]$body.Append((Paragraph-Xml -Text $line.Substring(2) -Style "Quote"))
  } elseif ([string]::IsNullOrWhiteSpace($line)) {
    [void]$body.Append('<w:p/>')
  } else {
    $plain = $line -replace '\*\*', '' -replace '`', ''
    [void]$body.Append((Paragraph-Xml -Text $plain -Style "Normal"))
  }
}

$documentXml = @"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:body>
    $body
    <w:sectPr>
      <w:pgSz w:w="11906" w:h="16838"/>
      <w:pgMar w:top="1080" w:right="1080" w:bottom="1080" w:left="1080" w:header="720" w:footer="720" w:gutter="0"/>
    </w:sectPr>
  </w:body>
</w:document>
"@

$stylesXml = @'
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:docDefaults><w:rPrDefault><w:rPr><w:rFonts w:ascii="Aptos" w:hAnsi="Aptos" w:cs="Nirmala UI"/><w:sz w:val="22"/><w:lang w:val="en-US" w:bidi="ta-IN"/></w:rPr></w:rPrDefault><w:pPrDefault><w:pPr><w:spacing w:after="120" w:line="276" w:lineRule="auto"/></w:pPr></w:pPrDefault></w:docDefaults>
  <w:style w:type="paragraph" w:default="1" w:styleId="Normal"><w:name w:val="Normal"/></w:style>
  <w:style w:type="paragraph" w:styleId="Title"><w:name w:val="Title"/><w:basedOn w:val="Normal"/><w:pPr><w:spacing w:before="0" w:after="320"/><w:jc w:val="center"/></w:pPr><w:rPr><w:b/><w:color w:val="397DBD"/><w:sz w:val="38"/></w:rPr></w:style>
  <w:style w:type="paragraph" w:styleId="Heading1"><w:name w:val="heading 1"/><w:basedOn w:val="Normal"/><w:pPr><w:keepNext/><w:spacing w:before="300" w:after="140"/></w:pPr><w:rPr><w:b/><w:color w:val="245C91"/><w:sz w:val="28"/></w:rPr></w:style>
  <w:style w:type="paragraph" w:styleId="Heading2"><w:name w:val="heading 2"/><w:basedOn w:val="Normal"/><w:pPr><w:keepNext/><w:spacing w:before="220" w:after="100"/></w:pPr><w:rPr><w:b/><w:color w:val="397DBD"/><w:sz w:val="24"/></w:rPr></w:style>
  <w:style w:type="paragraph" w:styleId="Quote"><w:name w:val="Quote"/><w:basedOn w:val="Normal"/><w:pPr><w:ind w:left="500"/><w:spacing w:before="120" w:after="180"/></w:pPr><w:rPr><w:i/><w:color w:val="52667A"/></w:rPr></w:style>
  <w:style w:type="paragraph" w:styleId="Code"><w:name w:val="Code"/><w:basedOn w:val="Normal"/><w:pPr><w:ind w:left="300"/><w:shd w:fill="F1F6FA"/><w:spacing w:after="0"/></w:pPr><w:rPr><w:rFonts w:ascii="Consolas" w:hAnsi="Consolas"/><w:sz w:val="19"/></w:rPr></w:style>
</w:styles>
'@

$numberingXml = @'
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:numbering xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:abstractNum w:abstractNumId="0"><w:multiLevelType w:val="singleLevel"/><w:lvl w:ilvl="0"><w:start w:val="1"/><w:numFmt w:val="bullet"/><w:lvlText w:val="•"/><w:lvlJc w:val="left"/><w:pPr><w:tabs><w:tab w:val="num" w:pos="720"/></w:tabs><w:ind w:left="720" w:hanging="360"/></w:pPr></w:lvl></w:abstractNum>
  <w:num w:numId="1"><w:abstractNumId w:val="0"/></w:num>
</w:numbering>
'@

$contentTypes = @'
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
  <Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>
  <Override PartName="/word/numbering.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.numbering+xml"/>
  <Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>
  <Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/>
</Types>
'@

$rootRels = @'
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>
  <Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" Target="docProps/app.xml"/>
</Relationships>
'@

$documentRels = @'
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/numbering" Target="numbering.xml"/>
</Relationships>
'@

$timestamp = [DateTime]::UtcNow.ToString("s") + "Z"
$coreXml = @"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:dcterms="http://purl.org/dc/terms/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"><dc:title>RoadAssist LK Project History</dc:title><dc:creator>RoadAssist Development Team</dc:creator><dc:subject>Project history, architecture and current status</dc:subject><dcterms:created xsi:type="dcterms:W3CDTF">$timestamp</dcterms:created><dcterms:modified xsi:type="dcterms:W3CDTF">$timestamp</dcterms:modified></cp:coreProperties>
"@
$appXml = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties" xmlns:vt="http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes"><Application>Microsoft Office Word</Application><Company>RoadAssist LK</Company></Properties>'

Add-Type -AssemblyName System.IO.Compression
$fileStream = [System.IO.File]::Open($destination, [System.IO.FileMode]::Create)
try {
  $archive = [System.IO.Compression.ZipArchive]::new($fileStream, [System.IO.Compression.ZipArchiveMode]::Create, $false)
  try {
    $parts = [ordered]@{
      '[Content_Types].xml' = $contentTypes
      '_rels/.rels' = $rootRels
      'word/document.xml' = $documentXml
      'word/styles.xml' = $stylesXml
      'word/numbering.xml' = $numberingXml
      'word/_rels/document.xml.rels' = $documentRels
      'docProps/core.xml' = $coreXml
      'docProps/app.xml' = $appXml
    }
    foreach ($part in $parts.GetEnumerator()) {
      $entry = $archive.CreateEntry($part.Key, [System.IO.Compression.CompressionLevel]::Optimal)
      $stream = $entry.Open()
      $writer = [System.IO.StreamWriter]::new($stream, [System.Text.UTF8Encoding]::new($false))
      try { $writer.Write($part.Value) } finally { $writer.Dispose() }
    }
  } finally {
    $archive.Dispose()
  }
} finally {
  $fileStream.Dispose()
}

Write-Output $destination
