param(
  [Parameter(Mandatory=$true)][string]$PublishDir,
  [Parameter(Mandatory=$true)][string]$Output,
  [Parameter(Mandatory=$true)][string]$SmokeResult,
  [string]$Version='0.5.0-beta.1',
  [Parameter(Mandatory=$true)][string]$SourceCommit
)
$ErrorActionPreference='Stop'
if ($Version -notmatch '^\d+\.\d+\.\d+-beta\.\d+$') { throw 'Expected a beta version.' }
if ($SourceCommit -notmatch '^[a-f0-9]{40}$') { throw 'Source commit must be a full Git SHA.' }
if (Test-Path $Output) { throw 'Release output already exists.' }
$smoke=Get-Content $SmokeResult -Raw | ConvertFrom-Json
if ($smoke.summary.failures -ne 0 -or $smoke.summary.passed -lt 45 -or $smoke.environment.sourceCommit -ne $SourceCommit) { throw 'Missing, failed, or mismatched Windows smoke evidence.' }
$publish=(Resolve-Path $PublishDir).Path
if ((Get-Item $publish).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Symlink publication directory rejected.' }
if (Get-ChildItem $publish -Recurse | Where-Object { $_.Attributes -band [IO.FileAttributes]::ReparsePoint }) { throw 'Symlink publication contents rejected.' }
$exe=Join-Path $publish 'YierBubu.exe'
$bytes=[IO.File]::ReadAllBytes($exe)
$pe=[BitConverter]::ToInt32($bytes,0x3c)
if ($bytes[0] -ne 0x4d -or $bytes[1] -ne 0x5a -or [BitConverter]::ToUInt32($bytes,$pe) -ne 0x4550 -or [BitConverter]::ToUInt16($bytes,$pe+4) -ne 0x8664) { throw 'Executable must be a real Windows x64 PE.' }
$config=Get-Content (Join-Path $publish 'YierBubu.runtimeconfig.json') -Raw | ConvertFrom-Json
if (-not $config.runtimeOptions.includedFrameworks) { throw 'Application is not self-contained.' }
New-Item -ItemType Directory -Path $Output | Out-Null
$destination=(Resolve-Path $Output).Path
$payload=Join-Path $destination 'YierBubu'
Copy-Item $publish $payload -Recurse
$windowsRoot=Split-Path -Parent $PSScriptRoot
Copy-Item (Join-Path $windowsRoot 'INSTALL.md') (Join-Path $payload '使用说明.txt')
Copy-Item (Join-Path $windowsRoot 'THIRD_PARTY_NOTICES.md') (Join-Path $payload '素材与来源说明.txt')
Copy-Item (Join-Path (Split-Path -Parent $windowsRoot) 'LICENSE') (Join-Path $payload 'LICENSE-code.txt')
$info=[ordered]@{
  version=$Version; platform='win-x64'; target='Windows 10 / Windows 11 x64, Intel and AMD';
  sourceCommit=$SourceCommit; builtOn=[System.Runtime.InteropServices.RuntimeInformation]::OSDescription;
  selfContained=$true; authenticodeSigned=$false; channel='beta';
  validation=[ordered]@{coreTests='See workflow log';serverDesktopSmoke=$true;smokeReportSHA256=(Get-FileHash $SmokeResult -Algorithm SHA256).Hash.ToLowerInvariant();windows10PhysicalInput=$false;windows11PhysicalInput=$false;intelAndAmdPhysical=$false;multiMonitorPhysical=$false};
  artworkLicense='Character assets excluded from code MIT; original rights remain with their owners.';
  privacy='No typed text, input history, telemetry, networking, startup registration, or simulated system input.'
}
$info | ConvertTo-Json -Depth 5 | Set-Content -Encoding utf8 (Join-Path $payload 'RELEASE-INFO.json')
$zip=Join-Path $destination "YierBubu-Windows-x64-v$Version.zip"
Compress-Archive -Path $payload -DestinationPath $zip -CompressionLevel Optimal
$roundtrip=Join-Path $destination 'verified-extraction'
Expand-Archive -Path $zip -DestinationPath $roundtrip
$original=@(Get-ChildItem $payload -Recurse -File)
$unpacked=Join-Path $roundtrip 'YierBubu'
if (@(Get-ChildItem $unpacked -Recurse -File).Count -ne $original.Count) { throw 'ZIP file inventory mismatch.' }
foreach ($file in $original) {
  $relative=[IO.Path]::GetRelativePath($payload,$file.FullName)
  if ((Get-FileHash $file.FullName -Algorithm SHA256).Hash -ne (Get-FileHash (Join-Path $unpacked $relative) -Algorithm SHA256).Hash) { throw "ZIP content mismatch: $relative" }
}
$check=Start-Process -FilePath (Join-Path $unpacked 'YierBubu.exe') -ArgumentList '--verify-assets' -Wait -PassThru
if ($check.ExitCode -ne 0) { throw 'Extracted package failed resource verification.' }
$hash=(Get-FileHash $zip -Algorithm SHA256).Hash.ToLowerInvariant()
"$hash  $([IO.Path]::GetFileName($zip))" | Set-Content -Encoding ascii (Join-Path $destination 'SHA256SUMS.txt')
Copy-Item (Join-Path $payload 'RELEASE-INFO.json') $destination
Write-Output "Verified Windows x64 portable package: $zip"
