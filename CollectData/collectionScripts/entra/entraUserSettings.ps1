<#
.SYNOPSIS
Function to gather the Entra User Settings

.DESCRIPTION
Following Microsoft Graph scopes are required for running this script:
- Policy.Read.All


This function will gather all of the user settings configurations for the Entra ID tenant.

.OUTPUTS
Outputs the results as a PSObject

.EXAMPLE
PS> Connect-MgGraph -scopes "Policy.Read.All"
PS> $result = entraUserSettings.ps1

.NOTES
The session needs to be connected to Microsoft Graph before running this script.
#>

param (
    [string] $logFile,
    [switch] $writeToConsole
)
    
$context = Get-MgContext

if ($context) {
    Write-Log -message "Gathering Entra ID User Settings." -logFile $logFile -writeToConsole:$writeToConsole
    $result = [ordered]@{}
    $userSettings = Get-MgPolicyAuthorizationPolicy -property *
    $externalCollaborationSettings = Get-MgBetaPolicyExternalIdentityPolicy
    $selfServiceSignUpSetting = (Get-MgPolicyAuthenticationFlowPolicy).SelfServiceSignUp.IsEnabled

    $guestUserRole = (Get-MgRoleManagementDirectoryRoleDefinition -UnifiedRoleDefinitionId $userSettings.GuestUserRoleId).DisplayName

    $result.Add("User can register applications", $userSettings.DefaultUserRolePermissions.AllowedToCreateApps)
    $result.Add("Restrict non-admin users from creating tenants", !($userSettings.DefaultUserRolePermissions.AllowedToCreateTenants))
    $result.Add("Users can create security groups", $userSettings.DefaultUserRolePermissions.AllowedToCreateSecurityGroups)
    $result.Add("Guest invite restrictions", $userSettings.AllowInvitesFrom)
    $result.Add("Guest self-service sign up", $selfServiceSignUpSetting)
    $result.Add("Guest User Role", $guestUserRole)
    $result.Add("Allow external users to remove themselves", $externalCollaborationSettings.AllowExternalIdentitiesToLeave)
}
else {
    Write-Log -message "No connection to Microsoft Graph. Cannot execute the generalInfo inventory." -logFile $logFile -writeToConsole:$writeToConsole -severityLevel "WARNING"
    $result = $null
}
    
$result
