param (
    [string] $configFile = "./configCollection.json"
)

$ErrorActionPreference = 'Stop'

Import-Module ./modules/functions.psm1 -Force
# Import-Module ./modules/customScripts.psm1 -Force

#region Prepare

# Ensure the configuration file exists
if (-not (Test-Path $configFile)) {
    throw "Configuration file not found: $configFile"
}

try {
    $config = Get-Content -Raw -Path $configFile | ConvertFrom-Json
}
catch {
    throw "Failed to read or parse input file: $_"
}

# Initialize
$writeToConsole = $config.general.writeLogstoConsole
$logFile = if ($IsWindows) { $PSCommandPath.Split("\")[-1].Replace(".ps1", ".log") } else { $PSCommandPath.Split("/")[-1].Replace(".ps1", ".log") }
$logFile = "$($config.general.logFolder)/$logFile"

# Ensure the directory for the log file exists
if (-not (Test-Path -Path $config.general.logFolder)) {
    Write-Log "Log directory not found: $($config.general.logFolder). Creating..." -logFile $logFile -writeToConsole:$writeToConsole -severityLevel "WARNING"
    New-Item -Path $config.general.logFolder -ItemType Directory
}

# Ensure the Azure query folder exists
if (-not (Test-Path $config.azure.queryFolder)) {
    throw "Query folder not found: $($config.azure.queryFolder)"
}

# Ensure the Entra scripts folder exists
if (-not (Test-Path $config.entra.scriptFolder)) {
    throw "Query folder not found: $($config.entra.scriptFolder)"
}

# Ensure the raw output folder exists
if (-not (Test-Path $config.general.rawOutputFolder)) {
    Write-Log "Raw output folder not found: $($config.general.rawOutputFolder). Creating..." -logFile $logFile -writeToConsole:$writeToConsole -severityLevel "WARNING"
    New-Item -Path $config.general.rawOutputFolder -ItemType Directory
}

Write-Log -message "Started Collect-Data script" -logFile $logFile -writeToConsole:$writeToConsole
Write-Log -message "Successfully read configuration file: $configFile" -logFile $logFile -writeToConsole:$writeToConsole

Write-Log -message "Collecting Azure resources base information." -logFile $logFile -writeToConsole:$writeToConsole

#endregion prepare

#region Azure

if ($config.azure.enabled) {
    Write-Log -message "Validating required modules for Azure resources inventory." -logFile $logFile -writeToConsole:$writeToConsole

    foreach ($module in $config.azure.requiredModules) {
        $installedModule = Get-Module -ListAvailable -Name $module
        if (-not $installedModule) {
            Write-Log "Module $module not found. Installing in /modules folder" -logFile $logFile -writeToConsole:$writeToConsole -severityLevel "WARNING"
            Save-Module -Name $module -Path ./modules -Force
            Import-Module ./modules/$module -Force
        }
        else {
            Write-Log "Module $($installedModule[0].Name) (version: $($installedModule[0].Version)) found." -logFile $logFile -writeToConsole:$writeToConsole
        }
    }

    # Connect to Azure
    $context = Get-AzContext
    if ($context) {
        Write-Log -message "Connected to Azure" -logFile $logFile -writeToConsole:$writeToConsole
    }
    else {
        Write-Log -message "No connection to Azure. Running Connect-AzAccount" -logFile $logFile -writeToConsole:$writeToConsole -severityLevel "WARNING"
        Write-Log -message "Please logon with your administrative account and select a random subscription (Inventory will always check all resources in the tenant you have access to)" -logFile $logFile -writeToConsole:$writeToConsole -severityLevel "INFO"
        Connect-AzAccount
    }

    # Get all queries in the query folder (and its subfolders)
    $queries = Get-ChildItem -Path $config.azure.queryFolder -Filter "*.kql" -Recurse

    # Execute each query
    foreach ($query in $queries) {
        Write-Log -message "Executing query $($query.BaseName)" -logFile $logFile -writeToConsole:$writeToConsole
    
        $results = ExecuteQuery -inputFile $query.FullName -logFile $logFile -writeToConsole:$writeToConsole

        if ($results) {
            OutputJson -object $results -outputFile "$($config.general.rawOutputFolder)/$($query.BaseName).json" -logFile $logFile -writeToConsole:$writeToConsole
        }
        else {
            Write-Log "No results for $($query.BaseName)" -logFile $logFile -writeToConsole:$writeToConsole -severityLevel "WARNING"
        }
        Clear-Variable results
    }

    # Get all subresources for Service Bus and API Management
    $subResourceScripts = Get-ChildItem -Path $config.azure.queryFolder -Filter "*.ps1" -Recurse
    foreach ($script in $subResourceScripts) {
        Write-Log -message "Executing subresource script $($script.BaseName)" -logFile $logFile -writeToConsole:$writeToConsole

        $results = & $script.FullName -logFile $logFile -writeToConsole:$writeToConsole

        if($results) {
            OutputJson -object $results -outputFile "$($config.general.rawOutputFolder)/$($script.BaseName).json" -logFile $logFile -writeToConsole:$writeToConsole
        }
        else {
            Write-Log "No results for $($script.BaseName)" -logFile $logFile -writeToConsole:$writeToConsole -severityLevel "WARNING"
        }
        Clear-Variable results
    }

}
else {
    Write-Log -message "Azure resources inventory is not enabled, no Azure resources inventory will be collected" -logFile $logFile -writeToConsole:$writeToConsole -severityLevel "WARNING"
}

#endregion Azure

#region Entra ID

Write-Log -message "Connecting to Microsoft Graph (Optional)" -logFile $logFile -writeToConsole:$writeToConsole
if ($config.entra.enabled) {
    Write-Log -message "Validating required modules for Microsoft Graph." -logFile $logFile -writeToConsole:$writeToConsole

    foreach ($module in $config.entra.requiredModules) {
        $installedModule = Get-Module -ListAvailable -Name $module
        if (-not $installedModule) {
            Write-Log "Module $module not found. Installing in /modules folder" -logFile $logFile -writeToConsole:$writeToConsole -severityLevel "WARNING"
            Save-Module -Name $module -Path ./modules -Force
            Import-Module ./modules/$module -Force
        }
        else {
            Write-Log "Module $($installedModule[0].Name) (version: $($installedModule[0].Version)) found." -logFile $logFile -writeToConsole:$writeToConsole
        }
    }

    # Get all Entra ID scripts in the script folder
    $scripts = Get-ChildItem -Path $config.entra.scriptFolder -Filter "*.ps1"

    # Run each script
    Connect-MgGraph -Scopes $config.entra.scopes -NoWelcome
    foreach ($script in $scripts) {
        $results = & $script.FullName -logFile $logFile -writeToConsole:$writeToConsole
       
        if ($results) {
            OutputJson -object $results -outputFile "$($config.general.rawOutputFolder)/$($script.BaseName).json"
        }
        else {
            Write-Log -message "No results for $($script.BaseName)" -logFile $logFile -writeToConsole:$writeToConsole -severityLevel "WARNING"
        }
    }


    # Get translation of Entra ID Object IDs to display names
    if ($config.entra.translateObjectIds) {
        Write-Log -message "Translating Entra ID Object IDs to display names" -logFile $logFile -writeToConsole:$writeToConsole

        $objectIdsToTranslate = @()

        # Go through all files that need translation to find the object IDs
        $filesRequiringTranslation = $config.entra.filesToTranslate
        foreach ($file in $filesRequiringTranslation) {
            $content = Get-Content -Path "$($config.general.rawOutputFolder)/$($file.fileName)" -Raw | ConvertFrom-Json
            foreach ($item in $content) {
                foreach ($attribute in $file.attributesContainingObjectId) {
                    $attributeParts = $attribute -split '\.'  # Split the attribute path into an array
                    $value = $item
                    foreach ($part in $attributeParts) {
                        if ($null -ne $value -and $value.PSObject.Properties[$part]) {
                            $value = $value.$part  # Drill down step by step
                        }
                        else {
                            $value = $null
                            break
                        }
                    }
                    # Check if the returned value is a valid GUID
                    $test = [System.Guid]::empty
                    if ([System.Guid]::TryParse($value,[System.Management.Automation.PSReference]$test)) {
                        $objectIdsToTranslate += $value
                    }
                }
            }
        }

        $translatedObjectIds = [System.Collections.ArrayList]::new()

        $objectIdsToTranslate = $objectIdsToTranslate | Sort-Object -Unique
    
        foreach ($id in $objectIdsToTranslate) {
            try {
                $displayName = (Get-MgDirectoryObject -DirectoryObjectId $id -ErrorAction Stop | Select-Object -ExpandProperty AdditionalProperties).displayName
            }
            catch {
                Write-Log -message "Something went wrong when collecting the displayName for the object $id" -logFile $logFile -writeToConsole:$writeToConsole -severityLevel "WARNING"
                $displayName = $id
            }
            $tempObject = [PSCustomObject]@{
                id          = $id
                displayName = $displayName
            }
            [void]$translatedObjectIds.Add($tempObject)
        }

        OutputJson -object $translatedObjectIds -outputFile "$($config.general.rawOutputFolder)/objectIdTranslations.json"
    }
    else {
        Write-Log -message "Entra ID Object ID translation is not enabled" -logFile $logFile -writeToConsole:$writeToConsole
    }

}
else {
    Write-Log -message "Microsoft Graph is not enabled, no Entra ID inventory will be collected" -logFile $logFile -writeToConsole:$writeToConsole -severityLevel "WARNING"
}

#endregion Entra ID

# Create zip file of results

# Copy the config file used to the raw output folder
Copy-Item -Path $configFile -Destination "$($config.general.rawOutputFolder)/configFileUsed.json" -Force

Compress-Archive -Path "$($config.general.rawOutputFolder)/*" -DestinationPath "rawResults.zip" -Force