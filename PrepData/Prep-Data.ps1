# This script will transform the raw output from the Collect-Data.ps1 script so that it can be used by PSRule and for Inventory
param (
    [string] $zipFile = "./rawResults.zip",
    [string] $configFile = "./configPrep.json"
)

$ErrorActionPreference = 'Stop'

Import-Module ./modules/functions.psm1 -Force

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

# Ensure the zip file exists
if (-not (Test-Path $zipFile)) {
    throw "Results zip file not found: $zipFile"
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

# Ensure the cleaned output folder exists
if (-not (Test-Path $config.general.cleanedOutputFolder)) {
    Write-Log "Cleaned output folder not found: $($config.general.cleanedOutputFolder). Creating..." -logFile $logFile -writeToConsole:$writeToConsole -severityLevel "WARNING"
    New-Item -Path $config.general.cleanedOutputFolder -ItemType Directory
}

Write-Log -message "Started Prep-Data script" -logFile $logFile -writeToConsole:$writeToConsole

#endregion prepare

# Extract the zip file to rawResults folder
try {
    Write-Log -message "Extracting zip file: $zipFile" -logFile $logFile -writeToConsole:$writeToConsole
    Expand-Archive -Path $zipFile -DestinationPath $config.general.rawOutputFolder -Force
}
catch {
    throw "Failed to extract zip file: $_"
}

# Load Collection Config information
try {
    $collectionConfig = Get-Content -Raw -Path "$($config.general.rawOutputFolder)/configFileUsed.json" | ConvertFrom-Json
}
catch {
    throw "Failed to read or parse collection configuration file: $_"
}

# Translate Object IDs
## Check if the object ID translation file exists, if so create hash table for translation
if (Test-Path "$($config.general.rawOutputFolder)/objectIdTranslations.json") {
    Write-Log -message "Translating Object IDs..." -logFile $logFile -writeToConsole:$writeToConsole
    $translationHashTable = @{}
    $objectIDTranslations = Get-Content -Raw -Path "$($config.general.rawOutputFolder)/objectIdTranslations.json" | ConvertFrom-Json
    foreach ($objectID in $objectIDTranslations) {
        $translationHashTable.Add($objectID.id, $objectID.displayName)
    }
}
else {
    Write-Log -message "Object ID translation file not found. Skipping translation..." -logFile $logFile -writeToConsole:$writeToConsole -severityLevel "WARNING"
}

## Translate the object IDs in the raw output files that are specified in the collection config file
$filesRequiringTranslation = $collectionConfig.entra.filesToTranslate

foreach ($file in $filesRequiringTranslation) {
    $content = Get-Content -Path "$($config.general.rawOutputFolder)/$($file.fileName)" -Raw | ConvertFrom-Json
    foreach ($item in $content) {
        foreach ($attribute in $file.attributesContainingObjectId) {
            $attributeParts = $attribute -split '\.'  # Split the attribute path into an array
            $value = $item
            $parent = $null
            $lastKey = $null

            foreach ($part in $attributeParts) {
                if ($null -ne $value -and $value.PSObject.Properties[$part]) {
                    $parent = $value
                    $lastKey = $part
                    $value = $value.$part  # Drill down step by step
                }
                else {
                    $value = $null
                    break
                }
            }
            if ($value) {
                $parent.$lastKey = $value | ForEach-Object {
                    if ($translationHashTable.ContainsKey($_)) {
                        $translationHashTable[$_]
                    }
                    else {
                        $_
                    }
                }
            }
        }
    }
    OutputJson -object $content -outputFile "$($config.general.cleanedOutputFolder)/$($file.fileName)"
}

# Copy the rest of the files to the cleaned output folder
$alreadyCopiedFiles = Get-ChildItem -Path $config.general.cleanedOutputFolder
$filesToCopy = Get-ChildItem -Path $config.general.rawOutputFolder | Where-Object { $_.Name -notin $alreadyCopiedFiles.Name }
foreach ($file in $filesToCopy) {
    Copy-Item -Path $file.FullName -Destination "$($config.general.cleanedOutputFolder)/$($file.Name)"
}