# Custom - RBAC assignments on RG level

## SYNOPSIS

Use RBAC assignments on resource groups instead of individual resources

## DESCRIPTION

> Remark: Currently this rule is not in use as it is replaced by the rule Custom.RBAC.UseCorrectScopes

RBAC assignments can be added on different levels. The most granular level is the resource level. However, it is recommended to assign roles on the subscription or the resource group level. This way, the role assignment is inherited by all resources within the subscription or the resource group. This makes it easier to manage the role assignments and reduces the risk of misconfigurations.

This rule replaces the default rule *Azure.RBAC.UseRGDelegation* in the Module PSRule.Rules.Azure.

## RECOMMENDATION

Consider using RBAC assignments on resource groups instead of individual resources.
