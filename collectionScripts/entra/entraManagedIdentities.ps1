
<#
.SYNOPSIS
Function to gather information on existing enterprise apps.

.DESCRIPTION
Following Microsoft Graph scopes are required for running this script:
- Application.Read.All

This function will gather the following information on the managed identities that exist in the Entra ID tenant
- Display Name
- AppId
- Description
- Creation Date
- Owners
- Resource

.OUTPUTS
Outputs the results as a PSObject

.EXAMPLE
PS> Connect-MgGraph -scopes "Application.Read.All"
PS> $result = graphManagedIdentitiesFunction

.NOTES
The session needs to be connected to Microsoft Graph before running this script.
#>

param (
    [string] $logFile,
    [switch] $writeToConsole
)
    
$context = Get-MgContext

if ($context) {
    Write-Log -message "Gathering info on managed identities." -logFile $logFile -writeToConsole:$writeToConsole
    $result = [System.Collections.ArrayList]::new()
    $requiredProperties = "Id, DisplayName, AppId, Description, Owners, AlternativeNames, createdDateTime"
    $managedIdentityList = Get-MgServicePrincipal -Filter "ServicePrincipalType eq 'ManagedIdentity'" -Property $requiredProperties
    $numberOfIdentities = $managedIdentityList.Count
    $counter = 0
    $rolesQueryPath = $PSCommandPath.Replace("entraManagedIdentities.ps1", "RBACforEntraId.kql")
    foreach ($identity in $managedIdentityList) {
        $counter += 1
        Write-Log -message "$counter/$numberOfIdentities - Gathering info on $($identity.DisplayName)" -logFile $logFile -writeToConsole:$writeToConsole
        # Create calculated members for managed identity
        ## RBAC roles
        $queryResults = ExecuteQuery -inputFile $rolesQueryPath -parameters "ID=$($identity.Id)" -logFile $logFile -writeToConsole:$writeToConsole
        $roleObjects = @()
        foreach ($role in $queryResults) {
            $tempRole = @{
                roleName = $role.roleName
                scopeName = $role.scopeName
                scopeType = $role.scopeType
            }
            $roleObjects += $tempRole
        }

        # Created Date
        [datetime]$createdDate = $identity.AdditionalProperties.createdDateTime
            
        # Create application custom object to add to array
        $tempObject = [PSCustomObject]@{
            DisplayName     = $identity.DisplayName
            AppId           = $identity.AppId
            Description     = $identity.Description
            CreatedDateTime = $createdDate.ToString("dd MMM yyyy hh:mm")
            Owners          = $identity.Owners
            Resource        = $identity.AlternativeNames[1]
            Roles           = $roleObjects
        }
        [void]$result.Add($tempObject)
    }
}
else {
    Write-Log -message "No connection to Microsoft Graph. Cannot execute the managedIdentity inventory." -logFile $logFile -writeToConsole:$writeToConsole -severityLevel "WARNING"
    $result = $null
}
    
$result


