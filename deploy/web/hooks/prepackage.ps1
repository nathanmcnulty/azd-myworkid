Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Import-AzdEnvironment {
    $lines = azd env get-values
    foreach ($line in $lines) {
        if ([string]::IsNullOrWhiteSpace($line)) {
            continue
        }

        $parts = $line -split '=', 2
        if ($parts.Length -ne 2) {
            continue
        }

        $name = $parts[0].Trim()
        $value = $parts[1].Trim()
        if ($value.Length -ge 2 -and $value.StartsWith('"') -and $value.EndsWith('"')) {
            $value = $value.Substring(1, $value.Length - 2)
        }

        Set-Item -Path "Env:$name" -Value $value
    }
}

Import-AzdEnvironment

$deployRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$repoRoot = (Resolve-Path (Join-Path $deployRoot '..\..')).Path
$serverRoot = Join-Path $repoRoot 'src\MyWorkID.Server'
$clientRoot = Join-Path $repoRoot 'src\MyWorkID.Client'
$distRoot = Join-Path $deployRoot '.azd\dist'
$tmpRoot = Join-Path $deployRoot '.azd\tmp'
$deployMode = [Environment]::GetEnvironmentVariable('MYWORKID_DEPLOY_MODE')
if ([string]::IsNullOrWhiteSpace($deployMode)) {
    $deployMode = 'releaseZip'
}

if (Test-Path $distRoot) {
    Remove-Item -LiteralPath $distRoot -Recurse -Force
}

New-Item -ItemType Directory -Path $distRoot -Force | Out-Null
New-Item -ItemType Directory -Path $tmpRoot -Force | Out-Null

switch ($deployMode) {
    'releaseZip' {
        $releaseVersion = [Environment]::GetEnvironmentVariable('MYWORKID_RELEASE_VERSION')
        if ([string]::IsNullOrWhiteSpace($releaseVersion)) {
            $releaseVersion = 'latest'
        }

        $zipUrl = if ($releaseVersion -eq 'latest') {
            'https://github.com/glueckkanja/MyWorkID/releases/latest/download/binaries.zip'
        }
        else {
            "https://github.com/glueckkanja/MyWorkID/releases/download/$releaseVersion/binaries.zip"
        }

        $zipPath = Join-Path $tmpRoot 'binaries.zip'
        Invoke-WebRequest -Uri $zipUrl -OutFile $zipPath
        Expand-Archive -Path $zipPath -DestinationPath $distRoot -Force
        break
    }
    'sourceBuild' {
        Get-Command npm -ErrorAction Stop | Out-Null
        Get-Command dotnet -ErrorAction Stop | Out-Null

        Push-Location $clientRoot
        try {
            npm ci
            npm run build
        }
        finally {
            Pop-Location
        }

        Push-Location $serverRoot
        try {
            dotnet publish .\MyWorkID.Server.csproj -c Release -o $distRoot
        }
        finally {
            Pop-Location
        }

        $wwwroot = Join-Path $distRoot 'wwwroot'
        New-Item -ItemType Directory -Path $wwwroot -Force | Out-Null
        Copy-Item -Path (Join-Path $clientRoot 'dist\*') -Destination $wwwroot -Recurse -Force
        break
    }
    default {
        throw "Unsupported MYWORKID_DEPLOY_MODE '$deployMode'. Use 'releaseZip' or 'sourceBuild'."
    }
}
