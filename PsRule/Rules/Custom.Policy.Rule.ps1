# Custom validation rules for Azure Policy

# Synopsis: Policy assignments should be on management group level
Rule 'Custom.Policy.AssignMGScope' -Ref 'Cust-Policy-001' -Level Warning -Type 'microsoft.authorization/policyassignments' {
    $Assert.StartsWith($targetObject.properties, 'scope', '/providers/Microsoft.Management/managementGroups/').
    Reason("Policy assignment {0} is scoped to {1}.", $TargetObject.properties.displayName, $TargetObject.properties.scope)
}