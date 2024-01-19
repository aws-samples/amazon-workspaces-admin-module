## Amazon WorkSpaces Admin PowerShell Module

This repository hosts a PowerShell module to help administrators inventory and reboot their [Amazon WorkSpaces](Import-Module ./amazon-workspaces-admin-module.psm1 -force) at scale. Administrators that need to invoke a bulk reboot to several WorkSpaces to receive service level updates or to apply environmental updates. This can be a time consuming process within the WorkSpaces console. This PowerShell module allows administrators to inventory their WorkSpaces and export the inventory in CSV format. The CSV file can then be used as an input parameter to invoke a reboot on the specified WorkSpaces. 

### Inventory Format 
| WorkSpaceId | Region | UserName | ComputerName | Compute | RootVolume | UserVolume | RunningMode | Protocol | IPAddress | RegCode | directoryId | State | BundleId | ConnectionState | FirstName | LastName | Email |
| :----------: | :----------: | :----------: | :----------: | :----------: | :----------: | :----------: | :----------: | :----------: | :----------: | :----------: | :----------: | :----------: | :----------: | :----------: | :----------: | :----------: | :----------: |

> Note that the Active Directory parameters (`FirstName`, `LastName`, `Email`) require the script to be ran from machine that can reach Active Directory from an account that as `Get-ADUser` permissions. 


```powershell
Import-Module ./amazon-workspaces-admin-module.psm1 -force
```


## Security

See [CONTRIBUTING](CONTRIBUTING.md#security-issue-notifications) for more information.

## License

This library is licensed under the MIT-0 License. See the LICENSE file.

