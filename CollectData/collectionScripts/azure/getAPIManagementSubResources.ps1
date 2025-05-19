param(
    [string] $logFile = ".logs/Collect-Data.log",
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

$apiManagementServices = $resources | Where-Object { $_.type -eq "microsoft.apimanagement/service" }

# Create an overview of the different subscriptions that contain Service Bus resources
$subscriptionIds = $apiManagementServices | Select-Object -ExpandProperty subscriptionId -Unique

# Prepare arrays to store the results
$result = @()

foreach ($subscriptionId in $subscriptionIds) {
    Write-Log -message "Checking API Management Services for subscription: $subscriptionId" -logFile $logFile -writeToConsole:$writeToConsole
    set-azcontext -SubscriptionId $subscriptionId | Out-Null
    $apiManagementResources = $apiManagementServices | Where-Object { $_.subscriptionId -eq $subscriptionId }
    foreach ($apiManagementService in $apiManagementResources) {
        Write-Log -message "Checking Api Management Service: $($apiManagementService.name)" -logFile $logFile -writeToConsole:$writeToConsole
        # Create API Context
        $apiManagementContext = New-AzApiManagementContext -ResourceGroupName $apiManagementService.resourceGroup -ServiceName $apiManagementService.name

        # Get APIs
        $apis = Get-AzApiManagementApi -Context $apiManagementContext
        if ($apis) {
            Write-Log -message "Found $($apis.Count) APIs for API Management Service: $($apiManagementService.name)" -logFile $logFile -writeToConsole:$writeToConsole
            foreach ($api in $apis) {
                $api | Add-Member -MemberType NoteProperty -Name Type -Value "microsoft.apimanagement/service/api" -Force
            }
            $result += $apis
        }
        else {
            Write-Log -message "No APIs found for API Management Service: $($apiManagementService.name)" -logFile $logFile -writeToConsole:$writeToConsole
        }

        # Get Backends
        $backends = Get-AzApiManagementBackend -Context $apiManagementContext
        if ($backends) {
            Write-Log -message "Found $($backends.Count) backends for API Management Service: $($apiManagementService.name)" -logFile $logFile -writeToConsole:$writeToConsole
            foreach ($backend in $backends) {
                $backend | Add-Member -MemberType NoteProperty -Name Type -Value "microsoft.apimanagement/service/backend" -Force
            }
            $result += $backends
        }
        else {
            Write-Log -message "No backends found for API Management Service: $($apiManagementService.name)" -logFile $logFile -writeToConsole:$writeToConsole
        }

        # Get all subscriptions
        $apiSubscriptions = Get-AzApiManagementSubscription -Context $apiManagementContext
        if ($apiSubscriptions) {
            Write-Log -message "Found $($apiSubscriptions.Count) subscriptions for API Management Service: $($apiManagementService.name)" -logFile $logFile -writeToConsole:$writeToConsole
            foreach ($apiSubscription in $apiSubscriptions) {
                $apiSubscription | Add-Member -MemberType NoteProperty -Name Type -Value "microsoft.apimanagement/service/subscription" -Force
            }
            $result += $apiSubscriptions
        }
        else {
            Write-Log -message "No subscriptions found for API Management Service: $($apiManagementService.name)" -logFile $logFile -writeToConsole:$writeToConsole
        }

        # Get Products
        $products = Get-AzApiManagementProduct -Context $apiManagementContext
        
        if ($products) {
            Write-Log -message "Found $($products.Count) products for API Management Service: $($apiManagementService.name)" -logFile $logFile -writeToConsole:$writeToConsole
            foreach ($product in $products) {
                # Get APIS belonging to the product
                $productApis = (Get-AzApiManagementApi -Context $apiManagementContext -ProductId $product.ProductId).Name
                # Get Subscriptions belonging to the product
                $productSubscriptions = ($apiSubscriptions | Where-Object { $_.ProductId -eq $product.ProductId })

                # Add Apis and Subscriptions as additional properties to the product object
                $product | Add-Member -MemberType NoteProperty -Name Type -Value "microsoft.apimanagement/service/product" -Force
                $product | Add-Member -MemberType NoteProperty -Name Apis -Value $productApis -Force
                $product | Add-Member -MemberType NoteProperty -Name Subscriptions -Value $productSubscriptions -Force
            }
            $result += $products
        }
        else {
            Write-Log -message "No products found for API Management Service: $($apiManagementService.name)" -logFile $logFile -writeToConsole:$writeToConsole
        }
        
    }
}

$result