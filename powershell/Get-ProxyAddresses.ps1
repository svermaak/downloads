<#
.SYNOPSIS
    Lists every Active Directory user's proxyAddresses, one object per address.

.DESCRIPTION
    PowerShell port of GetproxyAddresses.vbs. Queries the current domain (or -SearchBase) through ADSI, so it needs
    no RSAT or ActiveDirectory module: any domain-joined computer and any domain user will do. Users without
    proxyAddresses are left out, as before.

.PARAMETER SearchBase
    Distinguished name to search under. Defaults to the whole current domain.

.EXAMPLE
    .\Get-ProxyAddresses.ps1 | Export-Csv proxyAddresses.csv -NoTypeInformation

.EXAMPLE
    .\Get-ProxyAddresses.ps1 | Where-Object IsPrimary | Select-Object SamAccountName, Address

.NOTES
    ITtelligence – https://ittelligence.blog/2009/10/12/enumerate-all-active-directory-users-proxyaddresses/
#>
[CmdletBinding()]
param(
    [string]$SearchBase
)

function ConvertTo-ProxyAddressRecord {
    <# Splits "SMTP:john.smith@contoso.com" into its type and address. An upper-case type prefix is Exchange's mark
       for the primary address of that type (SMTP: primary, smtp: secondary). #>
    param(
        [Parameter(Mandatory)][string]$SamAccountName,
        [Parameter(Mandatory)][string]$ProxyAddress
    )
    $separator = $ProxyAddress.IndexOf(':')
    $type = if ($separator -gt 0) { $ProxyAddress.Substring(0, $separator) } else { '' }
    [pscustomobject]@{
        SamAccountName = $SamAccountName
        Type           = $type.ToUpperInvariant()
        Address        = if ($separator -gt 0) { $ProxyAddress.Substring($separator + 1) } else { $ProxyAddress }
        IsPrimary      = $type.Length -gt 0 -and $type -ceq $type.ToUpperInvariant()
        ProxyAddress   = $ProxyAddress
    }
}

function Get-ProxyAddresses {
    param([string]$SearchBase)
    $root = if ($SearchBase) { [adsi]"LDAP://$SearchBase" } else { [adsi]'' }
    $searcher = [adsisearcher]::new($root, '(&(objectCategory=person)(objectClass=user)(proxyAddresses=*))', @('sAMAccountName', 'proxyAddresses'))
    $searcher.PageSize = 1000
    $results = $null
    try {
        $results = $searcher.FindAll()
        foreach ($result in $results) {
            $sam = [string]$result.Properties['samaccountname'][0]
            foreach ($address in $result.Properties['proxyaddresses']) {
                ConvertTo-ProxyAddressRecord -SamAccountName $sam -ProxyAddress ([string]$address)
            }
        }
    }
    finally {
        if ($results) { $results.Dispose() }
        $searcher.Dispose()
    }
}

# Dot-sourcing (as the tests do) only loads the functions.
if ($MyInvocation.InvocationName -ne '.') {
    Get-ProxyAddresses -SearchBase $SearchBase
}
