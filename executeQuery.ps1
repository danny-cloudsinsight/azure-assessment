$ErrorActionPreference = 'Stop'

## Functions
function ExecuteQuery {
    Param
    (
        [Parameter(Mandatory = $true, Position = 0)]
        [string] $inputFile,
        [Parameter(Mandatory = $true, Position = 0)]
        [string] $outputFile
    )

    # Execute query
    try {
        $queryContent = get-content -Path $inputFile
    
    }
    catch [System.Management.Automation.ItemNotFoundException] {
        Write-Warning "File $inputFile does not exist. Skipping!"
        continue
    }
    catch {
        Write-Warning "An uncatched error has occurred. Please investigate"
        Write-Error $error[0]
    }

    try {
        $results = Search-AzGraph -Query "$queryContent" -UseTenantScope
    }
    catch {
        Write-Warning "Something went wrong when executing the KQL query in the file $inputFile. Check below message for more information"
        Write-Host $queryContent
        Write-Warning $error[0]
        continue
    }


    ## Write Results
    try {
        $results | Export-Csv -Path $outputFile -Delimiter ";" -Encoding utf8
    }
    catch {
        Write-Warning "Could not write output. Make sure the path for the output file ($outputFile) exists."
        continue
    }
}

function ExecuteQueryRest {
    Param
    (
        [Parameter(Mandatory = $true, Position = 0)]
        [string] $inputFile,
        [Parameter(Mandatory = $true, Position = 0)]
        [string] $outputFile
    )

    # Execute query
    try {
        $queryContent = get-content -Path $inputFile
    
    }
    catch [System.Management.Automation.ItemNotFoundException] {
        Write-Warning "File $inputFile does not exist. Skipping!"
        continue
    }
    catch {
        Write-Warning "An uncatched error has occurred. Please investigate"
        Write-Error $error[0]
    }

    $uri = "https://management.azure.com/providers/Microsoft.ResourceGraph/resources?api-version=2022-10-01"
    $token = (Get-AzAccessToken).Token
    $headers = @{
        "Content-Type" = "application/json"
        "Authorization" = "Bearer $token"
    }
    $escapedQueryContent = $queryContent -replace '"', '\"'
    $body = "{`"query`": `"$escapedQueryContent`"}"

    try {
        $results = Invoke-RestMethod -Uri $uri -Method Post -Headers $headers -Body $body
    }
    catch {
        Write-Warning "Something went wrong when executing the KQL query in the file $inputFile. Check below message for more information"
        Write-Warning $error[0]
        continue
    }


    ## Write Results
    try {
        $results.data | Export-Csv -Path $outputFile -Delimiter ";" -Encoding utf8
    }
    catch {
        Write-Warning "Could not write output. Make sure the path for the output file ($outputFile) exists."
        continue
    }
}



$inputFile = (get-content "./config.json" | ConvertFrom-Json)


Write-Host "Collecting base information."

foreach ($query in $inputFile.queries) {
    Write-Host "Executing query $($query.name)"
    
    ExecuteQuery -inputFile "./queries/$($query.name).kql" -outputFile "./results/$($query.name).csv"
}

Write-Host "Collecting detailed info on resources"

foreach ($resourceType in $inputFile.resourceTypes) {
    Write-Host "Getting information on $($resourceType.name) ($($resourceType.type)) resources"

    ExecuteQuery -inputFile "./queries/resourceTypes/$($resourceType.name).kql" -outputFile "./results/resourceType-$($resourceType.name).csv"
}
