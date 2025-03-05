<#
.SYNOPSIS
Function to gather the Entra Identity Secure Score recommendations

.DESCRIPTION
Following Microsoft Graph scopes are required for running this script:
- DirectoryRecommendations.Read.All

This function will gather the Identity Secure Score recommendations for the Entra ID tenant.

Currently the PowerShell command used in this script only exists in the beta version of the Microsoft Graph API.

.OUTPUTS
Outputs the results as a PSObject

.EXAMPLE
PS> Connect-MgGraph -scopes "DirectoryRecommendations.Read.All"
PS> $result = entraBetaDirectoryRecommendations.ps1

.NOTES
The session needs to be connected to Microsoft Graph before running this script.
#>

param (
    [string] $logFile,
    [switch] $writeToConsole
)
    
$context = Get-MgContext

if ($context) {
    Write-Log -message "Gathering Entra ID Secure score recommendations." -logFile $logFile -writeToConsole:$writeToConsole
    $result = Get-MgBetaDirectoryRecommendation
}
else {
    Write-Log -message "No connection to Microsoft Graph. Cannot execute the generalInfo inventory." -logFile $logFile -writeToConsole:$writeToConsole -severityLevel "WARNING"
    $result = $null
}
    
$result
