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
    # Get base information
    $tempresource = [PSCustomObject]@{
        Name = $resource.name
        Type = $resource.type
        ResourceGroup = $resource.resourceGroup
        SubscriptionId = $resource.subscriptionId
    }

    # Check if public endpoint is enabled
    if(($resource.properties.publicNetworkAccess -eq "Enabled") -or ($null -eq $resource.properties.publicNetworkAccess)) {
        $tempresource | Add-Member -MemberType NoteProperty -Name "PublicEndpoint" -Value "Yes"
    }
    elseif ($resource.properties.publicNetworkAccess -eq "Disabled") {
        $tempresource | Add-Member -MemberType NoteProperty -Name "PublicEndpoint" -Value "No"
    }else {
        $tempresource | Add-Member -MemberType NoteProperty -Name "PublicEndpoint" -Value "Undetermined"
    }

    # Check if the resource has a private endpoint
    if($privateEndpointResourceIds -contains $resource.id) {
        $tempresource | Add-Member -MemberType NoteProperty -Name "PrivateEndpoint" -Value "Yes"
    }
    else {
        $tempresource | Add-Member -MemberType NoteProperty -Name "PrivateEndpoint" -Value "No"
    }
    
    $results += $tempresource
    $tempresource = $null
}

$results