# Custom - No management group RBAC delegation

## SYNOPSIS

Only use RBAC assignments on subscriptions or resource groups

## DESCRIPTION

RBAC assignments on management group level provide too much permissions and should only be used in exceptional cases.
RBAC assignments on resource level are too granular and can lead to misconfigurations.

It is therefore recommended to use RBAC assignments on subscription or resource group level.
This rule will check all RBAC assignments and fail for those that are created on a management group level.

## RECOMMENDATION

Only create RBAC assignments on subscription or resource group level.
