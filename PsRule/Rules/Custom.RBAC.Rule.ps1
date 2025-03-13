# Custom Validation rules for RBAC assignments

# Use RBAC assignments on resource groups instead of individual resources
# Rule 'Custom.RBAC.UseRGDelegation' -Ref 'Cust-RBAC-001' -Type 'Microsoft.Resources/resourceGroups' -Level Warning {
#     $assignments = @($TargetObject.resources | Where-Object {
#         $_.type -eq 'Microsoft.Authorization/roleAssignments' -and
#         $_.properties.scope -like "/subscriptions/*/resourceGroups/*/providers/*"
#     })
#     $Assert.
#         LessOrEqual($assignments, 'Length', 0).
#         WithReason(($LocalizedData.RoleAssignmentCount -f $assignments.Length), $True)
# }


# Synopsis: Only use RBAC assignments on subscriptions or resource groups
Rule 'Custom.RBAC.UseCorrectScopes' -Ref 'Cust-RBAC-002' -Level Warning -Type 'microsoft.authorization/roleassignments' {
    $Assert.NotIn($TargetObject, 'scopeType', @('managementGroups','resource')).
    Reason("Role: {0} is assigned to principal {1} ({2}) on {3} level.", $TargetObject.roleName, $TargetObject.principalId, $TargetObject.principalType, $TargetObject.scopeType)
}

# Synopsis: Assign RBAC roles to groups instead of individual users
Rule 'Custom.RBAC.UseGroups' -Ref 'Cust-RBAC-003' -Level Warning -Type 'microsoft.authorization/roleassignments' {
    $Assert.HasFieldValue($TargetObject,'principalType', 'group').
    Reason("Role: {0} is assigned to principal type {1} ({2}).", $TargetObject.roleName, $TargetObject.principalType, $TargetObject.principalId)
}