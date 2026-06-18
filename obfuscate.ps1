$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$installSh = Join-Path $env:TEMP "prometheus-install.sh"
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/prometheus-lua/Prometheus/master/install.sh" -OutFile $installSh -UseBasicParsing
bash $installSh
$cli = Join-Path $env:USERPROFILE ".local\bin\prometheus-lua.exe"
if (-not (Test-Path $cli)) {
	$cli = Join-Path $env:USERPROFILE ".local\bin\prometheus-lua"
}
if (-not (Test-Path $cli)) {
	throw "prometheus-lua not found after install"
}
$env:PROMETHEUS_CLI = $cli
$env:PROMETHEUS_PRESET = "Medium"
$env:PROMETHEUS_ENTRY_PRESET = "Weak"
bash (Join-Path $root "scripts\obfuscate.sh")
