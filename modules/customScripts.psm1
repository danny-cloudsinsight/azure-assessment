<#
.SYNOPSIS
Function that triggers the correct custom function for the provided resource type.

.DESCRIPTION
Triggers the correct custom script function for the resource type that is provided as the first parameter.
Passes through the resource type object received as parameter to the custom function and returns the result of the custom function to the calling function.

The custom functions clean-up and/or extend the results received from the Azure Resource Graph by executing the KQL query (ExecuteQuery) for the resource type in question. 

.PARAMETER resourceType
Resource type to execute the custom function for

.PARAMETER object
Resulting object of executing the KQL query belonging to the resource type 

.OUTPUTS
Outputs the result of the custom function as a PSObject

.EXAMPLE
PS> $rawResult = ExecuteQuery -inputFile "./virtualNetworks.kql"
PS> $result = ExecuteCustomScript -resourceType "virtualNetworks" -object $rawResult

.NOTES
If no custom function exists for a specific resource type this function returns the same object it received as input.
#>
function ExecuteCustomScript {
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [string] $resourceType,
        [Parameter(Mandatory = $true, Position = 1)]
        [pscustomobject] $object,
        [Parameter(Mandatory = $false, Position = 2)]
        [string] $options
    )

    switch ($resourceType) {
        "RBAC" {
            $result = CustomRBACFunction -object $object -graphOption $options
        }
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

<#
.SYNOPSIS
Custom function for the virtualNetworks resource type.

.DESCRIPTION
This function will clean-up the results of the virtualNetworks resources KQL query by:
- extracting the name, IP range and NSG for each of the subnets in the vnet from the raw result
- extracting the name and the remote virtual network for each virtual network peering for this virtual network

All other columns will remain unchanged in the result.

.PARAMETER object
Resulting object of executing the KQL query for the virtualNetwork resource type

.OUTPUTS
Outputs the result of the custom function as a PSObject

.EXAMPLE
PS> $rawResult = ExecuteQuery -inputFile "./queries/resourceTypes/virtualNetworks.kql"
PS> $result = CustomVnetFunction -object $rawResult

.NOTES
More information on the vnetPeerings will be collected via the vnetPeerings.kql query
#>
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

<#
.SYNOPSIS
Custom function for the virtual machines resource type.

.DESCRIPTION
This function will clean-up the results of the virtualMachines resources KQL query by:
- extracting the name of each nic that is attached to the virtual machine
- extracting the name and the size of each data disk attached to the virtual machine

All other columns will remain unchanged in the result.

.PARAMETER object
Resulting object of executing the KQL query for the virtualMachines resource type 

.OUTPUTS
Outputs the result of the custom function as a PSObject

.EXAMPLE
PS> $rawResult = ExecuteQuery -inputFile "./queries/resourceTypes/virtualMachines.kql"
PS> $result = CustomVmFunction -object $rawResult

.NOTES
More information on the network interfaces of the VM will be collected using the networkInterfaces.kql query
More information on the data disks of the VM will be collected using the disks.kql query
#>
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

<#
.SYNOPSIS
Custom function for the networkSecurityGroups resource type.

.DESCRIPTION
This function will clean-up the results of the networkSecurityGroups resources KQL query by:
- extracting the names of the network interfaces this NSG is applied to
- extracting the subnet names and the virtual network they belong to for each subnet this NSG is applied to
- extracting the name of the custom security rules that are part of this NSG

All other columns will remain unchanged in the result.

.PARAMETER object
Resulting object of executing the KQL query for the networkSecurityGroups resource type 

.OUTPUTS
Outputs the result of the custom function as a PSObject

.EXAMPLE
PS> $rawResult = ExecuteQuery -inputFile "./queries/resourceTypes/networkSecurityGroups.kql"
PS> $result = CustomNsgFunction -object $rawResult

.NOTES
More information on the network interfaces that this NSG is applied to, will be collected using the networkInterfaces.kql query
More information on the custom security rules that are part of this NSG will be collected using the nsgRules.kql query
#>
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
        }
        else {
            $nsg.subnets = "None"
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

<#
.SYNOPSIS
Custom function for the RBAC resources.

.DESCRIPTION
This function will translate all the Entra ID object IDs in the results to the displayName of the corresponding object.
Following columns will be adapted principalId, createdBy and updatedBy.

Furthermore for groups, this function will check how many members are in the group and optionally will also provide the name of each member.

All other columns will remain unchanged in the result.

.PARAMETER object
Resulting object of executing the KQL query for RBAC resources 

.PARAMETER graphOption
Indicates what level of Microsoft Graph querying will be used:
- "None": Graph will not be used (this function will not have any effect on the results)
- "Base": Only number of members in a group will be displayed
- "Full": Also the actual members will be added

.OUTPUTS
Outputs the result of the custom function as a PSObject

.EXAMPLE
PS> $rawResult = ExecuteQuery -inputFile "./queries/RBAC.kql"
PS> $result = CustomRBACFunction -object $rawResult

.NOTES
For this custom function to work, a Microsoft Graph connection should be active. At least the scope 'Directory.Read.All' is required
#>
function CustomRBACFunction {
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [pscustomobject] $object,
        [Parameter(Mandatory = $false, Position = 1)]
        [string] $graphOption = "None"
    )
    Write-Host "Executing custom function for RBAC"
    $result = $object

    switch ($graphOption) {
        { $_.ToLower() -in "base", "full" } { $context = Get-MgContext }
        { $_.ToLower() -in "none" } { $context = $null }
        Default { $context = $null; Write-Warning "Incorrect value for graphOption ($graphOption), assuming 'None'. Correct values are 'None', 'Base', or 'Full'" }
    }
    
    if ($context) {
        # Add columm for amount of users in role
        $object | Add-Member -MemberType NoteProperty -Name "numberOfPrincipals" -Value 0
        if ($graphOption.ToLower() -eq "full") {
            $object | Add-Member -MemberType NoteProperty -Name "groupMembers" -Value ""
        }

        $cachedUsers = @{}
        foreach ($rule in $result) {
            if ($cachedUsers.ContainsKey($rule.principalId)) {
                $rule.numberOfPrincipals = $cachedUsers[$rule.principalId].number
                if ($graphOption.ToLower() -eq "full") {$rule.groupMembers = $cachedUsers[$rule.principalId].groupMembers}
                # Keep principalId as last item to change as otherwise this breaks the lookup in the hashtable
                $rule.principalId = $cachedUsers[$rule.principalId].name
            }
            else {
                try {
                    $displayName = (Get-MgDirectoryObject -DirectoryObjectId $rule.principalId -ErrorAction Stop | Select-Object -ExpandProperty AdditionalProperties).displayName
                    if ($rule.principalType -eq "Group") {
                        $memberList = Get-MgGroupMember -GroupId $rule.principalId
                        $number = $memberList.count
                        $members = ""
                        if ($graphOption.ToLower() -eq "full") {
                            foreach ($member in $memberList) {
                                if ($cachedUsers.ContainsKey($member)) {
                                    $members += "$($cachedUsers[$member].name), "
                                }
                                else {
                                    try {
                                        $memberName = (Get-MgDirectoryObject -DirectoryObjectId $member.Id -ErrorAction Stop | Select-Object -ExpandProperty AdditionalProperties).displayName
                                        $members += "$memberName, "
                                    }
                                    catch {
                                       Write-Warning "Something went wrong when collecting the members of group $displayName"
                                    }
                                    
                                }
                            }
                            $members = $members -replace ".{2}$"
                        }
                    }
                    else {
                        $number = 1
                        $members = ""
                    } 
                    $cachedUsers.Add($rule.principalId, @{'name' = $displayName; 'number' = $number; 'groupMembers' = $members })
                    $rule.principalId = $displayName
                    $rule.numberOfPrincipals = $number
                    if ($graphOption.ToLower() -eq "full") {
                        $rule.groupMembers = $members
                    }
                }
                catch {
                    $displayName = "User not found ($($rule.principalId))"
                    $number = 0
                    $cachedUsers.Add($rule.principalId, @{'name' = $displayName; 'number' = $number })
                    $rule.principalId = $displayName
                    $rule.numberOfPrincipals = $number
                }
            }
            
            if ($rule.createdBy) {
                if ($cachedUsers.ContainsKey($rule.createdBy)) {
                    $rule.createdBy = $cachedUsers[$rule.createdBy].name
                }
                else {
                    try {
                        $createdByName = (Get-MgDirectoryObject -DirectoryObjectId $rule.createdBy -ErrorAction Stop | Select-Object -ExpandProperty AdditionalProperties).displayName
                        $cachedUsers.Add($rule.createdBy, @{'name' = $createdByName; 'number' = 1 })
                        $rule.createdBy = $createdByName    
                    }
                    catch {
                        $createdByName = "User not found ($($rule.createdBy))"
                        $number = 0
                        $cachedUsers.Add($rule.createdBy, @{'name' = $displayName; 'number' = $number })
                        $rule.createdBy = $displayName
                        $rule.numberOfPrincipals = $number
                    }
                }
            }
            if ($rule.updatedBy) {
                if ($cachedUsers.ContainsKey($rule.updatedBy)) {
                    $rule.updatedBy = $cachedUsers[$rule.updatedBy].name
                }
                else {
                    try {
                        $updatedByName = (Get-MgDirectoryObject -DirectoryObjectId $rule.updatedBy -ErrorAction Stop | Select-Object -ExpandProperty AdditionalProperties).displayName
                        $cachedUsers.Add($rule.updatedBy, @{'name' = $updatedByName; 'number' = 1 })
                        $rule.updatedBy = $updatedByName    
                    }
                    catch {
                        $updatedByName = "User not found ($($rule.createdBy))"
                        $number = 0
                        $cachedUsers.Add($rule.updatedBy, @{'name' = $displayName; 'number' = $number })
                        $rule.updatedBy = $displayName
                        $rule.numberOfPrincipals = $number
                    }
                }
            }
        }
    }
    else { 
        Write-Warning "No connection to Microsoft Graph (or -graphOption = 'None'). IDs will not be translated" 
    }
    
    return $result
}
