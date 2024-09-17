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

# Version 0.1

- Original version