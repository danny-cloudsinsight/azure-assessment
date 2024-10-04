# Azure Assessment

## Prerequisites

- Powershell module **Az.ResourceGraph**
- Azure **Reader** role on the tenant Management Group level to collect information on the entire environment

## Steps

1. Clone the repo to a folder on your computer
2. Open a Powershell folder in the folder where you cloned the repo
3. Connect to Azure *Connect-AzAccount*
4. Run the script *runInventory.ps1*
5. Results will be stored as .csv files in the *results* folder
 
## Release Notes

See [Release Notes](./releaseNotes.md)