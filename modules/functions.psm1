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

.PARAMETER parameters
Parameters to use for the query. Should be provided as a string containing parameter=value pairs separated by ;.
In the kql file these parameters should be put with the following syntax %PARAMETER%

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
        [string] $inputFile,
        [Parameter(Mandatory = $false, Position = 1)]
        [string] $parameters,
        [string] $logFile,
        [switch] $writeToConsole
    )

    try {
        $queryContent = Get-Content -Path $inputFile
    
    }
    catch [System.Management.Automation.ItemNotFoundException] {
        Write-Log -message "File $inputFile does not exist. Skipping!" -logFile $logFile -writeToConsole:$writeToConsole -severityLevel "WARNING"
        continue
    }
    catch {
        Write-Log -message "An uncatched error has occurred. Please investigate" -logFile $logFile -writeToConsole:$writeToConsole -severityLevel "WARNING"
        Write-Log -message "Error: $_" -logFile $logFile -writeToConsole:$writeToConsole -severityLevel "ERROR"
        exit
    }

    # Replace parameters with their value in the query
    $parameterValues = ConvertFrom-StringData -StringData ($parameters.Replace(";", "`n"))

    $parameterValues.GetEnumerator() | ForEach-Object {
        $queryContent = $queryContent.Replace("%$($_.Key.ToUpper())%", $_.Value)
    }

    $results= @()
    try {
        $temp = Search-AzGraph -Query "$queryContent" -UseTenantScope -First 1000
        $results += $temp

        while($temp.SkipToken) {
            $temp = Search-AzGraph -Query "$queryContent" -SkipToken $temp.SkipToken -UseTenantScope -First 1000
            $results += $temp
        } 
    }
    catch {
        Write-Log -message "Something went wrong when executing the KQL query in the file $inputFile. Check below message for more information" -logFile $logFile -writeToConsole:$writeToConsole -severityLevel "WARNING"
        Write-Log -message "Error: $_" -logFile $logFile -writeToConsole:$writeToConsole -severityLevel "ERROR"
        continue
    }

    return $results
}

<#
.SYNOPSIS
Creates a Json file from a Powershell object

.DESCRIPTION
Creates a Json file using a Powershell object (PSObject) as first parameter and location of the json file as the second parameter

.PARAMETER object
Contains the PSObject to write to Json

.PARAMETER outputFile
Location of the outputFile

.EXAMPLE
PS> $processes = Get-Process
PS> OutputJson -object $processes -outputFile "./processes.json"

.NOTES
If you want to create the json file in a different folder, this folder needs to exist.
#>
function OutputJson {
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [pscustomobject] $object,
        [Parameter(Mandatory = $true, Position = 1)]
        [string] $outputFile,
        [string] $logFile,
        [switch] $writeToConsole
    )

    try {
        $object | ConvertTo-Json -Depth 20 | Out-File -FilePath $outputFile -Encoding utf8
    }
    catch {
        Write-Log -message "Could not write output. Make sure the path for the output file ($outputFile) exists." -logFile $logFile -writeToConsole:$writeToConsole -severityLevel "WARNING"
        continue
    }
}

<#
.SYNOPSIS
    Writes log messages to a specified file with a severity level and optionally to the console.

.DESCRIPTION
    The `Write-Log` function logs a message to a specified log file with a timestamp and a severity level.
    Optionally, the function can also output the log message to the console, color-coded based on the severity level.

.PARAMETER message
    The message to log. This is the content that will be written to the log file and optionally to the console.

.PARAMETER logFile
    The full path to the log file where the message will be written. If the file does not exist, it will be created.

.PARAMETER severityLevel
    The severity level of the log message. Valid values are "INFO", "WARNING", and "ERROR". Default is "INFO".

.PARAMETER writeToConsole
    If specified, the log message will also be written to the console output (in addition to the log file).

.EXAMPLE
    Write-Log -message "This is a test message" -logFile "C:\Logs\script.log" -severityLevel "INFO"
    
    This will write the message "This is a test message" to the log file at "C:\Logs\script.log" with an INFO severity level.

.EXAMPLE
    Write-Log -message "This is a warning message" -logFile "C:\Logs\script.log" -severityLevel "WARNING" -writeToConsole
    
    This will write the message "This is a warning message" to the log file at "C:\Logs\script.log" and display it in the console with a yellow color.
#>
function Write-Log {
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$message,

        [Parameter(Mandatory = $true, Position = 1)]
        [string]$logFile,

        [Parameter(Mandatory = $false)]
        [ValidateSet("INFO", "WARNING", "ERROR")]
        [string]$severityLevel = "INFO",

        [switch]$writeToConsole
    )

    # Get the current timestamp
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    # Format the log entry
    $logEntry = "$timestamp - [$severityLevel] - $message"

    # Write the log entry to the file 
    try {
        Add-Content -Path $logFile -Value $logEntry -ErrorAction Stop
    }
    catch {
        Write-Error "Failed to write to log file: $_"
    }

    # Optionally write the log entry to the console
    if ($writeToConsole) {
        switch ($severityLevel) {
            INFO { $textColor = "White" }
            WARNING { $textColor = "Yellow" }
            ERROR { $textColor = "Red" }
            Default { $textColor = "White" }
        }
        Write-Host $logEntry -ForegroundColor $textColor
    }
}
