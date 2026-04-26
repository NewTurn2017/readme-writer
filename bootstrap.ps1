# readme-writer bootstrap installer for Windows (PowerShell 5.1+ / 7+).
#
# Usage:
#   iwr -useb https://raw.githubusercontent.com/NewTurn2017/readme-writer/main/bootstrap.ps1 | iex
#
# Env vars:
#   READMEW_HOME   Install destination. Default: $HOME\.readme-writer
#   READMEW_REPO   Git URL. Default: https://github.com/NewTurn2017/readme-writer.git
#   READMEW_REF    Branch / tag. Default: main
#
# Notes:
#   - Requires git and python3 in PATH.
#   - Symlink creation requires Developer Mode or running as Administrator.
#     Otherwise this script falls back to copying.

$ErrorActionPreference = 'Stop'

$Repo = if ($env:READMEW_REPO) { $env:READMEW_REPO } else { 'https://github.com/NewTurn2017/readme-writer.git' }
$Ref  = if ($env:READMEW_REF)  { $env:READMEW_REF  } else { 'main' }
$Dest = if ($env:READMEW_HOME) { $env:READMEW_HOME } else { Join-Path $HOME '.readme-writer' }

function Need-Cmd($name) {
  if (-not (Get-Command $name -ErrorAction SilentlyContinue)) {
    Write-Host "missing required command: $name" -ForegroundColor Red; exit 1
  }
}
function Info($msg) { Write-Host $msg -ForegroundColor Cyan }
function Ok($msg)   { Write-Host $msg -ForegroundColor Green }
function Warn($msg) { Write-Host $msg -ForegroundColor Yellow }

Need-Cmd git
Need-Cmd python

# 1. Clone or update
Info "[1/3] cloning $Repo -> $Dest"
if (Test-Path (Join-Path $Dest '.git')) {
  git -C $Dest fetch --quiet origin $Ref
  git -C $Dest checkout --quiet $Ref
  git -C $Dest pull --quiet --ff-only origin $Ref | Out-Null
  Ok "  updated existing checkout."
} else {
  if ((Test-Path $Dest) -and -not (Test-Path (Join-Path $Dest '.git'))) {
    if ((Get-ChildItem -Force $Dest -ErrorAction SilentlyContinue | Measure-Object).Count -gt 0) {
      Write-Host "  $Dest is non-empty and not a git repo. aborting." -ForegroundColor Red; exit 1
    }
  }
  git clone --quiet --branch $Ref $Repo $Dest
  Ok "  cloned."
}

# 2. Symlink into Claude Code / Codex skill dirs
Info "[2/3] linking skill into ~/.claude/skills and ~/.codex/skills"

$Skills = @('readme-writer')
$Targets = @(
  (Join-Path $HOME '.claude\skills'),
  (Join-Path $HOME '.codex\skills')
)

function Try-Symlink($Path, $Target) {
  try {
    New-Item -ItemType SymbolicLink -Path $Path -Target $Target -ErrorAction Stop | Out-Null
    return $true
  } catch { return $false }
}

$FellBackToCopy = $false
foreach ($dir in $Targets) {
  if (-not (Test-Path $dir)) {
    Write-Host "  skip: $dir does not exist" -ForegroundColor DarkGray; continue
  }
  foreach ($skill in $Skills) {
    $linkPath = Join-Path $dir $skill
    $srcPath  = Join-Path $Dest "skills\$skill"

    if (Test-Path $linkPath) {
      $item = Get-Item $linkPath -Force
      if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
        $existingTarget = (Get-Item $linkPath -Force).Target
        if ($existingTarget -and ($existingTarget | Where-Object { $_ -eq $srcPath })) {
          Write-Host "  ok:   $linkPath (already linked)" -ForegroundColor DarkGray; continue
        }
      }
      $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
      $backup = "$linkPath.backup-$stamp"
      Write-Host "  move: $linkPath -> $backup"
      Move-Item -Path $linkPath -Destination $backup -Force
    }

    if (Try-Symlink -Path $linkPath -Target $srcPath) {
      Write-Host "  link: $linkPath -> $srcPath" -ForegroundColor Green
    } else {
      Warn "  fallback to copy (symlink permission denied; enable Developer Mode for symlinks)"
      Copy-Item -Recurse -Force -Path $srcPath -Destination $linkPath
      Write-Host "  copy: $linkPath" -ForegroundColor Green
      $FellBackToCopy = $true
    }
  }
}

Info "[3/3] done."
Ok "readme-writer installed at $Dest"
if ($FellBackToCopy) {
  Warn "Some links fell back to copy mode. Enable Developer Mode (Settings -> For developers)"
  Warn "for true symlinks so 'git pull' updates instantly."
}
Write-Host ""
Write-Host "Next steps:"
Write-Host "  - Start a new Claude Code or Codex session in any repo."
Write-Host "  - Try: 'write README for this project' or '이 레포에 README 써줘'"
Write-Host "  - Update later: cd `"$Dest`"; git pull"
