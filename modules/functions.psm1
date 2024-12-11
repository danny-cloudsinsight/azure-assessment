<#
.SYNOPSIS
Executes KQL query provided via file

.DESCRIPTION
Executes a KQl query that is provided in an inputFile using the Search-AzGraph powershell command.
This command is included in the Az.ResourceGraph module, which needs to be present.

The script will issue a warning if the file does not exist or if the KQL query cannot get executed (incorrect query or other error)
The script will issue an error when something else goes wrong with the file

.PARAMETER inputFile
Location of the file containing the valid KQL to execute

.PARAMETER parameters
Parameters to use for the query. Should be provided as a string containing parameter=value pairs separated by ;.
In the kql file these parameters should be put with the following syntax %PARAMETER%

.OUTPUTS
Outputs the result of the KQL query as a PSObject

.EXAMPLE
PS> echo "resources | order by name asc " > "./queryFile.kql"
PS> ExecuteQuery -inputFile "./queryFile.kql"

.NOTES
This script can return max. 1000 items 
#>
function ExecuteQuery {
    param
    (
        [Parameter(Mandatory = $true, Position = 0)]
        [string] $inputFile,
        [Parameter(Mandatory = $false, Position = 1)]
        [string] $parameters,
        [string] $logFile,
        [switch] $writeToConsole
    )

    try {
        $queryContent = get-content -Path $inputFile
    
    }
    catch [System.Management.Automation.ItemNotFoundException] {
        Write-Log -message "File $inputFile does not exist. Skipping!" -logFile $logFile -writeToConsole:$writeToConsole -severityLevel "WARNING"
        continue
    }
    catch {
        Write-Log -message "An uncatched error has occurred. Please investigate" -logFile $logFile -writeToConsole:$writeToConsole -severityLevel "WARNING"
        Write-Log -message "Error: $_" -logFile $logFile -writeToConsole:$writeToConsole -severityLevel "ERROR"
        exit
    }

    # Replace parameters with their value in the query
    $parameterValues = ConvertFrom-StringData -StringData ($parameters.Replace(";", "`n"))

    $parameterValues.GetEnumerator() | ForEach-Object {
        $queryContent = $queryContent.Replace("%$($_.Key.ToUpper())%", $_.Value)
    }

    try {
        $results = Search-AzGraph -Query "$queryContent" -UseTenantScope -First 1000
    }
    catch {
        Write-Log -message "Something went wrong when executing the KQL query in the file $inputFile. Check below message for more information" -logFile $logFile -writeToConsole:$writeToConsole -severityLevel "WARNING"
        Write-Log -message "Error: $_" -logFile $logFile -writeToConsole:$writeToConsole -severityLevel "ERROR"
        continue
    }

    return $results
}

<#
.SYNOPSIS
Executes KQL query provided via file (using REST API)

.DESCRIPTION
Executes a KQl query that is provided in an inputFile using the Invoke-RestMethod powershell command.
This function can for instance be used instead of the ExecuteQuery function when the Az.ResourceGraph module is not available.
The function required the Az.Accounts module to generate the authentication token.

The script will issue a warning if the file does not exist or if the KQL query cannot get executed (incorrect query or other error)
The script will issue an error when something else goes wrong with the file

.PARAMETER inputFile
Location of the file containing the valid KQL to execute

.OUTPUTS
Outputs the result of the KQL query as a PSObject

.EXAMPLE
PS> echo "resources | order by name asc " > "./queryFile.kql"
PS> ExecuteQueryRest -inputFile "./queryFile.kql"

.NOTES
This script can return max. 1000 items 
#>
function ExecuteQueryRest {
    param
    (
        [Parameter(Mandatory = $true, Position = 0)]
        [string] $inputFile,
        [string] $logFile,
        [switch] $writeToConsole
    )

    # Execute query
    try {
        $queryContent = get-content -Path $inputFile
    
    }
    catch [System.Management.Automation.ItemNotFoundException] {
        Write-Log -message "File $inputFile does not exist. Skipping!" -logFile $logFile -writeToConsole:$writeToConsole -severityLevel "WARNING"
        continue
    }
    catch {
        Write-Log -message "An uncatched error has occurred. Please investigate" -logFile $logFile -writeToConsole:$writeToConsole -severityLevel "WARNING"
        Write-Log -message "Error: $_" -logFile $logFile -writeToConsole:$writeToConsole -severityLevel "ERROR"
        exit
    }

    $uri = "https://management.azure.com/providers/Microsoft.ResourceGraph/resources?api-version=2022-10-01"
    $token = (Get-AzAccessToken).Token
    $headers = @{
        "Content-Type"  = "application/json"
        "Authorization" = "Bearer $token"
    }
    $escapedQueryContent = $queryContent -replace '"', '\"'
    $body = "{`"query`": `"$escapedQueryContent`"}"

    try {
        $results = Invoke-RestMethod -Uri $uri -Method Post -Headers $headers -Body $body
    }
    catch {
        Write-Log -message "Something went wrong when executing the KQL query in the file $inputFile. Check below message for more information" -logFile $logFile -writeToConsole:$writeToConsole -severityLevel "WARNING"
        Write-Log -message "Error: $_" -logFile $logFile -writeToConsole:$writeToConsole -severityLevel "ERROR"
        continue
    }


    ## Write Results
    try {
        $results.data | Export-Csv -Path $outputFile -Delimiter ";" -Encoding utf8
    }
    catch {
        Write-Log -message "Could not write output. Make sure the path for the output file ($outputFile) exists." -logFile $logFile -writeToConsole:$writeToConsole -severityLevel "WARNING"
        continue
    }
}

<#
.SYNOPSIS
Creates a CSV file from a Powershell object

.DESCRIPTION
Creates a CSV file using a Powershell object (PSObject) as first parameter and location of the CSV file as the second parameter

.PARAMETER object
Contains the PSObject to write to CSV

.PARAMETER outputFile
Location of the outputFile

.EXAMPLE
PS> $processes = Get-Process
PS> OutputCSV -object $processes -outputFile "./processes.csv"

.NOTES
If you want to create the CSV file in a different folder, this folder needs to exist.
#>
function OutputCSV {
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [pscustomobject] $object,
        [Parameter(Mandatory = $true, Position = 1)]
        [string] $outputFile,
        [string] $logFile,
        [switch] $writeToConsole
    )

    try {
        $object | Export-Csv -Path $outputFile -Delimiter ";" -Encoding utf8
    }
    catch {
        Write-Log -message "Could not write output. Make sure the path for the output file ($outputFile) exists." -logFile $logFile -writeToConsole:$writeToConsole -severityLevel "WARNING"
        continue
    }
}

<#
.SYNOPSIS
Turns a CSV file into a Markdown table

.DESCRIPTION
Turns a CSV file into a Markdown (.md) file containing a table with all the columns and rows from the csv file.
First line of the csv file will be used as header for the different table columns

.PARAMETER inputCSV
Path to the input CSV file

.PARAMETER outputFile
Optional location for the markdown file. By default will be in same location as CSV file, but with .md extension

.PARAMETER delimiter
Optional delimiter used in csv file. By default ';' will be used as delimiter

.EXAMPLE
PS> $processes = Get-Process
PS> OutputCSV -object $processes -outputFile "./processes.csv"
PS> ConvertCSVtoMD -inputCSV "./processes.csv" -outputFile "./processesTable.md" -delimiter ";"

.NOTES
- If you want to output the markdown file to a different folder, this folder needs to exist.
- New lines in cells in csv should be indicated using "<br>" and not with the newline character.
#>
function ConvertCSVtoMD {
    param
    (
        [Parameter(Mandatory = $true, Position = 0)]
        [string] $inputCSV,
        [Parameter(Mandatory = $false, Position = 1)]
        [string] $outputFile,
        [Parameter(Mandatory = $false, Position = 2)]
        [string] $delimiter = ";"
    )
    
    if (!$PSBoundParameters.ContainsKey('outputFile')) {
        $outputFile = $inputCSV.Substring(0, $inputCSV.LastIndexOf(".")) + ".md"
    }

    $mdData = ""

    $rawData = Get-Content -Path $inputCSV

    #Read the first line to create the headers
    $rawHeaders = $rawData | Select-Object -First 1
    $numberOfHeaders = ($rawHeaders.split($delimiter)).count
    $mdData = "|$($rawHeaders.Replace($delimiter,'|'))|`n"

    foreach ($i in 1..$numberOfHeaders) {
        $mdData += "|---"
    }
    $mdData += "|`n"

    #Remove the first line
    $rawData = $rawData | Select-Object -Skip 1

    foreach ($line in $rawData) {
        $mdData += "|$($line.Replace($delimiter,'|'))|`n"
    }

    $mdData | Out-File -Append $outPutFile

}

<#
.SYNOPSIS
Function that triggers the correct MS Graph function

.DESCRIPTION
Triggers the correct MS Graph function for the component that is provided as the first parameter.
The following permission is sufficient to run all current Graph functions:
- Directory.Read.All
 
.PARAMETER component
Component to execute the MS Graph function for

.PARAMETER options
Custom options for the MS Graph function

.OUTPUTS
Outputs the result of the MS Graph function as a PSObject

.EXAMPLE
PS> $result = ExecuteMsGraphScript -component "enterpriseApps"

.NOTES
If no MS Graph function exists for a specific resource type this function returns a warning
#>
function ExecuteMsGraphFunction {
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [string] $component,
        [Parameter(Mandatory = $false, Position = 1)]
        [string] $options = "",
        [string] $logFile,
        [switch] $writeToConsole
    )

    $result = $null

    switch ($component) {
        "enterpriseApps" {
            $result = graphEnterpriseAppsFunction -options "$options" -logFile $logFile -writeToConsole:$writeToConsole
        }
        "managedIdentities" {
            $result = graphManagedIdentitiesFunction -logFile $logFile -writeToConsole:$writeToConsole
        }
        "directoryRoles" {
            $result = graphDirectoryRolesFunction -logFile $logFile -writeToConsole:$writeToConsole
        }
        "generalInfo" {
            $result = graphGeneralInfoFunction -logFile $logFile -writeToConsole:$writeToConsole
        }
        Default {
            Write-Log -message "No MS Graph function defined for component $component" -logFile $logFile -writeToConsole:$writeToConsole -severityLevel "WARNING"
        }
    }

    $result
}

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
- Expired and soon expiring secrets
- Federated Credentials
- App Roles
- Creation Date
- Owners
- Sign-in Audience

.PARAMETER options
Custom options for the enterprise apps function. Should be provided as a string containing key=value pairs separated by ;.
Possible key values:
- secretExpiryWarningDays: number of days before end date of secret that it is put in expiring state. Default is 30 days.

.OUTPUTS
Outputs the results as a PSObject

.EXAMPLE
PS> Connect-MgGraph -scopes "Application.Read.All"
PS> $result = graphEnterpriseAppsFunction -options "secretExpiryWarningDays=30"

.NOTES
The session needs to be connected to Microsoft Graph before running this script.
#>
function graphEnterpriseAppsFunction {
    param(
        [Parameter(Mandatory = $false, Position = 0)]
        [string] $options = "",
        [string] $logFile,
        [switch] $writeToConsole
    )
    
    $optionValues = ConvertFrom-StringData -StringData ($options.Replace(";", "`n"))


    if ($optionValues.ContainsKey("secretExpiryWarningDays")) {
        $secretExpiryWarningDays = $optionValues.secretExpiryWarningDays
        Write-Log -message "Custom value for secretExpiryWarningDays: $secretExpiryWarningDays" -logFile $logFile -writeToConsole:$writeToConsole
    }
    else {
        $secretExpiryWarningDays = 30
    }
    
    $context = Get-MgContext
    $currentDate = Get-Date
    $expiryWarningDate = (Get-Date).AddDays($secretExpiryWarningDays)

    if ($context) {
        Write-Log -message "Gathering info on enterprise apps." -logFile $logFile -writeToConsole:$writeToConsole
        $result = [System.Collections.ArrayList]::new()
        $requiredProperties = "AppId, DisplayName, Description, PasswordCredentials, FederatedIdentityCredentials, AppRoles, CreatedDateTime, Owners, SignInAudience"
        $applicationList = Get-MgApplication -ExpandProperty FederatedIdentityCredentials -Property $requiredProperties
        foreach ($application in $applicationList) {
            # Create calculated members for application
            ## PassWordCredentials
            $tempPasswordString = ""
            $expiryStatus = "None"
            foreach ($password in $application.PasswordCredentials) {
                if ($password.DisplayName) {
                    $tempPasswordString += $password.DisplayName
                }
                else {
                    $tempPasswordString += "<no DisplayName>"
                }
                $tempPasswordString += " ($($password.EndDateTime.ToString("dd MMM yyyy hh:mm")))"
                # Calculate correct status in case of multiple secrets
                if ($password.EndDateTime -gt $expiryWarningDate) {
                    $expiryStatus = "OK"
                }
                elseif ($password.EndDateTime -gt $currentDate) {
                    $tempPasswordString += " (EXPIRING)"
                    if ($expiryStatus -ne "OK") { 
                        $expiryStatus = "Expiring"
                    }
                }
                else {
                    $tempPasswordString += " (EXPIRED)"
                    if ($expiryStatus -eq "None") {
                        $expiryStatus = "Expired"
                    }
                }
                $tempPasswordString += " | "
            }
            if ($tempPasswordString -ne "") {
                $tempPasswordString = $tempPasswordString -replace ".{3}$"
            }

            ## FederatedCredentials
            $tempFederatedCredentials = ""
            foreach ($credential in $application.FederatedIdentityCredentials) {
                $tempFederatedCredentials += "Name: $($credential.name), "
                $tempFederatedCredentials += "Issuer: $($credential.Issuer), "
                $tempFederatedCredentials += "Subject: $($credential.Subject) | "
            }
            if ($tempFederatedCredentials -ne "") {
                $tempFederatedCredentials = $tempFederatedCredentials -replace ".{3}$"
            }

            ## AppRoles
            $tempAppRoles = ""
            foreach ($role in $application.AppRoles) {
                $tempAppRoles += "$($role.DisplayName) | "
            }
            if ($tempAppRoles -ne "") {
                $tempAppRoles = $tempAppRoles -replace ".{3}$"
            }

            ## RBAC roles
            $servicePrincipalId = (Get-MgServicePrincipal -Filter "AppId eq `'$($application.AppId)`'").Id
            $queryResults = ExecuteQuery -inputFile "queries/entra/RBACforEntraId.kql" -parameters "ID=$servicePrincipalId" -logFile $logFile -writeToConsole:$writeToConsole
            $roles = ""
            foreach ($role in $queryResults) {
                $roles += "role: $($role.roleName), scope: $($role.scopeName), type: $($role.scopeType) | "
            }
            if ($roles -ne "") {
                $roles = $roles -replace ".{3}$"
            }
  


            # Create application custom object to add to array
            $tempObject = [PSCustomObject]@{
                DisplayName          = $application.DisplayName
                AppId                = $application.AppId
                Description          = $application.Description
                PasswordCredentials  = $tempPasswordString
                ExpiryStatus         = $expiryStatus
                FederatedCredentials = $tempFederatedCredentials
                AppRoles             = $tempAppRoles
                CreatedDateTime      = ($application.CreatedDateTime).ToString("dd MMM yyyy hh:mm")
                Owners               = $application.Owners
                SignInAudience       = $application.SignInAudience
                Roles                = $roles
            }
            [void]$result.Add($tempObject)
        }
    }
    else {
        Write-Log -message "No connection to Microsoft Graph. Cannot execute the enterpriseApps inventory." -logFile $logFile -writeToConsole:$writeToConsole -severityLevel "WARNING"
        $result = $null
    }
    
    return $result
}

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
function graphManagedIdentitiesFunction {
    param (
        [string] $logFile,
        [switch] $writeToConsole
    )
    
    $context = Get-MgContext

    if ($context) {
        Write-Log -message "Gathering info on managed identities." -logFile $logFile -writeToConsole:$writeToConsole
        $result = [System.Collections.ArrayList]::new()
        $requiredProperties = "Id, DisplayName, AppId, Description, Owners, AlternativeNames, createdDateTime"
        $managedIdentityList = Get-MgServicePrincipal -filter "ServicePrincipalType eq 'ManagedIdentity'" -Property $requiredProperties
        foreach ($identity in $managedIdentityList) {
            # Create calculated members for managed identity
            ## RBAC roles
            $queryResults = ExecuteQuery -inputFile "queries/entra/RBACforEntraId.kql" -parameters "ID=$($identity.Id)" -logFile $logFile -writeToConsole:$writeToConsole
            $roles = ""
            foreach ($role in $queryResults) {
                $roles += "role: $($role.roleName), scope: $($role.scopeName), type: $($role.scopeType) | "
            }
            if ($roles -ne "") {
                $roles = $roles -replace ".{3}$"
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
                Roles           = $roles
            }
            [void]$result.Add($tempObject)
        }
    }
    else {
        Write-Log -message "No connection to Microsoft Graph. Cannot execute the managedIdentity inventory." -logFile $logFile -writeToConsole:$writeToConsole -severityLevel "WARNING"
        $result = $null
    }
    
    $result
}

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
function graphDirectoryRolesFunction {
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
            $members = ""
            $amount = 0
            foreach ($memberId in $role.Members.Id) {
                if ($cachedUsers.ContainsKey($memberId)) {
                    $members += "$($cachedUsers[$memberId]), "
                    $amount += 1
                }
                else {
                    try {
                        $memberName = (Get-MgDirectoryObject -DirectoryObjectId $memberId -ErrorAction Stop | Select-Object -ExpandProperty AdditionalProperties).displayName
                        $members += "$memberName, "
                        $amount += 1
                    }
                    catch {
                        Write-Log -message "Something went wrong when collecting the members of group $($role.DisplayName)" -logFile $logFile -writeToConsole:$writeToConsole -severityLevel "WARNING"
                    }
                    $cachedUsers.Add($memberId, $memberName)
                }
            }
            if ($members -ne "") {
                $members = $members -replace ".{2}$"
            }

            
            # Create application custom object to add to array
            $tempObject = [PSCustomObject]@{
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
}

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
function graphGeneralInfoFunction {
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

        $result = foreach ($key in $info.Keys) {
            [PSCustomObject]@{
                Item  = $key
                Value = $info[$key]
            }
        }
    }
    else {
        Write-Log -message "No connection to Microsoft Graph. Cannot execute the generalInfo inventory." -logFile $logFile -writeToConsole:$writeToConsole -severityLevel "WARNING"
        $result = $null
    }
    
    $result
}

<#
.SYNOPSIS
    Writes log messages to a specified file with a severity level and optionally to the console.

.DESCRIPTION
    The `Write-Log` function logs a message to a specified log file with a timestamp and a severity level.
    Optionally, the function can also output the log message to the console, color-coded based on the severity level.

.PARAMETER message
    The message to log. This is the content that will be written to the log file and optionally to the console.

.PARAMETER logFile
    The full path to the log file where the message will be written. If the file does not exist, it will be created.

.PARAMETER severityLevel
    The severity level of the log message. Valid values are "INFO", "WARNING", and "ERROR". Default is "INFO".

.PARAMETER writeToConsole
    If specified, the log message will also be written to the console output (in addition to the log file).

.EXAMPLE
    Write-Log -message "This is a test message" -logFile "C:\Logs\script.log" -severityLevel "INFO"
    
    This will write the message "This is a test message" to the log file at "C:\Logs\script.log" with an INFO severity level.

.EXAMPLE
    Write-Log -message "This is a warning message" -logFile "C:\Logs\script.log" -severityLevel "WARNING" -writeToConsole
    
    This will write the message "This is a warning message" to the log file at "C:\Logs\script.log" and display it in the console with a yellow color.
#>
function Write-Log {
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$message,

        [Parameter(Mandatory = $true, Position = 1)]
        [string]$logFile,

        [Parameter(Mandatory = $false)]
        [ValidateSet("INFO", "WARNING", "ERROR")]
        [string]$severityLevel = "INFO",

        [switch]$writeToConsole
    )

    # Get the current timestamp
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    # Format the log entry
    $logEntry = "$timestamp - [$severityLevel] - $message"

    # Write the log entry to the file 
    try {
        Add-Content -Path $logFile -Value $logEntry -ErrorAction Stop
    }
    catch {
        Write-Error "Failed to write to log file: $_"
    }

    # Optionally write the log entry to the console
    if ($writeToConsole) {
        switch ($severityLevel) {
            INFO { $textColor = "White" }
            WARNING { $textColor = "Yellow" }
            ERROR { $textColor = "Red" }
            Default { $textColor = "White" }
        }
        Write-Host $logEntry -ForegroundColor $textColor
    }
}
