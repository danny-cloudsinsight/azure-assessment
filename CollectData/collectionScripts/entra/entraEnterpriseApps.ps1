
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
                Name = $credential.name
                Issuer = $credential.Issuer
                Subject = $credential.Subject
            }
            $federatedCredentialsObject += $tempFederatedCredentialObject
        }

        ## AppRoles
        $appRolesList = @()
        foreach ($role in $application.AppRoles) {
            $appRolesList += $role.DisplayName
        }

        ## RBAC roles
        $servicePrincipalId = (Get-MgServicePrincipal -Filter "AppId eq `'$($application.AppId)`'").Id
        $queryResults = ExecuteQuery -inputFile $rolesQueryPath -parameters "ID=$servicePrincipalId" -logFile $logFile -writeToConsole:$writeToConsole
        $rolesObject = @()
        foreach ($role in $queryResults) {
            $tempRoleObject = @{
                roleName = $role.roleName
                scopeName = $role.scopeName
                scopeType = $role.scopeType
            }
            $rolesObject += $tempRoleObject
        }


        # Create application custom object to add to array
        $tempObject = [PSCustomObject]@{
            Type                 = "entra/appregistrations"
            DisplayName          = $application.DisplayName
            AppId                = $application.AppId
            Description          = $application.Description
            PasswordCredentials  = $passwordObject
            FederatedCredentials = $federatedCredentialsObject
            AppRoles             = $appRolesList
            CreatedDateTime      = ($application.CreatedDateTime).ToString("dd MMM yyyy hh:mm")
            Owners               = $application.Owners
            SignInAudience       = $application.SignInAudience
            Roles                = $rolesObject
        }
        [void]$result.Add($tempObject)
    }
}
else {
    Write-Log -message "No connection to Microsoft Graph. Cannot execute the enterpriseApps inventory." -logFile $logFile -writeToConsole:$writeToConsole -severityLevel "WARNING"
    $result = $null
}
    
$result


