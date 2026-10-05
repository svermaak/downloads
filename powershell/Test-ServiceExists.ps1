<#
.SYNOPSIS
    Reports whether a service exists on one or more remote computers.

.DESCRIPTION
    PowerShell port of DoesServiceExist.vbs. Each computer is pinged first, then queried over CIM: WS-Management
    (WinRM) when it answers, otherwise DCOM, which reaches the same machines the original script did.
    Status is Exists, DoesNotExist, Offline (no ping reply) or Unknown (replied, but could not be queried).

.PARAMETER ComputerName
    One or more computers. Accepts pipeline input, so a text file of names works: Get-Content hosts.txt | ...

.PARAMETER Name
    Service key name, such as WDSServer or Spooler, not the display name.

.EXAMPLE
    .\Test-ServiceExists.ps1 -ComputerName CompanyServer01 -Name WDSServer

.EXAMPLE
    Get-Content servers.txt | .\Test-ServiceExists.ps1 -Name Spooler | Where-Object Status -eq 'Exists'

.NOTES
    ITtelligence – https://ittelligence.blog/2009/09/29/doesserviceexist-detect-if-service-exist-on-remote-host/
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory, ValueFromPipeline)][string[]]$ComputerName,
    [Parameter(Mandatory)][string]$Name
)

begin {
    function New-RemoteCimSession {
        <# WinRM first; DCOM for older or locked-down hosts where WinRM is off. Returns $null when neither works. #>
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

    function Get-ServiceStatus {
        param([string]$Computer, [string]$ServiceName)
        if (-not (Test-Connection -ComputerName $Computer -Count 1 -Quiet)) { return 'Offline' }
        $session = New-RemoteCimSession -Computer $Computer
        if (-not $session) { return 'Unknown' }
        try {
            # Service names cannot contain quotes, but escape anyway so the filter cannot be broken out of.
            $filter = "Name='{0}'" -f ($ServiceName -replace "'", "''")
            $service = Get-CimInstance -CimSession $session -ClassName Win32_Service -Filter $filter -ErrorAction Stop
            if ($service) { 'Exists' } else { 'DoesNotExist' }
        }
        catch {
            Write-Verbose "$Computer`: query failed: $($_.Exception.Message)"
            'Unknown'
        }
        finally {
            Remove-CimSession -CimSession $session
        }
    }
}

process {
    foreach ($computer in $ComputerName) {
        [pscustomobject]@{
            ComputerName = $computer
            ServiceName  = $Name
            Status       = Get-ServiceStatus -Computer $computer -ServiceName $Name
        }
    }
}
