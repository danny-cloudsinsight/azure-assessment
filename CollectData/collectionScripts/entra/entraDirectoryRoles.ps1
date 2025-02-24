<#
.SYNOPSIS
Function to gather information on Entra ID roles and their members

.DESCRIPTION
Following Microsoft Graph scopes are required for running this script:
- RoleManagement.Read.Directory

This function will gather the following information on all the Entra ID roles
- Display Name
- Members

.OUTPUTS
Outputs the results as a PSObject

.EXAMPLE
PS> Connect-MgGraph -scopes "RoleManagement.Read.Directory"
PS> $result = graphDirectoryRolesFunction

.NOTES
The session needs to be connected to Microsoft Graph before running this script.
#>

param (
    [string] $logFile,
    [switch] $writeToConsole
)
    
$context = Get-MgContext

if ($context) {
    Write-Log -message "Gathering info on Directory Roles." -logFile $logFile -writeToConsole:$writeToConsole
    $result = [System.Collections.ArrayList]::new()

    $directoryRoles = Get-MgDirectoryRole -ExpandProperty Members -Property DisplayName, Members

    $cachedUsers = @{}
    foreach ($role in $directoryRoles) {
        # Lookup Display names of members
        $members = @()
        $amount = 0
        foreach ($memberId in $role.Members.Id) {
            if ($cachedUsers.ContainsKey($memberId)) {
                $members += $cachedUsers[$memberId]
                $amount += 1
            }
            else {
                try {
                    $memberName = (Get-MgDirectoryObject -DirectoryObjectId $memberId -ErrorAction Stop | Select-Object -ExpandProperty AdditionalProperties).displayName
                    $members += $memberName
                    $amount += 1
                }
                catch {
                    Write-Log -message "Something went wrong when collecting the members of group $($role.DisplayName)" -logFile $logFile -writeToConsole:$writeToConsole -severityLevel "WARNING"
                }
                $cachedUsers.Add($memberId, $memberName)
            }
        }

            
        # Create application custom object to add to array
        $tempObject = [PSCustomObject]@{
            Type            = "entra/directoryroles"
            DisplayName     = $role.DisplayName
            NumberOfMembers = $amount
            Members         = $members
        }
        [void]$result.Add($tempObject)
    }
}
else {
    Write-Log -message "No connection to Microsoft Graph. Cannot execute the directoryRoles inventory." -logFile $logFile -writeToConsole:$writeToConsole -severityLevel "WARNING"
    $result = $null
}
    
$result
