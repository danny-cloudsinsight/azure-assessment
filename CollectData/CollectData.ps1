param (
    [string] $configFile = "./configCollection.json"
)

$ErrorActionPreference = 'Stop'

Import-Module ./modules/functions.psm1 -Force
# Import-Module ./modules/customScripts.psm1 -Force

#region prepare

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

Write-Log -message "Started runInventory script" -logFile $logFile -writeToConsole:$writeToConsole
Write-Log -message "Successfully read configuration file: $configFile" -logFile $logFile -writeToConsole:$writeToConsole

Write-Log -message "Collecting Azure resources base information." -logFile $logFile -writeToConsole:$writeToConsole

#endregion prepare

#region Azure

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
        OutputJson -object $results -outputFile "$($config.general.rawOutputFolder)/$($query.BaseName).json"
    }
    else {
        Write-Log "No results for $($query.BaseName)" -logFile $logFile -writeToConsole:$writeToConsole -severityLevel "WARNING"
    }
    Clear-Variable results
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
}
else {
    Write-Log -message "Microsoft Graph is not enabled, no Entra ID inventory will be collected" -logFile $logFile -writeToConsole:$writeToConsole -severityLevel "WARNING"
}

#endregion Entra ID

# Create zip file of results

Compress-Archive -Path $config.general.rawOutputFolder -DestinationPath "results.zip" -Force