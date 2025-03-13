# Custom - Use required tags

## SYNOPSIS

All resources must have the required tags

## DESCRIPTION

A list of required tags has been defined for the Azure organization. This rule validates that all resources that support tags have the required tags. If a resource does not have all the required tags, the rule will fail.

This rule replaces the rule *Azure.Resource.UseTags* in the Module PSRule.Rules.Azure.

## RECOMMENDATION

Check how the resource is created and either add the tags manually for manual resources or make sure the tags are added in the Terraform code for resources created by Terraform.
