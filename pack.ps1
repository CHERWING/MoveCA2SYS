# MoveCA2SYS 打包脚本
param(
  [string]$SourceDir = $PSScriptRoot,
  [string]$OutputDir = (Split-Path -Parent $PSScriptRoot)
)

$ver = "v1.3"
$dest = Join-Path $OutputDir "MoveCA2SYS_$ver.zip"

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$exclude = @('pack.ps1', '.gitignore', '.gitkeep', 'README.md', 'update.json', 'CHANGELOG.md')
$zip = [System.IO.Compression.ZipFile]::Open($dest, [System.IO.Compression.ZipArchiveMode]::Create)

try {
  Get-ChildItem -LiteralPath $SourceDir -Recurse | ForEach-Object {
    $relative = $_.FullName.Substring($SourceDir.Length + 1).Replace('\', '/')
    # 排除 .git 目录
    if ($relative -eq '.git' -or $relative -like '.git/*') { return }
    foreach ($ex in $exclude) {
      if ($relative -eq $ex) { return }
    }
    if ($_.PSIsContainer) {
      $null = $zip.CreateEntry("$relative/")
    } else {
      $entry = $zip.CreateEntry($relative, [System.IO.Compression.CompressionLevel]::Optimal)
      $entryStream = $entry.Open()
      try {
        $fileStream = [System.IO.File]::OpenRead($_.FullName)
        try { $fileStream.CopyTo($entryStream) } finally { $fileStream.Dispose() }
      } finally { $entryStream.Dispose() }
    }
  }
} finally {
  $zip.Dispose()
}

$size = (Get-Item $dest).Length
Write-Output "打包完成: $dest ($([math]::Round($size / 1KB)) KB)"
