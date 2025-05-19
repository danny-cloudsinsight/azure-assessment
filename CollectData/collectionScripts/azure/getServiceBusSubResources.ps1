param(
    [string] $logFile = "./logs/Collect-Data.log",
    [switch] $writeToConsole,
    [string] $inputFile = "./rawResults/resources-full-raw.json"
)

# Import the inputFile
 
# Ensure the inputfile exists
if (-not (Test-Path $inputFile)) {
    throw "Input file not found: $inputFile"
}

try {
    $resources = Get-Content -Raw -Path $inputFile | ConvertFrom-Json
}
catch {
    throw "Failed to read or parse input file: $_"
}

$serviceBuses = $resources | Where-Object { $_.type -eq "Microsoft.ServiceBus/namespaces" }

# Create an overview of the different subscriptions that contain Service Bus resources
$subscriptionIds = $serviceBuses | Select-Object -ExpandProperty subscriptionId -Unique

$result = @()

foreach($subscriptionId in $subscriptionIds) {
    Write-Log -message "Checking Service Buses for subscription: $subscriptionId" -logFile $logFile -writeToConsole:$writeToConsole
    set-azcontext -SubscriptionId $subscriptionId | Out-Null
    $serviceBusResources = $serviceBuses | Where-Object { $_.subscriptionId -eq $subscriptionId }
    foreach($serviceBus in $serviceBusResources) {
        Write-Log -message "Checking Service Bus: $($serviceBus.name)" -logFile $logFile -writeToConsole:$writeToConsole
        # Get Queues
        $queues = Get-AzServiceBusQueue -NamespaceName $serviceBus.name -ResourceGroupName $serviceBus.resourceGroup
        if ($queues) {
            Write-Log -message "Found $($queues.Count) queues for Service Bus: $($serviceBus.name)" -logFile $logFile -writeToConsole:$writeToConsole
            foreach ($queue in $queues) {
                $queue | Add-Member -MemberType NoteProperty -Name Type -Value "microsoft.servicebus/namespaces/queue" -Force
            }
            $result += $queues
        } else {
            Write-Log -message "No queues found for Service Bus: $($serviceBus.name)" -logFile $logFile -writeToConsole:$writeToConsole
        }
    
        # Get Topics
        $topics = Get-AzServiceBusTopic -NamespaceName $serviceBus.name -ResourceGroupName $serviceBus.resourceGroup
    
        if ($topics) {
            Write-Log -message "Found $($topics.Count) topics for Service Bus: $($serviceBus.name)" -logFile $logFile -writeToConsole:$writeToConsole
            foreach ($topic in $topics) {
                $topic | Add-Member -MemberType NoteProperty -Name Type -Value "microsoft.servicebus/namespaces/topic" -Force
            }
            $result += $topics
        } else {
            Write-Log -message "No topics found for Service Bus: $($serviceBus.name)" -logFile $logFile -writeToConsole:$writeToConsole
        }
    }
}

$result