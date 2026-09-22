# vendor-pool-clone.ps1
# Hardlink-clones every file under Source into Dest, preserving directory structure.
# Hardlinks need no admin rights (unlike SymbolicLink), and unlike a junction,
# the Source content survives even if `git worktree remove --force` deletes Dest
# (verified 2026-08-24: junction lets that command cascade-delete the target).
#
# Usage: powershell -NoProfile -ExecutionPolicy Bypass -File vendor-pool-clone.ps1 -Source <dir> -Dest <dir>
# Dest must not already exist; caller is responsible for cleanup beforehand.

param(
    [Parameter(Mandatory=$true)][string]$Source,
    [Parameter(Mandatory=$true)][string]$Dest
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $Source)) { throw "Source not found: $Source" }
if (Test-Path $Dest) { throw "Dest already exists: $Dest (caller must clean up first)" }

New-Item -ItemType Directory -Path $Dest -Force | Out-Null

$sw = [System.Diagnostics.Stopwatch]::StartNew()
$files = Get-ChildItem $Source -Recurse -File
$n = 0
foreach ($f in $files) {
    $rel = $f.FullName.Substring($Source.Length).TrimStart('\')
    $destPath = Join-Path $Dest $rel
    $destDir = Split-Path $destPath
    if (-not (Test-Path $destDir)) { New-Item -ItemType Directory -Path $destDir -Force | Out-Null }
    New-Item -ItemType HardLink -Path $destPath -Value $f.FullName | Out-Null
    $n++
}
$sw.Stop()

"Hardlinked $n files in $([math]::Round($sw.Elapsed.TotalSeconds,1)) sec"
