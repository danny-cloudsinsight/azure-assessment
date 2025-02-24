param (
    [string] $inputFile = "./config.json",
    [string] $logFile = "./runInventory.log",
    [switch] $writeToConsole
)

$ErrorActionPreference = 'Stop'

Import-Module ./modules/functions.psm1 -Force
Import-Module ./modules/customScripts.psm1 -Force

# Ensure the directory for the log file exists
$logDirectory = Split-Path -Path $logFile -Parent
if (-not (Test-Path -Path $logDirectory)) {
    throw "Log directory not found: $logDirectory"
}

# Read and parse the configuration file
if (-not (Test-Path $inputFile)) {
    throw "Configuration file not found: $configFile"
}

try {
    $config = Get-Content -Raw -Path $inputFile | ConvertFrom-Json
    Write-Log -message "Started runInventory script" -logFile $logFile -writeToConsole:$writeToConsole
    Write-Log -message "Successfully read configuration file: $inputFile" -logFile $logFile -writeToConsole:$writeToConsole
}
catch {
    throw "Failed to read or parse input file: $_"
}


Write-Log -message "Connecting to Microsoft Graph (Optional)" -logFile $logFile -writeToConsole:$writeToConsole
if ($config.MicrosoftGraph.enabled) {
    Connect-MgGraph -Scopes $config.MicrosoftGraph.scopes -NoWelcome
}
else {
    Write-Log -message "Microsoft Graph is not enabled, some features may not work as expected" -logFile $logFile -writeToConsole:$writeToConsole -severityLevel "WARNING"
}

Write-Log -message "Collecting base information." -logFile $logFile -writeToConsole:$writeToConsole

foreach ($query in $config.queries) {
    Write-Log -message "Executing query $($query.name)" -logFile $logFile -writeToConsole:$writeToConsole
    $queryInput = "./queries/$($query.name).kql"
    $queryOutputCsv = "./results/csv/$($query.name).csv"
    $queryOutputJson = "./results/json/$($query.name).json"
    
    $results = ExecuteQuery -inputFile $queryInput -logFile $logFile -writeToConsole:$writeToConsole

    if ($results) {
        if ($query.custom) {
            $results = ExecuteCustomScript -resourceType $query.name -object $results -options $query.customOptions -logFile $logFile -writeToConsole:$writeToConsole
        }
        OutputCSV -object $results -outputFile $queryOutputCsv
        OutputJson -object $results -outputFile $queryOutputJson
    }
    else {
        Write-Log "Results object does not exist!" -logFile $logFile -writeToConsole:$writeToConsole -severityLevel "WARNING"
    }

    Clear-Variable results
}

Write-Log -message "Collecting detailed info on resources" -logFile $logFile -writeToConsole:$writeToConsole

foreach ($resourceType in $config.resourceTypes) {
    Write-Log -message "Getting information on $($resourceType.name) ($($resourceType.type)) resources" -logFile $logFile -writeToConsole:$writeToConsole
    $queryInput = "./queries/resourceTypes/$($resourceType.name).kql"
    $queryDetailedOutputCsv = "./results/csv/resourceType-$($resourceType.name).csv"
    $queryDetailedOutputJson = "./results/json/resourceType-$($resourceType.name).json"


    $results = ExecuteQuery -inputFile $queryInput -logFile $logFile -writeToConsole:$writeToConsole

    if ($results) {
        if ($resourceType.custom) {
            $results = ExecuteCustomScript -resourceType $resourceType.name -object $results -options $resourceType.customOptions -logFile $logFile -writeToConsole:$writeToConsole
        }
        OutputCSV -object $results -outputFile $queryDetailedOutputCsv
        OutputJson -object $results -outputFile $queryDetailedOutputJson

    }
    else {
        Write-Log -message "Results object does not exist!" -logFile $logFile -writeToConsole:$writeToConsole -severityLevel "WARNING"
    }

    Clear-Variable results

}

# Collect Entra ID inventory
if ($config.MicrosoftGraph.enabled) {
    foreach ($component in $config.MicrosoftGraph.inventory) {
        if ($component.enabled) {
            $results = ExecuteMsGraphFunction -component $component.name -options $component.customOptions -logFile $logFile -writeToConsole:$writeToConsole
            if ($results) {
                $outputFileCsv = "./results/csv/entra-$($component.name).csv"
                $outputFileJson = "./results/json/entra-$($component.name).json"

                OutputCSV -object $results -outputFile $outputFileCsv
                OutputJson -object $results -outputFile $outputFileJson
            }
            else {
                Write-Log -message "No results for $($component.name)" -logFile $logFile -writeToConsole:$writeToConsole -severityLevel "WARNING"
            }
        }
    }
}
else {
    Write-Log -message "No Entra ID inventory will be collected as Microsoft Graph is not enabled" -logFile $logFile -writeToConsole:$writeToConsole -severityLevel "WARNING"
}