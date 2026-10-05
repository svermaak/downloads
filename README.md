# Downloads

Tools from [ITtelligence](https://ittelligence.blog). Each zip has a GitHub Release, which the matching blog post links to.

## PowerShell ports of the VBScript tools

Microsoft has deprecated VBScript, so the most useful VBScript tools have PowerShell versions in [`powershell/`](powershell/).
They run on Windows PowerShell 5.1 and PowerShell 7, return objects instead of text, and need no extra modules.

| Script | Replaces | What it does |
|---|---|---|
| `Get-ProxyAddresses.ps1` | `GetproxyAddresses.vbs` | Lists every AD user's proxyAddresses |
| `Test-ServiceExists.ps1` | `DoesServiceExist.vbs` | Checks whether a service exists on remote computers |
| `Get-RegionalSettings.ps1` | `GetRegionalSettings.vbs` | Reads the default profile's country and locale on remote computers |
| `Set-DevicePath.ps1` | `SetDevicePath.vbs` | Adds driver folders to the DevicePath registry value |

`pwsh -File powershell/tests/Run-Tests.ps1` parses every script and tests the logic that runs without Windows.
