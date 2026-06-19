$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path

& (Join-Path $root "build.ps1")

$version = Get-Content (Join-Path $root "VERSION") -Raw
Write-Host "Release version: $version"
Write-Host "Loadstring:"
Write-Host "loadstring(game:HttpGet('https://raw.githubusercontent.com/hmzqlf/rbx_script/$version/HmzHub.lua'))()"
Write-Host "Done. Push HmzHub.lua and VERSION to GitHub."
