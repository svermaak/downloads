<#
.SYNOPSIS
    Adds every folder under a driver folder that contains .inf files to the DevicePath registry value.

.DESCRIPTION
    PowerShell port of SetDevicePath.vbs. Windows searches the folders in DevicePath
    (HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion) for drivers when new hardware appears, so pointing it at an
    extracted driver library lets Plug and Play find them without anyone browsing to a folder.

    The folder and all its subfolders are searched; each one holding at least one .inf file is appended, unless it
    is already listed. Paths under the Windows folder or the system drive are written as %SystemRoot% and
    %SystemDrive%, so the value still works if the image is deployed to another drive letter.

    Differences from the original: the value keeps its original case (the VBScript upper-cased everything), the
    %SystemRoot% substitution now actually applies (the VBScript overwrote it with the system drive one), and
    -WhatIf shows the new value without writing it. Run it as an administrator.

.PARAMETER DriverFolder
    The root of the driver library, for example C:\Drivers.

.EXAMPLE
    .\Set-DevicePath.ps1 -DriverFolder C:\Drivers -WhatIf

.EXAMPLE
    .\Set-DevicePath.ps1 -DriverFolder C:\Drivers

.NOTES
    ITtelligence – https://ittelligence.blog/2009/04/10/setdevicepath/
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$DriverFolder
)

function ConvertTo-PortablePath {
    <# Swaps the Windows folder and the system drive for their variables, the longer match first, case-insensitively. #>
    param([string]$Path, [hashtable]$Variables)
    foreach ($name in ($Variables.Keys | Sort-Object { $Variables[$_].Length } -Descending)) {
        $value = $Variables[$name].TrimEnd('\')
        if ($value -and $Path.StartsWith($value, [StringComparison]::OrdinalIgnoreCase)) {
            return "%$name%" + $Path.Substring($value.Length)
        }
    }
    return $Path
}

function Get-NewDevicePath {
    <# The current value plus each new folder, in order, skipping folders already listed (compared case-insensitively). #>
    param([string]$Current, [string[]]$Folders, [hashtable]$Variables)
    $entries = [System.Collections.Generic.List[string]]::new()
    foreach ($entry in ($Current -split ';')) {
        if ($entry.Trim()) { $entries.Add($entry.Trim()) }
    }
    foreach ($folder in $Folders) {
        $portable = ConvertTo-PortablePath -Path $folder -Variables $Variables
        $known = @($entries | Where-Object { $_ -eq $portable -or $_ -eq $folder })
        if ($known.Count -eq 0) { $entries.Add($portable) }
    }
    return ($entries -join ';')
}

function Get-DriverFolders {
    param([string]$Root)
    $folders = @(Get-Item -LiteralPath $Root) + @(Get-ChildItem -LiteralPath $Root -Directory -Recurse)
    foreach ($folder in $folders) {
        if (Get-ChildItem -LiteralPath $folder.FullName -Filter *.inf -File | Select-Object -First 1) { $folder.FullName }
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    if (-not $DriverFolder -or -not (Test-Path -LiteralPath $DriverFolder -PathType Container)) {
        throw "Driver folder not found: '$DriverFolder'. Usage: .\Set-DevicePath.ps1 -DriverFolder C:\Drivers"
    }
    $key = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion'
    # Read the raw value: expanding the variables would write literal paths back.
    $current = (Get-Item -LiteralPath $key).GetValue('DevicePath', '', [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
    $variables = @{ SystemRoot = $env:SystemRoot; SystemDrive = $env:SystemDrive }
    $newValue = Get-NewDevicePath -Current $current -Folders @(Get-DriverFolders -Root $DriverFolder) -Variables $variables
    $newValue
    if ($newValue -ne $current -and $PSCmdlet.ShouldProcess("$key\DevicePath", "Set to '$newValue'")) {
        Set-ItemProperty -LiteralPath $key -Name DevicePath -Value $newValue -Type ExpandString
    }
}
