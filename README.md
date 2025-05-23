# Azure Assessment

## Prerequisites

- Powershell v7 or higher
- Azure **Reader** role on the tenant Management Group level to collect information on the entire environment.

## Required PowerShell modules

Following PowerShell modules are used by the different scripts:

- "Microsoft.Graph.Authentication",
- "Microsoft.Graph.DirectoryObjects",
- "Microsoft.Graph.Applications",
- "Microsoft.Graph.Identity.DirectoryManagement",
- "Microsoft.Graph.Identity.SignIns",
- "Microsoft.Graph.Identity.Governance",
- "Microsoft.Graph.Beta.Identity.DirectoryManagement",
- "Microsoft.Graph.Beta.Identity.SignIns",
- "Az.ResourceGraph",
- "Az.Accounts"

> Note: If these modules are not installed on the system, they will be saved into the *modules* folder and be imported from there.

## Required Microsoft Graph Permissions

Following Microsoft Graph scopes are required to run the scripts:

- "RoleManagement.Read.Directory",
- "Application.Read.All",
- "DeviceManagementServiceConfig.Read.All",
- "Domain.Read.All",
- "LicenseAssignment.Read.All",
- "Policy.Read.All",
- "DirectoryRecommendations.Read.All"

> Note: If permission for these scopes has not been given yet, the script will prompt the user to grant the permissions.

## Steps

1. Clone the repo to a folder on your computer
2. Open a Powershell folder in the folder where you cloned the repo
3. Validate the content of the *configCollection.json* file and optionally adapt the log and/or rawResults folder.
4. Run the script *Collect-Data.ps1*
5. Results will be stored as .json files in the _rawResults_ folder and will also be added to the archive *results.zip*

## Release Notes

See [Release Notes](./releaseNotes.md)

## Version

2025.05.23-13.54