#Requires -Version 7.6
$ErrorActionPreference='Stop'
Import-Module Pester -MinimumVersion 5.7 -ErrorAction Stop
$result=Invoke-Pester -Path "$PSScriptRoot/../tests/SetupStatus.Tests.ps1" -PassThru -Output Detailed
if ($result.FailedCount -or $result.TotalCount -eq 0) { throw 'Setup status tests failed.' }
