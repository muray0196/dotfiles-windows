# scripts/Link-Configs.ps1
#Requires -Version 5.1
param(
  [string]$ConfigRoot = "$HOME\dotfiles-windows\config",
  [string]$ScoopRoot  = "$HOME\scoop",
  [switch]$SkipMissing,
  [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# --- Helpers ---------------------------------------------------------------
function Ensure-Dir {
  param([Parameter(Mandatory)][string]$Path)
  if (-not (Test-Path -LiteralPath $Path)) {
    if ($DryRun) { Write-Host "[DRY] MKDIR  $Path"; return }
    New-Item -ItemType Directory -Force -Path $Path | Out-Null
  }
}
function Remove-PathSafe {
  param([Parameter(Mandatory)][string]$Path)
  if (-not (Test-Path -LiteralPath $Path)) { return }
  $item = Get-Item -LiteralPath $Path -Force
  $isReparse = ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0
  $isDir = Test-Path -LiteralPath $Path -PathType Container
  if ($DryRun) { Write-Host "[DRY] RM     $Path"; return }
  if ($isReparse) { Remove-Item -LiteralPath $Path -Force }
  else            { Remove-Item -LiteralPath $Path -Force -Recurse:$isDir }
}
function New-SymlinkSafe {
  param(
    [Parameter(Mandatory)][string]$Link,
    [Parameter(Mandatory)][string]$Target
  )
  if (-not (Test-Path -LiteralPath $Target)) {
    if ($SkipMissing) { Write-Warning "Missing target -> $Target (skip)"; return }
    throw "Target not found: $Target"
  }
  $parent = Split-Path -Parent $Link
  if ($parent) { Ensure-Dir $parent }
  Remove-PathSafe $Link
  if ($DryRun) { Write-Host "[DRY] LINK   $Link -> $Target"; return }
  New-Item -ItemType SymbolicLink -Path $Link -Target $Target -Force | Out-Null
  Write-Host "[OK ] LINK   $Link -> $Target"
}

# --- Special folders (予約名は上書きしない) -----------------------------------
$UserHome     = $env:USERPROFILE
$Documents    = [Environment]::GetFolderPath('MyDocuments')
$AppData      = $env:APPDATA
$LocalAppData = $env:LOCALAPPDATA

$config     = $ConfigRoot
$scoop      = $ScoopRoot
$persist    = Join-Path $scoop 'persist'

# --- Link Map --------------------------------------------------------------
$links = @(
  # foobar2000
  @{ Link = Join-Path $persist 'foobar2000\profile\configuration'; Target = Join-Path $config 'foobar2000\configuration' }
  @{ Link = Join-Path $persist 'foobar2000\profile\dsp-presets';   Target = Join-Path $config 'foobar2000\dsp-presets'   }

  # Mp3tag
  @{ Link = Join-Path $persist 'mp3tag\data\columns.ini';  Target = Join-Path $config 'mp3tag\columns.ini'  }
  @{ Link = Join-Path $persist 'mp3tag\data\usrfields.ini';Target = Join-Path $config 'mp3tag\usrfields.ini'}

  # mpv
  @{ Link = Join-Path $persist 'mpv\portable_config';      Target = Join-Path $config 'mpv' }

  # Notepad++
  @{ Link = Join-Path $persist 'notepadplusplus'; Target = Join-Path $config 'npp' }

  # PowerShell Profile
  @{ Link = Join-Path $Documents 'PowerShell';              Target = Join-Path $config 'powershell' }

  # VS Code
  @{ Link = Join-Path $AppData 'Code\User\keybindings.json'; Target = Join-Path $config 'vscode\keybindings.json' }
  @{ Link = Join-Path $AppData 'Code\User\settings.json';    Target = Join-Path $config 'vscode\settings.json'    }

  # winget settings
  @{ Link = Join-Path $LocalAppData 'Packages\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe\LocalState\settings.json'
     Target = Join-Path $config 'winget\settings.json' }

  # Windows Terminal
  @{ Link = Join-Path $LocalAppData 'Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json'
     Target = Join-Path $config 'win-terminal\settings.json' }

  # WSL
  @{ Link = Join-Path $UserHome '.wslconfig';               Target = Join-Path $config 'wsl\.wslconfig' }
)

# --- Run -------------------------------------------------------------------
foreach ($m in $links) { New-SymlinkSafe -Link $m.Link -Target $m.Target }
Write-Host "`nDone."
