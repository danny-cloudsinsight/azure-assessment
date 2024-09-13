$ErrorActionPreference = 'Stop'

Import-Module ./modules/functions.psm1 -Force

$inputFile = (get-content "./config.json" | ConvertFrom-Json)


Write-Host "Collecting base information."

foreach ($query in $inputFile.queries) {
    Write-Host "Executing query $($query.name)"
    $queryInput= "./queries/$($query.name).kql"
    $queryOutput= "./results/$($query.name).csv"
    
    $results = ExecuteQuery -inputFile $queryInput

    if($results){
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
        OutputCSV -object $results -outputFile $queryOutput
    }else {
        Write-Warning "Results object does not exist!"
    }

    Clear-Variable results

}
