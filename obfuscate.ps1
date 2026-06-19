$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path

function Get-PrometheusCli {
	$candidates = @(
		$env:PROMETHEUS_CLI,
		(Join-Path $env:USERPROFILE ".local\bin\prometheus-lua"),
		(Join-Path $env:USERPROFILE ".local\bin\prometheus-lua.exe")
	) | Where-Object { $_ -and (Test-Path $_) }
	if ($candidates.Count -gt 0) {
		return $candidates[0]
	}
	$installSh = Join-Path $env:TEMP "prometheus-install.sh"
	Invoke-WebRequest -Uri "https://raw.githubusercontent.com/prometheus-lua/Prometheus/master/install.sh" -OutFile $installSh -UseBasicParsing
	bash $installSh
	foreach ($path in @(
		(Join-Path $env:USERPROFILE ".local\bin\prometheus-lua"),
		(Join-Path $env:USERPROFILE ".local\bin\prometheus-lua.exe")
	)) {
		if (Test-Path $path) {
			return $path
		}
	}
	throw "prometheus-lua not found (install via WSL/bash or set PROMETHEUS_CLI)"
}

function Invoke-Obfuscate {
	param(
		[string]$InputPath,
		[string]$OutputPath,
		[string]$Preset
	)
	$dir = Split-Path -Parent $OutputPath
	if ($dir -and -not (Test-Path $dir)) {
		New-Item -ItemType Directory -Force -Path $dir | Out-Null
	}
	& $cli --LuaU --preset $Preset --nocolors --out $OutputPath $InputPath
	if ($LASTEXITCODE -ne 0) {
		throw "Obfuscation failed: $InputPath"
	}
}

$cli = Get-PrometheusCli
$preset = if ($env:PROMETHEUS_PRESET) { $env:PROMETHEUS_PRESET } else { "Medium" }
$entryPreset = if ($env:PROMETHEUS_ENTRY_PRESET) { $env:PROMETHEUS_ENTRY_PRESET } else { "Weak" }

$jobs = @(
	@{ In = "source\HmzHub.lua"; Out = "HmzHub.lua"; Preset = $entryPreset },
	@{ In = "source\HmzLoader.lua"; Out = "HmzLoader.lua"; Preset = $entryPreset },
	@{ In = "source\loader.lua"; Out = "loader.lua"; Preset = $entryPreset },
	@{ In = "source\HmzHub\core.lua"; Out = "HmzHub\core.lua"; Preset = $preset },
	@{ In = "source\HmzHub\games\anime_astral.lua"; Out = "HmzHub\games\anime_astral.lua"; Preset = $preset }
)

foreach ($job in $jobs) {
	$in = Join-Path $root $job.In
	$out = Join-Path $root $job.Out
	if (-not (Test-Path $in)) {
		throw "Missing source file: $in"
	}
	Write-Host "Obfuscating $($job.In) -> $($job.Out) [$($job.Preset)]"
	Invoke-Obfuscate -InputPath $in -OutputPath $out -Preset $job.Preset
}

Write-Host "Done. Commit and push obfuscated files only (source/ stays local)."
