# Plain assertions (no Pester needed): parses every script and tests the logic that runs without Windows.
# Usage: pwsh -File powershell/tests/Run-Tests.ps1   (exits 1 on any failure)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$failures = 0
function Assert-Equal($Actual, $Expected, [string]$Name) {
    if ("$Actual" -ceq "$Expected") { Write-Host "PASS $Name" }
    else { Write-Host "FAIL $Name`n  expected: $Expected`n  actual:   $Actual"; $script:failures++ }
}

foreach ($file in Get-ChildItem -LiteralPath $root -Filter *.ps1) {
    $tokens = $null; $errors = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$errors)
    Assert-Equal $errors.Count 0 "$($file.Name) parses"
}

. (Join-Path $root 'Get-ProxyAddresses.ps1')
$primary = ConvertTo-ProxyAddressRecord -SamAccountName jsmith -ProxyAddress 'SMTP:john.smith@contoso.com'
Assert-Equal "$($primary.Type)|$($primary.Address)|$($primary.IsPrimary)" 'SMTP|john.smith@contoso.com|True' 'primary SMTP address'
$secondary = ConvertTo-ProxyAddressRecord -SamAccountName jsmith -ProxyAddress 'smtp:js@contoso.com'
Assert-Equal "$($secondary.Type)|$($secondary.IsPrimary)" 'SMTP|False' 'secondary smtp address'
$odd = ConvertTo-ProxyAddressRecord -SamAccountName jsmith -ProxyAddress 'no-prefix'
Assert-Equal "$($odd.Type)|$($odd.Address)|$($odd.IsPrimary)" '|no-prefix|False' 'address without a type prefix'

. (Join-Path $root 'Set-DevicePath.ps1')
$vars = @{ SystemRoot = 'C:\Windows'; SystemDrive = 'C:' }
Assert-Equal (ConvertTo-PortablePath -Path 'c:\windows\inf\oem' -Variables $vars) '%SystemRoot%\inf\oem' 'Windows folder becomes %SystemRoot% (longest match first)'
Assert-Equal (ConvertTo-PortablePath -Path 'C:\Drivers\LAN' -Variables $vars) '%SystemDrive%\Drivers\LAN' 'system drive becomes %SystemDrive%, case kept'
Assert-Equal (ConvertTo-PortablePath -Path 'D:\Drivers' -Variables $vars) 'D:\Drivers' 'other drives unchanged'
Assert-Equal (Get-NewDevicePath -Current '%SystemRoot%\inf' -Folders @('C:\Drivers\LAN', 'C:\Drivers\Video') -Variables $vars) '%SystemRoot%\inf;%SystemDrive%\Drivers\LAN;%SystemDrive%\Drivers\Video' 'folders appended in order'
Assert-Equal (Get-NewDevicePath -Current '%SystemRoot%\inf;%SYSTEMDRIVE%\DRIVERS\LAN' -Folders @('C:\Drivers\LAN') -Variables $vars) '%SystemRoot%\inf;%SYSTEMDRIVE%\DRIVERS\LAN' 'existing entry (any case) not added again'
Assert-Equal (Get-NewDevicePath -Current '' -Folders @('D:\Drv') -Variables $vars) 'D:\Drv' 'empty value'

$temp = Join-Path ([System.IO.Path]::GetTempPath()) ([guid]::NewGuid())
New-Item -ItemType Directory -Path (Join-Path $temp 'LAN'), (Join-Path $temp 'Video/Intel'), (Join-Path $temp 'Empty') | Out-Null
'x' | Set-Content (Join-Path $temp 'LAN/net.inf')
'x' | Set-Content (Join-Path $temp 'Video/Intel/igd.inf')
'x' | Set-Content (Join-Path $temp 'Empty/readme.txt')
try {
    $found = @(Get-DriverFolders -Root $temp | ForEach-Object { $_.Substring($temp.Length).Replace('\', '/') } | Sort-Object)
    Assert-Equal ($found -join ',') '/LAN,/Video/Intel' 'only folders with .inf files, recursively'
}
finally {
    Remove-Item -LiteralPath $temp -Recurse -Force
}

if ($failures -gt 0) { Write-Host "$failures failed"; exit 1 }
Write-Host 'All passed'
