param([Parameter(Mandatory=$true)][string]$Output)
$ErrorActionPreference='Stop'
$projectRoot=Split-Path -Parent $PSScriptRoot
$env:DOTNET_CLI_TELEMETRY_OPTOUT='1'
if (Test-Path $Output) { throw 'Output already exists; choose a new directory.' }
& python (Join-Path $PSScriptRoot 'prepare-assets.py')
if ($LASTEXITCODE -ne 0) { throw 'Approved asset preparation failed.' }
& dotnet run --project (Join-Path $projectRoot 'YierBubu.Tests') -c Release
if ($LASTEXITCODE -ne 0) { throw 'Core tests failed.' }
& dotnet publish (Join-Path $projectRoot 'YierBubu.Windows') -c Release -r win-x64 --self-contained true -p:PublishSingleFile=false -p:DebugType=None -p:DebugSymbols=false -p:ContinuousIntegrationBuild=true -o $Output
if ($LASTEXITCODE -ne 0) { throw 'Windows publication failed.' }
$check=Start-Process -FilePath (Join-Path (Resolve-Path $Output) 'YierBubu.exe') -ArgumentList '--verify-assets' -Wait -PassThru
if ($check.ExitCode -ne 0) { throw 'Published application resource verification failed.' }
