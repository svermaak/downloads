<#
.SYNOPSIS
    Reads the regional settings of the default user profile on one or more remote computers.

.DESCRIPTION
    PowerShell port of GetRegionalSettings.vbs. Reads HKEY_USERS\.DEFAULT\Control Panel\International through the
    remote registry provider (StdRegProv) over CIM: WS-Management (WinRM) when it answers, otherwise DCOM, as the
    original did. Returns sCountry, as before, plus LocaleName (for example en-ZA), which current Windows versions
    always set. Values are empty when the computer cannot be queried or the value is not present.

    As with the original, this is the .DEFAULT profile (used before anyone logs on), not the logged-on user's
    setting.

.PARAMETER ComputerName
    One or more computers. Accepts pipeline input.

.EXAMPLE
    .\Get-RegionalSettings.ps1 -ComputerName CompanyServer01

.EXAMPLE
    Get-Content servers.txt | .\Get-RegionalSettings.ps1 | Export-Csv regional.csv -NoTypeInformation

.NOTES
    ITtelligence – https://ittelligence.blog/2009/07/23/getregionalsettings/
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory, ValueFromPipeline)][string[]]$ComputerName
)

begin {
    $HKEY_USERS = [uint32]2147483651
    $keyPath = '.DEFAULT\Control Panel\International'

    function New-RemoteCimSession {
        param([string]$Computer)
        foreach ($protocol in 'Wsman', 'Dcom') {
            try {
                $option = New-CimSessionOption -Protocol $protocol
                return New-CimSession -ComputerName $Computer -SessionOption $option -OperationTimeoutSec 15 -ErrorAction Stop
            }
            catch {
                Write-Verbose "$Computer`: $protocol failed: $($_.Exception.Message)"
            }
        }
        return $null
    }

    function Get-RegistryString {
        param($Session, [string]$ValueName)
        $arguments = @{ hDefKey = $HKEY_USERS; sSubKeyName = $keyPath; sValueName = $ValueName }
        $result = Invoke-CimMethod -CimSession $Session -Namespace root/default -ClassName StdRegProv -MethodName GetStringValue -Arguments $arguments
        # ReturnValue 0 means the value was found; anything else (for example 1, not found) gives an empty result.
        if ($result.ReturnValue -eq 0) { $result.sValue } else { '' }
    }
}

process {
    foreach ($computer in $ComputerName) {
        $country = ''
        $locale = ''
        $session = New-RemoteCimSession -Computer $computer
        if ($session) {
            try {
                $country = Get-RegistryString -Session $session -ValueName 'sCountry'
                $locale = Get-RegistryString -Session $session -ValueName 'LocaleName'
            }
            catch {
                Write-Verbose "$computer`: registry read failed: $($_.Exception.Message)"
            }
            finally {
                Remove-CimSession -CimSession $session
            }
        }
        [pscustomobject]@{
            ComputerName = $computer
            Country      = $country
            LocaleName   = $locale
        }
    }
}
