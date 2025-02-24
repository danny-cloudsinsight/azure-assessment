<#
.SYNOPSIS
Function to gather all conditional access policies that exist in the tenant.

.DESCRIPTION
Following Microsoft Graph scopes are required for running this script:
- Policy.Read.All


This function will gather all of the user settings configurations for the Entra ID tenant.

.OUTPUTS
Outputs the results as a PSObject

.EXAMPLE
PS> Connect-MgGraph -scopes "Policy.Read.All"
PS> $result = entraConditionalAccessPolicies.ps1

.NOTES
The session needs to be connected to Microsoft Graph before running this script.
#>

param (
    [string] $logFile,
    [switch] $writeToConsole
)
    
$context = Get-MgContext

if ($context) {
    Write-Log -message "Gathering Entra ID Conditional Access policies." -logFile $logFile -writeToConsole:$writeToConsole
    $result = Get-MgIdentityConditionalAccessPolicy
}
else {
    Write-Log -message "No connection to Microsoft Graph. Cannot execute the generalInfo inventory." -logFile $logFile -writeToConsole:$writeToConsole -severityLevel "WARNING"
    $result = $null
}
    
$result
