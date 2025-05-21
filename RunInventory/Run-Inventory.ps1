# This script wil take the raw output from the Collect-Data.ps1 script (see rawResults folder) and create an inventory with the most relevant information.
param(
    [string] $logFile = "./Run-Inventory.log",
    [switch] $writeToConsole,
    [string] $inputFile = "../CollectData/rawResults/resources-full-raw.json",
    [string] $privateEndpointTypesFile = "./scripts/privateEndpointTypes.txt"
)

$ErrorActionPreference = 'Stop'

Import-Module ../modules/functions.psm1 -Force

# Ensure both files exists and can be read
if (-not (Test-Path $inputFile)) {
    Write-Log -message "Input file not found: $inputFile" -logFile $logFile -writeToConsole:$writeToConsole -severityLevel "ERROR"
    exit 1
}

if (-not (Test-Path $privateEndpointTypesFile)) {
    Write-Log -message "Private endpoint types file not found: $privateEndpointTypesFile" -logFile $logFile -writeToConsole:$writeToConsole -severityLevel "ERROR"
    exit 1
}

if (-not (Test-Path $logFile)) {
    New-Item -Path $logFile -ItemType File -Force
}    

#Run getEndpoints.ps1
try {
    $endpointOverview = ./scripts/getEndpoints.ps1 -logFile $logFile -writeToConsole:$writeToConsole -inputFile $inputFile -privateEndpointTypesFile $privateEndpointTypesFile
}
catch {
    Write-Log -message "Failure when running getEndpoints.ps1: $_" -logFile $logFile -writeToConsole:$writeToConsole -severityLevel "ERROR"
}

# # Run getEnterpriseAppsInfo.ps1 - Collects the enterprise apps that have secrets
# try {
#     $enterpriseAppsOverview = ./scripts/getEnterpriseAppsInfo.ps1 -logFile $logFile -writeToConsole:$writeToConsole -inputFile $inputFile
# }
# catch {
#     Write-Log -message "Failed to run getEnterpriseAppsInfo.ps1: $_" -logFile $logFile -writeToConsole:$writeToConsole -severityLevel "ERROR"
# }

if($endpointOverview){
    Write-Log -message "Successfully collected all endpoints" -logFile $logFile -writeToConsole:$writeToConsole -severityLevel "INFO"
    $endpointOverview | Export-Csv -Path ./results/endpoints.csv -NoTypeInformation -Force -Encoding UTF8
    Write-Log -message "Endpoints Summary:" -logFile $logFile -writeToConsole:$writeToConsole -severityLevel "INFO"
    Write-Log -message "Total Endpoints: $($endpointOverview.Count)" -logFile $logFile -writeToConsole:$writeToConsole -severityLevel "INFO"
    Write-Log -message "Total Public Endpoints: $(($endpointOverview | Where-Object { $_.PublicEndpoint -eq 'Yes' }).Count)" -logFile $logFile -writeToConsole:$writeToConsole -severityLevel "INFO"
    Write-Log -message "Total Endpoints with private connection: $(($endpointOverview | Where-Object { $_.PrivateEndpoint -eq 'Yes' }).Count)" -logFile $logFile -writeToConsole:$writeToConsole -severityLevel "INFO"
    Write-Log -message "Total completely private endpoints: $(($endpointOverview | Where-Object { $_.PublicEndpoint -eq 'No' -and $_.PrivateEndpoint -eq 'Yes' }).Count)" -logFile $logFile -writeToConsole:$writeToConsole -severityLevel "INFO"

}else {
    Write-Log -message "Something went wrong when collecting all endpoints" -logFile $logFile -writeToConsole:$writeToConsole -severityLevel "INFO"
}

# $enterpriseAppsOverview | Export-Csv -Path ./results/enterpriseApps.csv -NoTypeInformation -Force -Encoding UTF8