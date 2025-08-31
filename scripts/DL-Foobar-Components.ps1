# PowerShell 5/7 どちらでも可。管理者権限は不要（保存先に権限があればOK）
$ErrorActionPreference = 'Stop'
$dest = "$HOME\Downloads\fb2k-components"

New-Item -ItemType Directory -Force -Path $dest | Out-Null

function Get-Fb2kDownloadUrl {
    param([string]$PageUrl)
    $resp = Invoke-WebRequest -Uri $PageUrl
    $a = $resp.Links | Where-Object { $_.href -match '/getcomponent/.+\.fb2k-component$' } | Select-Object -First 1
    if ($a) {
        $href = $a.href
        if ($href -notmatch '^https?://') {
            $base = ([uri]$PageUrl).GetLeftPart([System.UriPartial]::Authority)
            if (-not $href.StartsWith('/')) { $href = '/' + $href }
            return $base + $href
        }
        return $href
    }
    $m = [regex]::Match($resp.Content, 'https?://www\.foobar2000\.org/getcomponent/[^"''\s]+?\.fb2k-component')
    if ($m.Success) { return $m.Value }
    return $null
}


function Get-HyvDownloadUrl {
    param([string]$PageUrl)
    $resp = Invoke-WebRequest -Uri $PageUrl
    $a = $resp.Links | Where-Object { $_.href -match '\.fb2k-component$' } | Select-Object -First 1
    if ($a) {
        # 相対→絶対
        if ($a.href -notmatch '^https?://') {
            $base = ([uri]$PageUrl).GetLeftPart([System.UriPartial]::Authority)
            $path = if ($a.href.StartsWith('/')) { $a.href } else { '/' + $a.href }
            return $base + $path
        }
        return $a.href
    }
    $m = [regex]::Match($resp.Content, 'https?://foobar\.hyv\.fi/[^"''\s]+?\.fb2k-component')
    if ($m.Success) { return $m.Value }
    return $null
}

$targets = @(
 # SoX resampler（Caseリビルド配布）
 @{ name='foo_dsp_resampler'; page='https://foobar.hyv.fi/?view=foo_dsp_resampler'; getter='hyv' },
 # OpenLyrics
 @{ name='foo_openlyrics';   page='https://www.foobar2000.org/components/view/foo_openlyrics';   getter='fb2k' },
 # ASIO 出力
 @{ name='foo_out_asio';     page='https://www.foobar2000.org/components/view/foo_out_asio';     getter='fb2k' },
 # Last.fm Scrobble
 @{ name='foo_scrobble';     page='https://www.foobar2000.org/components/view/foo_scrobble';     getter='fb2k' },
 # Columns UI（安定版 3.0.1 を指名。最新アルファが欲しければ page を安定→最新に差し替え）
 @{ name='foo_ui_columns';   page='https://www.foobar2000.org/components/view/foo_ui_columns'; getter='fb2k' },
 # Album list panel（Columns UI 用）
 @{ name='foo_uie_albumlist';page='https://www.foobar2000.org/components/view/foo_uie_albumlist'; getter='fb2k' }
)

foreach ($t in $targets) {
    $url = if ($t.getter -eq 'hyv') { Get-HyvDownloadUrl $t.page } else { Get-Fb2kDownloadUrl $t.page }
    if (-not $url) { Write-Warning "リンク取得失敗: $($t.name) <$($t.page)>"; continue }
    $out = Join-Path $dest (Split-Path -Leaf $url)
    Write-Host "↓ $($t.name)`n$url"
    Invoke-WebRequest -Uri $url -OutFile $out
}
このコードで無事に動いた。改善として、ダウンロードしたパスを表示するように

様々な顧客サービスを用意