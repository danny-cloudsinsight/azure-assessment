
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
    # Replace the script path to point to the RBAC query file
    $rolesQueryPath = $PSCommandPath.Replace("entraManagedIdentities.ps1", "RBACforEntraId.kql")
    foreach ($identity in $managedIdentityList) {
        $counter += 1
        Write-Log -message "$counter/$numberOfIdentities - Gathering info on $($identity.DisplayName)" -logFile $logFile -writeToConsole:$writeToConsole
        # Create calculated members for managed identity
        ## Group memberships (also returns Entra roles the managed identity has)
        $groups = Get-MgServicePrincipalMemberOf -ServicePrincipalId $identity.Id

        ### Split the groups in Entra Roles and Entra Groups
        $entraRoles = $groups | Where-Object { $_.AdditionalProperties.'@odata.type' -eq "#microsoft.graph.directoryRole" }
        $entraGroups = $groups | Where-Object { $_.AdditionalProperties.'@odata.type' -eq "#microsoft.graph.group" }

        ### Create a query string for the role assignments and a hash table for lookups of name using the ID
        $queryIds = ""
        $lookupTable = @{}
        foreach ($group in $entraGroups) {
            $queryIds += "'$($group.id)',"
            $lookupTable.Add($group.id, $group.AdditionalProperties.displayName)
        }
        ## RBAC roles
        $roleObjects = @()

        ### Add the managed identity itself to the query and the lookup table
        $queryIds += "'$($identity.Id)'"
        $lookupTable.Add($identity.Id, $identity.DisplayName)


        ### Role assignments (query for the roles assigned to the managed identity and to the groups it is a member of)
        $queryResults = ExecuteQuery -inputFile $rolesQueryPath -parameters "ID=$queryIds" -logFile $logFile -writeToConsole:$writeToConsole
        foreach ($role in $queryResults) {
            $tempRole = @{
                roleName = $role.roleName
                scopeName = $role.scopeName
                scopeType = $role.scopeType
                assignedTo = $lookupTable[$role.principal]
            }
            $roleObjects += $tempRole
        }

        # Created Date
        [datetime]$createdDate = $identity.AdditionalProperties.createdDateTime
            
        # Create application custom object to add to array
        $tempObject = [PSCustomObject]@{
            DisplayName     = $identity.DisplayName
            AppId           = $identity.AppId
            ObjectId        = $identity.Id
            Description     = $identity.Description
            CreatedDateTime = $createdDate.ToString("dd MMM yyyy hh:mm")
            Owners          = $identity.Owners
            Resource        = $identity.AlternativeNames[1]
            EntraGroups     = $entraGroups.AdditionalProperties.displayName
            EntraRoles      = $entraRoles.AdditionalProperties.displayName
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


