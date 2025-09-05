# scripts/Link-Configs.ps1
#Requires -Version 5.1
[CmdletBinding(PositionalBinding=$false)]
param(
  [string]$ConfigRoot = "$HOME\dotfiles-windows\config",
  [string]$ScriptsRoot = "$HOME\dotfiles-windows\scripts",
  [string]$ScoopRoot  = "$HOME\scoop",
  [switch]$SkipMissingTarget,
  [switch]$DryRun,
  [switch]$Replace
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# Guard: reject unexpected positional args (typos etc.)
if ($args.Count -gt 0) {
  Write-Warning ("Unknown or unexpected argument(s): {0}. Use named switches only: -SkipMissingTarget, -DryRun, -Replace" -f ($args -join ', '))
  return
}

# Banner for DryRun mode
if ($DryRun) {
  Write-Host "[DRY] Preview mode: no changes will be made." -ForegroundColor Cyan
}

# --- Helpers ---------------------------------------------------------------
# 集計用（実行中に随時追加して最後にサマリ表示）
$script:Created        = @()  # 実際に作成
$script:AlreadyLinked  = @()  # 既に同一ターゲットにリンク済み
$script:SkippedMissing = @()  # ターゲット欠落によりスキップ
$script:Failed         = @()  # エラー
$script:BackedUp       = @()  # 既存をバックアップに退避

function Write-LineWithColor {
  param(
    [Parameter(Mandatory)][string]$Message,
    [ConsoleColor]$Color = [ConsoleColor]::White
  )
  Write-Host $Message -ForegroundColor $Color
}

function Normalize-PathSafe {
  param([Parameter(Mandatory)][string]$Path)
  try { return (Resolve-Path -LiteralPath $Path).ProviderPath } catch { return [IO.Path]::GetFullPath($Path) }
}

function Format-Label {
  param(
    [string]$App,
    [string]$Item,
    [string]$Fallback
  )
  if ($App) { if ($Item) { return ("{0}: {1}" -f $App, $Item) } else { return $App } }
  return $Fallback
}
function New-BackupPath {
  param([Parameter(Mandatory)][string]$Path)
  $dir  = Split-Path -Parent $Path
  $name = Split-Path -Leaf $Path
  $candidate = Join-Path $dir ("{0}.bak" -f $name)
  $i = 1
  while (Test-Path -LiteralPath $candidate) {
    $candidate = Join-Path $dir ("{0}.bak-{1}" -f $name, $i)
    $i++
  }
  return $candidate
}

function Backup-Or-ReplaceExisting {
  param(
    [Parameter(Mandatory)][string]$Path,
    [string]$App,
    [string]$Item
  )
  if (-not (Test-Path -LiteralPath $Path)) { return }
  if ($Replace) {
    if ($DryRun) { Write-LineWithColor ("[DRY]  REPLACE REMOVE {0}" -f $Path) 'DarkYellow'; return }
    Remove-PathSafe -Path $Path
    Write-LineWithColor ("[REPL] REMOVE  {0}" -f $Path) 'DarkYellow'
    return
  }
  $bak = New-BackupPath -Path $Path
  if ($DryRun) {
    Write-LineWithColor ("[DRY]  BACKUP  {0} -> {1}" -f $Path, $bak) 'Magenta'
    $script:BackedUp += [pscustomobject]@{ App=$App; Item=$Item; Path=$Path; Backup=$bak }
    return
  }
  try {
    Rename-Item -LiteralPath $Path -NewName (Split-Path -Leaf $bak) -Force
    Write-LineWithColor ("[BKUP] MOVE    {0} -> {1}" -f $Path, $bak) 'Magenta'
    $script:BackedUp += [pscustomobject]@{ App=$App; Item=$Item; Path=$Path; Backup=$bak }
  } catch {
    throw "Backup failed: $($_.Exception.Message)"
  }
}
function Remove-PathSafe {
  param([Parameter(Mandatory)][string]$Path)
  if (-not (Test-Path -LiteralPath $Path)) { return }
  $item = Get-Item -LiteralPath $Path -Force
  $isReparse = ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0
  $isDir = Test-Path -LiteralPath $Path -PathType Container
  if ($DryRun) { Write-LineWithColor "[DRY]  RM      $Path" 'DarkGray'; return }
  if ($isReparse) { Remove-Item -LiteralPath $Path -Force }
  else            { Remove-Item -LiteralPath $Path -Force -Recurse:$isDir }
}
function New-SymlinkSafe {
  param(
    [Parameter(Mandatory)][string]$Link,
    [Parameter(Mandatory)][string]$Target,
    [string]$App,
    [string]$Item
  )
  if (-not (Test-Path -LiteralPath $Target)) {
    if ($SkipMissingTarget) {
      $msg = "[SKIP] MISSING $Link -> $Target"
      Write-LineWithColor $msg 'Yellow'
      $script:SkippedMissing += [pscustomobject]@{ App=$App; Item=$Item; Link=$Link; Target=$Target; Reason='Missing target' }
      return
    }
    throw "Target not found: $Target"
  }
  $parent = Split-Path -Parent $Link
  if ($parent -and -not (Test-Path -LiteralPath $parent -PathType Container)) {
    $msg = "[SKIP] MISSING PARENT $parent (for $Link)"
    Write-LineWithColor $msg 'Yellow'
    $script:SkippedMissing += [pscustomobject]@{ App=$App; Item=$Item; Link=$Link; Target=$Target; Reason='Missing parent directory' }
    return
  }

  # 既存で同一ターゲットならスキップ
  if (Test-Path -LiteralPath $Link) {
    try {
      $existing = Get-Item -LiteralPath $Link -Force
      $isReparse = ($existing.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0
      $existingTarget = $null
      if ($isReparse) {
        try { $existingTarget = $existing.Target } catch { $existingTarget = $null }
      }
      if ($existingTarget) {
        # Normalize for比較
        $t1 = Normalize-PathSafe -Path $Target
        $t2 = Normalize-PathSafe -Path $existingTarget
        if ($t1 -eq $t2) {
          $msg = "[SAME] LINK   $Link -> $Target"
          Write-LineWithColor $msg 'DarkGray'
          $script:AlreadyLinked += [pscustomobject]@{ App=$App; Item=$Item; Link=$Link; Target=$Target }
          return
        }
      }
    } catch {
      # 取得に失敗した場合は通常処理
    }
  }

  Backup-Or-ReplaceExisting -Path $Link -App $App -Item $Item
  if ($DryRun) {
    Write-LineWithColor "[DRY]  LINK    $Link -> $Target" 'Cyan'
    return
  }
  New-Item -ItemType SymbolicLink -Path $Link -Target $Target -Force | Out-Null
  Write-LineWithColor "[OK ]  LINK    $Link -> $Target" 'Green'
  $script:Created += [pscustomobject]@{ App=$App; Item=$Item; Link=$Link; Target=$Target }
}

# --- Special folders -----------------------------------
$UserHome     = $env:USERPROFILE
$Documents    = [Environment]::GetFolderPath('MyDocuments')
$AppData      = $env:APPDATA
$LocalAppData = $env:LOCALAPPDATA

$config     = $ConfigRoot
$scripts     = $ScriptsRoot
$scoop      = $ScoopRoot
$persist    = Join-Path $scoop 'persist'

# --- Link Map --------------------------------------------------------------
$links = @(
  # foobar2000
  @{ App='foobar2000'; Item='configuration'; Link = Join-Path $persist 'foobar2000\profile\configuration'; Target = Join-Path $config 'foobar2000\configuration' }
  @{ App='foobar2000'; Item='dsp-presets';   Link = Join-Path $persist 'foobar2000\profile\dsp-presets';   Target = Join-Path $config 'foobar2000\dsp-presets'   }

  # Mp3tag
  @{ App='Mp3tag'; Item='columns.ini';  Link = Join-Path $persist 'mp3tag\data\columns.ini';  Target = Join-Path $config 'mp3tag\columns.ini'  }
  @{ App='Mp3tag'; Item='usrfields.ini';Link = Join-Path $persist 'mp3tag\data\usrfields.ini';Target = Join-Path $config 'mp3tag\usrfields.ini'}

  # mpv
  @{ App='mpv'; Item='portable_config'; Link = Join-Path $persist 'mpv\portable_config';      Target = Join-Path $config 'mpv' }

  # Notepad++
  @{ App='Notepad++'; Item='config'; Link = Join-Path $persist 'notepadplusplus'; Target = Join-Path $config 'npp' }

  # PowerShell Profile
  @{ App='PowerShell'; Item='Profile'; Link = Join-Path $Documents 'PowerShell\Microsoft.PowerShell_profile.ps1'; Target = Join-Path $config 'powershell\Microsoft.PowerShell_profile.ps1' }

  # VS Code
  @{ App='VS Code'; Item='keybindings.json'; Link = Join-Path $AppData 'Code\User\keybindings.json'; Target = Join-Path $config 'vscode\keybindings.json' }
  @{ App='VS Code'; Item='settings.json';    Link = Join-Path $AppData 'Code\User\settings.json';    Target = Join-Path $config 'vscode\settings.json'    }

  # Neovim
  @{ App='Neovim'; Item='init'; Link = Join-Path $LocalAppData 'nvim\init.lua'; Target = Join-Path $config 'nvim\init.lua' }
  @{ App='Neovim'; Item='config';    Link = Join-Path $LocalAppData 'nvim\lua';    Target = Join-Path $config 'nvim\lua'    }

  # winget settings
  @{ App='winget'; Item='settings.json'; Link = Join-Path $LocalAppData 'Packages\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe\LocalState\settings.json'
     Target = Join-Path $config 'winget\settings.json' }

  # Windows Terminal
  @{ App='Windows Terminal'; Item='settings.json'; Link = Join-Path $LocalAppData 'Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json'
     Target = Join-Path $config 'win-terminal\settings.json' }

  # WSL
  @{ App='WSL'; Item='.wslconfig'; Link = Join-Path $UserHome '.wslconfig'; Target = Join-Path $config 'wsl\.wslconfig' }
  
  # AHK script on startup
  @{ App='AHK'; Item='AHK script'; Link = Join-Path $AppData 'Microsoft\Windows\Start Menu\Programs\Startup\ctrl,h_backspace.ahk'; Target = Join-Path $scripts 'ahk\ctrl,h_backspace.ahk' }
)

# --- Run -------------------------------------------------------------------
foreach ($m in $links) {
  try {
    New-SymlinkSafe -Link $m.Link -Target $m.Target -App $m.App -Item $m.Item
  } catch {
    $err = $_.Exception.Message
    Write-LineWithColor "[FAIL] LINK    $($m.Link) -> $($m.Target) : $err" 'Red'
    $script:Failed += [pscustomobject]@{ App=$m.App; Item=$m.Item; Link=$m.Link; Target=$m.Target; Error=$err }
  }
}

# --- Summary ---------------------------------------------------------------
Write-Host ""
$summaryTitle = if ($DryRun) { '===== Summary (DRY RUN) =====' } else { '===== Summary =====' }
Write-Host $summaryTitle

function Print-Section {
  param(
    [Parameter(Mandatory)][string]$Title,
    [AllowEmptyCollection()][object[]]$Items = @(),
    [Parameter(Mandatory)][string]$Marker,
    [Parameter(Mandatory)][ConsoleColor]$Color,
    [switch]$ShowError
  )
  Write-Host (" {0}: {1}" -f $Title, $Items.Count)
  if ($Items.Count -gt 0) {
    foreach ($i in $Items) {
      $fallback = if ($i.PSObject.Properties.Name -contains 'Link') { $i.Link } elseif ($i.PSObject.Properties.Name -contains 'Path') { $i.Path } else { $null }
      $label = Format-Label -App $i.App -Item $i.Item -Fallback $fallback
      if ($ShowError) { Write-LineWithColor ("   {0} {1} : {2}" -f $Marker, $label, $i.Error) $Color }
      else            { Write-LineWithColor ("   {0} {1}"     -f $Marker, $label) $Color }
    }
  }
}

Print-Section -Title 'Backed up'     -Items $script:BackedUp       -Marker '>' -Color 'Magenta'
Print-Section -Title 'Created'       -Items $script:Created        -Marker '+' -Color 'Green'
Print-Section -Title 'Already (same)'-Items $script:AlreadyLinked  -Marker '=' -Color 'DarkGray'
Print-Section -Title 'Skipped'       -Items $script:SkippedMissing -Marker '~' -Color 'Yellow'
Print-Section -Title 'Failed'        -Items $script:Failed         -Marker 'x' -Color 'Red' -ShowError
Write-Host "==================="

$doneMsg = if ($DryRun) { 'Done (dry-run).' } else { 'Done.' }
Write-Host $doneMsg
