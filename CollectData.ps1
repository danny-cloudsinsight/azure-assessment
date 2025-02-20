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
    throw "Log directory not found: $($config.general.logFolder)"
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
    throw "Raw output folder not found: $($config.general.rawOutputFolder)"
}

Write-Log -message "Started runInventory script" -logFile $logFile -writeToConsole:$writeToConsole
Write-Log -message "Successfully read configuration file: $configFile" -logFile $logFile -writeToConsole:$writeToConsole

Write-Log -message "Collecting base information." -logFile $logFile -writeToConsole:$writeToConsole

#endregion prepare

#region Azure

# Get all queries in the query folder (and its subfolders)
$queries = Get-ChildItem -Path $config.azure.queryFolder -Filter "*.kql" -Recurse

# Execute each query
# foreach ($query in $queries) {
#     Write-Log -message "Executing query $($query.BaseName)" -logFile $logFile -writeToConsole:$writeToConsole
    
#     $results = ExecuteQuery -inputFile $query.FullName -logFile $logFile -writeToConsole:$writeToConsole

#     if ($results) {
#         OutputJson -object $results -outputFile "$($config.general.rawOutputFolder)/$($query.BaseName).json"
#     }
#     else {
#         Write-Log "No results for $($query.BaseName)" -logFile $logFile -writeToConsole:$writeToConsole -severityLevel "WARNING"
#     }
#     Clear-Variable results
# }

#endregion Azure

#region Entra ID

Write-Log -message "Connecting to Microsoft Graph (Optional)" -logFile $logFile -writeToConsole:$writeToConsole
if ($config.entra.enabled) {
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