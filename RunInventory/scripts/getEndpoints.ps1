param(
    [string] $logFile = "./getPublicEndpoints.log",
    [switch] $writeToConsole,
    [string] $inputFile = "../../CollectData/rawResults/resources-full-raw.json",
    [string] $privateEndpointTypesFile = "./privateEndpointTypes.txt"
)

# Import the inputFile and privateEndpointTypesFile
 
# Ensure both files exists and can be read
if (-not (Test-Path $inputFile)) {
    throw "Input file not found: $inputFile"
}

try {
    $resources = Get-Content -Raw -Path $inputFile | ConvertFrom-Json
}
catch {
    throw "Failed to read or parse input file: $_"
}

if (-not (Test-Path $privateEndpointTypesFile)) {
    throw "Private endpoint types file not found: $privateEndpointTypesFile"
}

try {
    $privateEndpointResourceTypes = Get-Content -Path $privateEndpointTypesFile
}
catch {
    throw "Failed to read or parse private endpoint types file: $_"
}


# Check all resources that can have private endpoints and validate if they have any
# Get all resources that can have private endpoints
$resourcesToCheck = $resources | Where-Object { $_.type -in $privateEndpointResourceTypes }
$results = @()

if(-not $resourcesToCheck) {
    throw "No resources found that can have private endpoints."
}

# Collect all the private endpoints created manually
$privateEndpoints = $resources | Where-Object { $_.type -eq "Microsoft.Network/privateEndpoints" }
$privateEndpointResourceIds = $privateEndpoints.properties.privateLinkServiceConnections.properties.privateLinkServiceId

foreach ($resource in $resourcesToCheck) {
    # Get base information and initializa all members
    $tempresource = [PSCustomObject]@{
        Name = $resource.name
        Type = $resource.type
        ResourceGroup = $resource.resourceGroup
        SubscriptionName = $resource.subscriptionName
        Sku = "Not available"
        PublicEndpoint = "Undetermined"
        PrivateEndpoint = "Not available"
        NetworkAcls = "Not available"
        Supported = "Yes"
        Remarks = ""
    }

    # Add Sku
    if($resource.sku.name) {
        $tempresource.Sku = $resource.sku.name
    }
    elseif ($resource.sku.tier) {
        $tempresource.Sku = $resource.sku.tier
    }
    elseif($resource.properties.sku.name) {
        $tempresource.Sku = $resource.properties.sku.name
    }
    elseif ($resource.properties.sku) {
        $tempresource.Sku = $resource.properties.sku
    }

    # Check if public endpoint is enabled
    if(($resource.properties.publicNetworkAccess -eq "Enabled") -or ($null -eq $resource.properties.publicNetworkAccess)) {
        $tempresource.PublicEndpoint = "Yes"
    }
    elseif ($resource.properties.publicNetworkAccess -eq "Disabled") {
        $tempresource.PublicEndpoint = "No"
    }

    # Check if the resource has a private endpoint
    if($privateEndpointResourceIds -contains $resource.id) {
        $tempresource.PrivateEndpoint = "Yes"
    }
    else {
        $tempresource.PrivateEndpoint = "No"
    }

    # Custom configuration for specific resource types
    ## microsoft.apimanagement/service
    if ($resource.type.ToLower() -eq "microsoft.apimanagement/service") {
        # publicNetworkAccess is not relevant if virtualNetworkType is Internal, APIM is always private in this case
        if($resource.properties.virtualNetworkType -eq "Internal") {
            $tempresource.PublicEndpoint = "No"
        }
        $tempresource.Remarks = "virtualNetworkType = $($resource.properties.virtualNetworkType)"
    }

    ## microsoft.web/sites
    if ($resource.type.ToLower() -eq "microsoft.web/sites") {
        # private endpoints are not supported for skus 'Free' and 'Dynamic'
        if ($tempresource.Sku -eq "Free" -or $tempresource.Sku -eq "Dynamic") {
            $tempresource.Supported = "No"
            $tempresource.Remarks = "Private endpoints are not supported when Sku is Free or Dynamic"
        }
    }

    ##microsoft.cache/redis
    ##microsoft.containerregistry/registries
    ##microsoft.servicebus/namespaces
    if ($resource.type.ToLower() -eq "microsoft.cache/redis" -or $resource.type.ToLower() -eq "microsoft.containerregistry/registries" -or $resource.type.ToLower() -eq "microsoft.servicebus/namespaces") {
        # private endpoints are only supported for the premium sku
        if ($tempresource.Sku -ne "Premium") {
            $tempresource.Supported = "No"
            $tempresource.Remarks = "Private endpoints are only supported for the Premium sku"
        }
    }

    ##microsoft.eventhub/namespaces
    if ($resource.type.ToLower() -eq "microsoft.eventhub/namespaces") {
        # private endpoints are not supported for the basic sku
        if ($tempresource.Sku -eq "Basic") {
            $tempresource.Supported = "No"
            $tempresource.Remarks = "Private endpoints are not supported for the Basic sku"
        }
    }
    
    ##microsoft.keyvault/vaults
    ##microsoft.storage/storageaccounts
    if ($resource.type.ToLower() -eq "microsoft.keyvault/vaults" -or $resource.type.ToLower() -eq "microsoft.storage/storageaccounts") {
        # Check if networkAcls is configured
        if($resource.properties.networkAcls -and $resource.properties.networkAcls.defaultAction -ne "Allow") {
            $ipRules = ($resource.properties.networkAcls.ipRules | ForEach-Object { $_.value }) -join ' _ '
            $vNetRules = ($resource.properties.networkAcls.virtualNetworkRules | ForEach-Object { ($_.id -split '/')[-3..-1] -join '/'}) -join ' _ '
            $resourceAccessRules = ($resource.properties.networkAcls.resourceAccessRules | ForEach-Object { ($_.resourceId -split '/')[-3..-1] -join '/' }) -join ' _ '
            $text = "bypass: $($resource.properties.networkAcls.bypass) | ipRules: $ipRules | virtualNetworkRules: $vnetRules"
            if ($resource.type.ToLower() -eq "microsoft.storage/storageaccounts") {
                $text += " | resourceAccessRules: $resourceAccessRules"
            }
            $tempresource.NetworkAcls = "Configured"
            $tempresource.Remarks = $text
        }
        else {
            $tempresource.NetworkAcls = "Not configured"
        }
    }

    $results += $tempresource
    $tempresource = $null
}

$results