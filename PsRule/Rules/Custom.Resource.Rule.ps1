# Custom Validation rules for Resources

# Synopsis: All resources must have the required tags
Rule 'Custom.Resource.RequiredTags' -Ref 'Cust-Res-001' -With 'Azure.Resource.SupportsTags' {
    # List of resource that support tags can be found here: https://learn.microsoft.com/en-us/azure/azure-resource-manager/tag-support
    $Assert.AllOf(
        $Assert.HasField($TargetObject.tags, 'owner').Reason('Owner tag is required'),
        $Assert.HasField($TargetObject.tags, 'client').Reason('Client tag is required')
    )
}
