function update {
	scoop update * && winget update --all
}

function cleanup {
	scoop cleanup * && scoop cache rm * && Remove-Item -Recurse -Force "$env:TEMP\WinGet" -ErrorAction SilentlyContinue && Remove-Item -Recurse -Force "$env:LOCALAPPDATA\Packages\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe\LocalState\DiagOutputDir\*" -ErrorAction SilentlyContinue
}

function audio-ls {
    yt-dlp -F @Args | rg "audio only"
}

function audio-dl {
    param(
        [Parameter(ValueFromRemainingArguments=$true)]
        $Args
    )

    $params = @(
        '-P', "$HOME\Downloads",
        '-f', 'bestaudio[acodec=opus]/bestaudio',
		    '--remux-video', 'webm>opus/mp4>m4a',
        '--downloader', 'aria2c',
        '--downloader', 'm3u8,dash:aria2c',
        '--downloader-args', 'aria2c:-c -x 8 -s 8 -k 1M --file-allocation=none',
        '--embed-metadata'
    )

    if ($Args) { $params += $Args }

    & yt-dlp @params
}

function crop {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)] [string]$In,
    [Parameter(Mandatory)] [string]$To,
    [string]$Out
  )

  if (-not (Get-Command ffmpeg -ErrorAction SilentlyContinue)) {
    Write-Error "ffmpegが見つかりません。"; return
  }

  $ext = [IO.Path]::GetExtension($In).ToLowerInvariant()
  $allowed = '.opus', '.mp3', '.aac', '.m4a', '.flac'
  if ($ext -notin $allowed) {
    Write-Error "対応拡張子は .opus / .mp3 / .aac / .m4a / .flac のみです: $In"; return
  }

  if (-not $Out) {
    $base = [IO.Path]::GetFileNameWithoutExtension($In)
    $dir  = [IO.Path]::GetDirectoryName($In)
    $tag  = ($To -replace '[^\d]', '-')
    $Out  = Join-Path $dir ("{0}_0to{1}{2}" -f $base, $tag, $ext)
  } else {
    if (-not [IO.Path]::HasExtension($Out)) { $Out += $ext }
  }

  $common = @(
    '-hide_banner','-v','error',
    '-ss','0','-to',"$To",
    '-i',"$In",
    '-map','0:a:0'
  )

  if ($ext -eq '.flac') {
    $args = $common + @(
      '-c:a','flac','-compression_level','8',
      '-map_metadata','0'
    )
  } else {
    $args = $common + @('-c','copy')
    switch ($ext) {
      '.mp3' { $args += @('-write_xing','0') }
      '.m4a' { $args += @('-movflags','+faststart') }
      default { }
    }
  }

  $args += @("$Out")
  ffmpeg @args
}
