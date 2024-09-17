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
        "virtualMachines" {
            $result = CustomVmFunction -object $object
        }
        "networkSecurityGroups" {
            $result = CustomNsgFunction -object $object
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
            $newSubnet += "$($subnet.name)(IPs: $($subnet.addressPrefixes), NSG: $($subnet.networkSecurityGroup)) | "
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
        }
        else {
            $vnet.virtualNetworkPeerings = "None"
        }
    }
    
    return $result
}

function CustomVmFunction {
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [pscustomobject] $object
    )
    Write-Host "Executing custom function for VirtualMachines"
    $result = $object

    
    foreach ($vm in $result) {
        # network interfaces
        $newNic = ""
        foreach ($nic in $vm.networkInterface) {
            $nicName = $($nic.id).split("/")[-1]
            $newNic += "$nicName | "
        }
        $newNic = $newNic -replace ".{3}$" #remove last 3 characters
        $vm.networkInterface = $newNic

        # data disks     
        if ($vm.dataDisks) {
            $newDisk = ""
            foreach ($disk in $vm.dataDisks) {
                $diskName = $disk.name
                $size = $disk.diskSizeGB

                $newDisk += "$diskname ($($size)GB) | "
            }
            $newDisk = $newDisk -replace ".{3}$"
            $vm.dataDisks = $newDisk
        }
        else {
            $vm.dataDisks = "None"
        }
    }
    
    return $result
}

function CustomNsgFunction {
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [pscustomobject] $object
    )
    Write-Host "Executing custom function for NetworkSecurityGroups"
    $result = $object

    
    foreach ($nsg in $result) {
        # network interfaces
        if ($nsg.networkInterfaces) {
            $newNic = ""
            foreach ($nic in $nsg.networkInterfaces) {
                $nicName = $($nic.id).split("/")[-1]
                $newNic += "$nicName | "
            }
            $newNic = $newNic -replace ".{3}$" #remove last 3 characters
            $nsg.networkInterfaces = $newNic
        }
        else {
            $nsg.networkInterfaces = "None"
        }

        # subnets
        if ($nsg.subnets) {
            $newSubnet = ""
            foreach ($subnet in $nsg.subnets) {
                $subnetName = $($subnet.id).split("/")[-1]
                $vnetName = $($subnet.id).split("/")[-3]
                $newSubnet += "$subnetName (vnet: $vnetName) | "
            }
            $newSubnet = $newSubnet -replace ".{3}$" #remove last 3 characters
            $nsg.subnets = $newSubnet
        }else{
            $nsg.subnets= "None"
        }

        # security rules    
        if ($nsg.securityRules) {
            $newRule = ""
            foreach ($rule in $nsg.securityRules) {
                $ruleName = $rule.name
                $newRule += "$ruleName | "
            }
            $newRule = $newRule -replace ".{3}$"
            $nsg.securityRules = $newRule
        }
        else {
            $nsg.securityRules = "None"
        }
    }
    
    return $result
}
