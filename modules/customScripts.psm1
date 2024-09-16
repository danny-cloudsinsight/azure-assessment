function ExecuteCustomScript {
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [string] $resourceType,
        [Parameter(Mandatory = $true, Position = 1)]
        [pscustomobject] $object
    )

    switch ($resourceType) {
        "virtualNetworks" { 
            $result = CustomVnetFunction -object $object
        }
        Default {
            Write-Warning "No custom function defined for resource type $resourceType"
            $result = $object
        }
    }

    return $result
}

function CustomVnetFunction {
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [pscustomobject] $object
    )
    Write-Host "Executing custom function for VirtualNetworks"
    $result = $object

    
    foreach ($vnet in $result) {
        # subnets

        $newSubnet = ""
        foreach ($subnet in $vnet.subnets) {
            $newSubnet += "$($subnet.name)($($subnet.addressPrefixes)) | "
        }
        $newSubnet = $newSubnet -replace ".{3}$" #remove last 3 characters
        $vnet.subnets = $newSubnet

        # vnetPeerings     
        if ($vnet.virtualNetworkPeerings) {
            $newPeering = ""
            foreach ($peering in $vnet.virtualNetworkPeerings) {
                $remoteNetworkId = $peering.properties.remoteVirtualNetwork.id
                $remoteNetworkName = $remoteNetworkId.split("/")[-1]

                $newPeering += "$($peering.name) (remoteVnet: $remoteNetworkName) | "
            }
            $newPeering = $newPeering -replace ".{3}$"
            $vnet.virtualNetworkPeerings = $newPeering
        }else {
            $vnet.virtualNetworkPeerings = "None"
        }
    }
    
    return $result
}