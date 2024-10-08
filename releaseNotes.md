# Version 0.3

- Added inventory of following Entra ID components
  - Enterprise Applications
  - Managed Identities
  - Entra Director Role members
  - General Tenant information

# Version 0.2

- Increased max. number of results per query from 100 to 1000
- Moved the functions to a separate functions module (functions.psm1)
- Moved the CSV output from the ExecuteQuery function to a separate OutputCSV function
- Added detailed queries for the following resource types:
  - vnetPeerings
  - virtualMachines (including disks)
  - networkInterfaces
  - publicIpAddresses
  - networkSecurityGroups (including security rules)
  - keyVaults
- Added custom scripts for further analysis for the following resource types:
  - virtualNetworks
  - virtualMachines
  - networkSecurityGroups
- Translated Entra ID object IDs to names in RBAC query
- Added option to get group members of all groups in RBAC query
- Added description to all Powershell functions
- Translated management group and subscription ID to name in azure policy and RBAC queries

# Version 0.1

- Original version