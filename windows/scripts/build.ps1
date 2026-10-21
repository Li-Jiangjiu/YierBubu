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
# Runtime packs contain license/notices that the SDK does not automatically publish.
$nugetLine=& dotnet nuget locals global-packages --list --force-english-output
if ($LASTEXITCODE -ne 0) { throw 'Cannot locate official runtime pack licenses.' }
$nugetRoot=($nugetLine -replace '^global-packages:\s*','').Trim()
$config=Get-Content (Join-Path $Output 'YierBubu.runtimeconfig.json') -Raw | ConvertFrom-Json
foreach ($framework in $config.runtimeOptions.includedFrameworks) {
  $packageId=$framework.name.ToLowerInvariant()+'.runtime.win-x64'
  $pack=Join-Path (Join-Path $nugetRoot $packageId) $framework.version
  $notices=@(Get-ChildItem $pack -File | Where-Object { $_.Name -match '^(LICENSE(\.TXT)?|THIRD[-_ ]?PARTY.*)$' })
  if (-not ($notices | Where-Object { $_.Name -match '^LICENSE(\.TXT)?$' })) { throw "Runtime license missing: $packageId" }
  $noticeDir=Join-Path (Join-Path $Output 'RuntimeNotices') $framework.name
  New-Item -ItemType Directory -Path $noticeDir -Force | Out-Null
  foreach ($notice in $notices) { Copy-Item $notice.FullName $noticeDir }
}
$check=Start-Process -FilePath (Join-Path (Resolve-Path $Output) 'YierBubu.exe') -ArgumentList '--verify-assets' -Wait -PassThru
if ($check.ExitCode -ne 0) { throw 'Published application resource verification failed.' }
