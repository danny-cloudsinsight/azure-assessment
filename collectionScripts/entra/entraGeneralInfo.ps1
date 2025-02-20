<#
.SYNOPSIS
Function to gather general information regarding the Entra Tenant

.DESCRIPTION
Following Microsoft Graph scopes are required for running this script:
- Directory.Read.All

This function will gather the following information on Entra Id
- Tenant name
- Tenant ID
- domains

.OUTPUTS
Outputs the results as a PSObject

.EXAMPLE
PS> Connect-MgGraph -scopes "Directory.Read.All"
PS> $result = graphGeneralInfoFunction

.NOTES
The session needs to be connected to Microsoft Graph before running this script.
#>

param (
    [string] $logFile,
    [switch] $writeToConsole
)
    
$context = Get-MgContext

if ($context) {
    Write-Log -message "Gathering info on Entra Tenant." -logFile $logFile -writeToConsole:$writeToConsole
    $info = [ordered]@{}

    # Organization
    $organization = Get-MgOrganization -Property DisplayName, Id
    $info.Add("Name", $organization.DisplayName)
    $info.Add("Id", $organization.Id)

    # Domains
    $domains = Get-MgDomain -Property Id, IsDefault, IsVerified
    $defaultDomain = ""
    $verifiedDomains = ""
    $otherDomains = ""
    foreach ($domain in $domains) {
        if ($domain.IsDefault) {
            $defaultDomain = $domain.Id
        }
        elseif ($domain.IsVerified) {
            $verifiedDomains += "$($domain.Id), "
        }
        else {
            $otherDomains += "$($domain.Id), "
        }
    }
    if ($verifiedDomains -ne "") {
        $verifiedDomains = $verifiedDomains -replace ".{2}$"
    }
    if ($otherDomains -ne "") {
        $otherDomains = $otherDomains -replace ".{2}$"
    }
    $info.Add("Default domain", $defaultDomain)
    $info.Add("Verified domains", $verifiedDomains)
    $info.Add("Other domains", $otherDomains)
        
    #License
    $sku = ((Get-MgSubscribedSku).ServicePlans | Where-Object { $_.ServicePlanName -Like 'AAD_PREMIUM*' }).ServicePlanName
    if ($sku -contains "AAD_PREMIUM_P2") {
        $info.Add("License", "Microsoft Entra ID P2")
    }
    elseif ($sku -contains "AAD_PREMIUM") {
        $info.Add("License", "Microsoft Entra ID P1")
    }
    else {
        $info.Add("License", "Unknown")
    }
}
else {
    Write-Log -message "No connection to Microsoft Graph. Cannot execute the generalInfo inventory." -logFile $logFile -writeToConsole:$writeToConsole -severityLevel "WARNING"
    $info = $null
}
    
$info
