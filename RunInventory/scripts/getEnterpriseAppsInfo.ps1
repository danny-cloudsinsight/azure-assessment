param(
    [string] $logFile = "./getEnterpriseAppsInfo.log",
    [switch] $writeToConsole,
    [string] $inputFile = "../../CollectData/rawResults/entraEnterpriseApps.json"
)

# Import the inputFile
 
# Ensure the inputfile exists
if (-not (Test-Path $inputFile)) {
    throw "Input file not found: $inputFile"
}

try {
    $enterpriseApps = Get-Content -Raw -Path $inputFile | ConvertFrom-Json
}
catch {
    throw "Failed to read or parse input file: $_"
}

# Create an overview of all enterpise apps that have secrets
$appsWithSecrets = @()
foreach($enterpriseApp in $enterpriseApps) {
    if($enterpriseApp.PasswordCredentials.Count -gt 0) {
        Write-Log -message "Found $($enterpriseApp.PasswordCredentials.Count) secrets for $($enterpriseApp.DisplayName)" -logFile $logFile -writeToConsole:$writeToConsole
        foreach ($password in $enterpriseApp.PasswordCredentials) {
            $tempObject = [PSCustomObject]@{
                Name = $enterpriseApp.DisplayName
                AppId = $enterpriseApp.AppId
                SecretDisplayName = $password.displayName
                SecretEndDate = $password.EndDate
            }
            $appsWithSecrets += $tempObject
        }
    }else {
        Write-Log -message "No secrets found for $($enterpriseApp.DisplayName)" -logFile $logFile -writeToConsole:$writeToConsole
    }
}

$appsWithSecrets | Export-Csv -Path "../results/enterpriseAppsWithSecrets.csv" -NoTypeInformation -Encoding UTF8
