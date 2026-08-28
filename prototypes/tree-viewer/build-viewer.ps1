#Requires -Version 7
# PROTOTYPE (#161) — splice dataset.json into viewer.template.html -> viewer.html (self-contained).
$ErrorActionPreference = 'Stop'
$json = Get-Content "$PSScriptRoot/dataset.json" -Raw
$tpl  = Get-Content "$PSScriptRoot/viewer.template.html" -Raw
if (-not $tpl.Contains('"__DATASET__"')) { throw 'placeholder "__DATASET__" not found in template.' }
$tpl.Replace('"__DATASET__"', $json.TrimEnd()) | Set-Content "$PSScriptRoot/viewer.html" -Encoding utf8
Write-Host "wrote $PSScriptRoot/viewer.html ($((Get-Item "$PSScriptRoot/viewer.html").Length / 1KB -as [int]) KB)"
