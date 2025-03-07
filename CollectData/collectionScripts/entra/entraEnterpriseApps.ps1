
<#
.SYNOPSIS
Function to gather information on existing enterprise apps.

.DESCRIPTION
Following Microsoft Graph scopes are required for running this script:
- Application.Read.All

This function will gather the following information on the enterprise apps that exist in the Entra ID tenant
- Display Name
- AppId
- Description
- Secrets and their expiry date
- Federated Credentials
- App Roles
- Creation Date
- Owners
- Sign-in Audience

.OUTPUTS
Outputs the results as a PSObject

.EXAMPLE
PS> Connect-MgGraph -scopes "Application.Read.All"
PS> $result = graphEnterpriseAppsFunction -options "secretExpiryWarningDays=30"

.NOTES
The session needs to be connected to Microsoft Graph before running this script.
#>

param(
    [string] $logFile,
    [switch] $writeToConsole
)
      
$context = Get-MgContext

if ($context) {
    Write-Log -message "Gathering info on enterprise apps." -logFile $logFile -writeToConsole:$writeToConsole
    $result = [System.Collections.ArrayList]::new()
    $requiredProperties = "AppId, DisplayName, Description, PasswordCredentials, FederatedIdentityCredentials, AppRoles, CreatedDateTime, Owners, SignInAudience"
    $applicationList = Get-MgApplication -ExpandProperty FederatedIdentityCredentials -Property $requiredProperties 
    $numberOfApps = $applicationList.Count
    $counter = 0
    $rolesQueryPath = $PSCommandPath.Replace("entraEnterpriseApps.ps1", "RBACforEntraId.kql")

    # Create a hash of appRoleIds and their display names
    $appRoleLookup = @{}

    foreach ($application in $applicationList) {
        $counter += 1
        Write-Log -message "$counter/$numberOfApps - Gathering info on $($application.DisplayName)" -logFile $logFile -writeToConsole:$writeToConsole
        # Create calculated members for application
        ## PassWordCredentials
        $passwordObject = @()
        foreach ($password in $application.PasswordCredentials) {
            $tempPasswordObject = @{}
            if ($password.DisplayName) {
                $tempPasswordObject["displayName"] = $password.DisplayName
            }
            else {
                $tempPasswordObject["displayName"] = ""
            }
            $tempPasswordObject["EndDate"] = $password.EndDateTime
            $passwordObject += $tempPasswordObject
        }


        ## FederatedCredentials
        $federatedCredentialsObject = @()
        foreach ($credential in $application.FederatedIdentityCredentials) {
            $tempFederatedCredentialObject = @{
                Name    = $credential.name
                Issuer  = $credential.Issuer
                Subject = $credential.Subject
            }
            $federatedCredentialsObject += $tempFederatedCredentialObject
        }

        ## AppRoles
        $appRolesList = @()
        foreach ($role in $application.AppRoles) {
            $appRolesList += $role.DisplayName
        }

        ## Get the service principal associated with to get the roles assigned to the application
        $servicePrincipalId = (Get-MgServicePrincipal -Filter "AppId eq `'$($application.AppId)`'").Id

        ## Group memberships (also returns Entra roles the managed identity has)
        if (-not [string]::IsNullOrEmpty($servicePrincipalId)) {
        $groups = Get-MgServicePrincipalMemberOf -ServicePrincipalId $servicePrincipalId
        }
        else {
            $groups = $null
        }

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
        $queryIds += "'$servicePrincipalId'"
        if (-not [string]::IsNullOrEmpty($servicePrincipalId)) {
            $lookupTable.Add($ServicePrincipalId, $application.DisplayName)
        }

        ### Role assignments (query for the roles assigned to the managed identity and to the groups it is a member of)
        if (-not [string]::IsNullOrEmpty($servicePrincipalId)) {
            $queryResults = ExecuteQuery -inputFile $rolesQueryPath -parameters "ID=$queryIds" -logFile $logFile -writeToConsole:$writeToConsole
            foreach ($role in $queryResults) {
                $tempRole = @{
                    roleName   = $role.roleName
                    scopeName  = $role.scopeName
                    scopeType  = $role.scopeType
                    assignedTo = $lookupTable[$role.principal]
                }
                $roleObjects += $tempRole
            }    
        }else {
            $roleObjects = $null
        }
       
        ## API Permissions
        if (-not [string]::IsNullOrEmpty($servicePrincipalId)) {
            $apiPermissionObjects = @()
            $apiPermissions = Get-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $servicePrincipalId
            foreach ($permission in $apiPermissions) {
                $key = "$($permission.ResourceId)-$($permission.AppRoleId)"
                if (-not ($appRoleLookup.ContainsKey($key))) {
                    Write-Warning "Looking up all appRoles for $($permission.ResourceDisplayName)"

                    $newAppRoles = (Get-MgServicePrincipal -ServicePrincipalId $permission.ResourceId).AppRoles
                    foreach ($appRole in $newAppRoles) {
                        $appKey = "$($permission.ResourceId)-$($appRole.Id)"
                        $appRoleLookup.Add($appKey, $appRole.Value)
                    }    
                }
                else {
                    Write-Host "Found in cache: $($permission.ResourceDisplayName)-$($appRoleLookup[$key])"
                }
        
                $apiPermissionObjects += @{
                    Resource = $permission.ResourceDisplayName
                    AppRole  = $appRoleLookup[$key]
                }
            }
        }else {
            $apiPermissionObjects = $null
        }

        # Create application custom object to add to array
        $tempObject = [PSCustomObject]@{
            Type                 = "entra/appregistrations"
            DisplayName          = $application.DisplayName
            AppId                = $application.AppId
            ObjectID             = $servicePrincipalId
            Description          = $application.Description
            PasswordCredentials  = $passwordObject
            FederatedCredentials = $federatedCredentialsObject
            AppRoles             = $appRolesList
            CreatedDateTime      = ($application.CreatedDateTime).ToString("dd MMM yyyy hh:mm")
            Owners               = $application.Owners
            SignInAudience       = $application.SignInAudience
            EntraGroups          = $entraGroups.AdditionalProperties.displayName
            EntraRoles           = $entraRoles.AdditionalProperties.displayName
            Roles                = $roleObjects
            apiPermissions       = $apiPermissionObjects
        }
        [void]$result.Add($tempObject)
    }
}
else {
    Write-Log -message "No connection to Microsoft Graph. Cannot execute the enterpriseApps inventory." -logFile $logFile -writeToConsole:$writeToConsole -severityLevel "WARNING"
    $result = $null
}
    
$result


