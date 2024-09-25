<#
.SYNOPSIS
Executes KQL query provided via file

.DESCRIPTION
Executes a KQl query that is provided in an inputFile using the Search-AzGraph powershell command.
This command is included in the Az.ResourceGraph module, which needs to be present.

The script will issue a warning if the file does not exist or if the KQL query cannot get executed (incorrect query or other error)
The script will issue an error when something else goes wrong with the file

.PARAMETER inputFile
Location of the file containing the valid KQL to execute

.OUTPUTS
Outputs the result of the KQL query as a PSObject

.EXAMPLE
PS> echo "resources | order by name asc " > "./queryFile.kql"
PS> ExecuteQuery -inputFile "./queryFile.kql"

.NOTES
This script can return max. 1000 items 
#>
function ExecuteQuery {
    param
    (
        [Parameter(Mandatory = $true, Position = 0)]
        [string] $inputFile
    )

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
        $results = Search-AzGraph -Query "$queryContent" -UseTenantScope -First 1000
    }
    catch {
        Write-Warning "Something went wrong when executing the KQL query in the file $inputFile. Check below message for more information"
        Write-Host $queryContent
        Write-Warning $error[0]
        continue
    }

    return $results
}

<#
.SYNOPSIS
Executes KQL query provided via file (using REST API)

.DESCRIPTION
Executes a KQl query that is provided in an inputFile using the Invoke-RestMethod powershell command.
This function can for instance be used instead of the ExecuteQuery function when the Az.ResourceGraph module is not available.
The function required the Az.Accounts module to generate the authentication token.

The script will issue a warning if the file does not exist or if the KQL query cannot get executed (incorrect query or other error)
The script will issue an error when something else goes wrong with the file

.PARAMETER inputFile
Location of the file containing the valid KQL to execute

.OUTPUTS
Outputs the result of the KQL query as a PSObject

.EXAMPLE
PS> echo "resources | order by name asc " > "./queryFile.kql"
PS> ExecuteQueryRest -inputFile "./queryFile.kql"

.NOTES
This script can return max. 1000 items 
#>
function ExecuteQueryRest {
    param
    (
        [Parameter(Mandatory = $true, Position = 0)]
        [string] $inputFile
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
        "Content-Type"  = "application/json"
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

<#
.SYNOPSIS
Creates a CSV file from a Powershell object

.DESCRIPTION
Creates a CSV file using a Powershell object (PSObject) as first parameter and location of the CSV file as the second parameter

.PARAMETER object
Contains the PSObject to write to CSV

.PARAMETER outputFile
Location of the outputFile

.EXAMPLE
PS> $processes = Get-Process
PS> OutputCSV -object $processes -outputFile "./processes.csv"

.NOTES
If you want to create the CSV file in a different folder, this folder needs to exist.
#>
function OutputCSV {
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [pscustomobject] $object,
        [Parameter(Mandatory = $true, Position = 1)]
        [string] $outputFile
    )

    try {
        $object | Export-Csv -Path $outputFile -Delimiter ";" -Encoding utf8
    }
    catch {
        Write-Warning "Could not write output. Make sure the path for the output file ($outputFile) exists."
        continue
    }
}

<#
.SYNOPSIS
Turns a CSV file into a Markdown table

.DESCRIPTION
Turns a CSV file into a Markdown (.md) file containing a table with all the columns and rows from the csv file.
First line of the csv file will be used as header for the different table columns

.PARAMETER inputCSV
Path to the input CSV file

.PARAMETER outputFile
Optional location for the markdown file. By default will be in same location as CSV file, but with .md extension

.PARAMETER delimiter
Optional delimiter used in csv file. By default ';' will be used as delimiter

.EXAMPLE
PS> $processes = Get-Process
PS> OutputCSV -object $processes -outputFile "./processes.csv"
PS> ConvertCSVtoMD -inputCSV "./processes.csv" -outputFile "./processesTable.md" -delimiter ";"

.NOTES
- If you want to output the markdown file to a different folder, this folder needs to exist.
- New lines in cells in csv should be indicated using "<br>" and not with the newline character.
#>
function ConvertCSVtoMD {
    param
    (
        [Parameter(Mandatory = $true, Position = 0)]
        [string] $inputCSV,
        [Parameter(Mandatory = $false, Position = 1)]
        [string] $outputFile,
        [Parameter(Mandatory = $false, Position = 2)]
        [string] $delimiter = ";"
    )
    
    if (!$PSBoundParameters.ContainsKey('outputFile')) {
        $outputFile = $inputCSV.Substring(0, $inputCSV.LastIndexOf(".")) + ".md"
    }

    $mdData = ""

    $rawData = Get-Content -Path $inputCSV

    #Read the first line to create the headers
    $rawHeaders = $rawData | Select-Object -First 1
    $numberOfHeaders = ($rawHeaders.split($delimiter)).count
    $mdData = "|$($rawHeaders.Replace($delimiter,'|'))|`n"

    foreach ($i in 1..$numberOfHeaders) {
        $mdData += "|---"
    }
    $mdData += "|`n"

    #Remove the first line
    $rawData = $rawData | Select-Object -Skip 1

    foreach ($line in $rawData) {
        $mdData += "|$($line.Replace($delimiter,'|'))|`n"
    }

    $mdData | Out-File -Append $outPutFile

}