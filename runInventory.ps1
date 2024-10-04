$ErrorActionPreference = 'Stop'

Import-Module ./modules/functions.psm1 -Force
Import-Module ./modules/customScripts.psm1 -Force

$inputFile = (get-content "./config.json" | ConvertFrom-Json)

Write-Host "Connecting to Microsoft Graph (Optional)"
if ($inputFile.MicrosoftGraph.enabled){
    Connect-MgGraph -Scopes $inputFile.MicrosoftGraph.scopes
}else {
    Write-Warning "Microsoft Graph is not enabled, some features may not work as expected"
    Disconnect-MgGraph
}


Write-Host "Collecting base information."

foreach ($query in $inputFile.queries) {
    Write-Host "Executing query $($query.name)"
    $queryInput= "./queries/$($query.name).kql"
    $queryOutput= "./results/$($query.name).csv"
    
    $results = ExecuteQuery -inputFile $queryInput

    if($results){
        if($query.custom){
            $results = ExecuteCustomScript -resourceType $query.name -object $results -options $query.customOptions
        }
        OutputCSV -object $results -outputFile $queryOutput
    }else {
        Write-Warning "Results object does not exist!"
    }

    Clear-Variable results
}

Write-Host "Collecting detailed info on resources"

foreach ($resourceType in $inputFile.resourceTypes) {
    Write-Host "Getting information on $($resourceType.name) ($($resourceType.type)) resources"
    $queryInput= "./queries/resourceTypes/$($resourceType.name).kql"
    $queryOutput= "./results/resourceType-$($resourceType.name).csv"

    $results = ExecuteQuery -inputFile $queryInput

    if($results){
        if($resourceType.custom){
            $results = ExecuteCustomScript -resourceType $resourceType.name -object $results -options $resourceType.customOptions
        }
        OutputCSV -object $results -outputFile $queryOutput
    }else {
        Write-Warning "Results object does not exist!"
    }

    Clear-Variable results

}

# Collect Entra ID inventory
if($inputFile.MicrosoftGraph.enabled){
    foreach ($component in $inputFile.MicrosoftGraph.inventory) {
        if ($component.enabled) {
            $results = ExecuteMsGraphFunction -component $component.name -options $component.customOptions
            if ($results) {
                $outputFile = "./results/entra-$($component.name).csv"
                OutputCSV -object $results -outputFile $outputFile
            }else {
                Write-Warning "No results for $($component.name)"
            }
        }
    }
}else {
    Write-Warning "No Entra ID inventory will be collected as Microsoft Graph is not enabled"
}