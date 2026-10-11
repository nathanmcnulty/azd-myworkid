#Requires -Version 7.6
[CmdletBinding()]
param([Parameter(Mandatory)][string]$TargetPath)
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'MyWorkID.Status.psm1') -Force
try {
    $target = Get-Content -LiteralPath $TargetPath -Raw | ConvertFrom-Json -DateKind String
    $report = Get-MwidSetupStatus -Target $target
    $report | ConvertTo-Json -Depth 16
    if (@($report.gates | Where-Object status -eq 'failed').Count -gt 0) { exit 1 }
} catch { throw 'Setup status could not be produced. Check the reviewed target shape and selected cached account. No raw provider error or target file is emitted.' }
