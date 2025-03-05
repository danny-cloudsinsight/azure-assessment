<#
.SYNOPSIS
Function to gather the Entra Id Authentication Methods settings

.DESCRIPTION
Following Microsoft Graph scopes are required for running this script:
- Policy.Read.All

This function will gather the Identity Secure Score recommendations for the Entra ID tenant.

Currently the beta version of the PowerShell commands for Microsoft Graph API are used as these contain the required data.

.OUTPUTS
Outputs the results as a PSObject

.EXAMPLE
PS> Connect-MgGraph -scopes "Policy.Read.All"
PS> $result = entraBetaAuthenticationMethods.ps1

.NOTES
The session needs to be connected to Microsoft Graph before running this script.
#>

param (
    [string] $logFile,
    [switch] $writeToConsole
)
    
$context = Get-MgContext

if ($context) {
    Write-Log -message "Gathering Entra ID Authentication methods." -logFile $logFile -writeToConsole:$writeToConsole
    $result = Get-MgBetaPolicyAuthenticationMethodPolicy
}
else {
    Write-Log -message "No connection to Microsoft Graph. Cannot execute the generalInfo inventory." -logFile $logFile -writeToConsole:$writeToConsole -severityLevel "WARNING"
    $result = $null
}
    
$result
