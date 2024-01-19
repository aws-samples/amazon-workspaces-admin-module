## Amazon WorkSpaces Admin PowerShell Module

This repository hosts a PowerShell module to help administrators inventory and reboot their [Amazon WorkSpaces](https://aws.amazon.com/workspaces/all-inclusive/) at scale. Administrators that need to invoke a bulk reboot to several WorkSpaces to receive service level updates or to apply environmental updates. This can be a time consuming process within the WorkSpaces console. This PowerShell module allows administrators to inventory their WorkSpaces and export the inventory in CSV format. The CSV file can then be used as an input parameter to invoke a reboot on the specified WorkSpaces. 

### Inventory Format 
| WorkSpaceId | Region | UserName | ComputerName | Compute | RootVolume | UserVolume | RunningMode | Protocol | IPAddress | RegCode | directoryId | State | BundleId | ConnectionState | FirstName | LastName | Email |
| :----------: | :----------: | :----------: | :----------: | :----------: | :----------: | :----------: | :----------: | :----------: | :----------: | :----------: | :----------: | :----------: | :----------: | :----------: | :----------: | :----------: | :----------: |

> Note that the Active Directory parameters (`FirstName`, `LastName`, `Email`) require the script to be ran from machine that can reach Active Directory from an account that as `Get-ADUser` permissions. 


### Usage 
To review cmdlet usage, you can run `Get-Help` against the module cmdlets after importing the module. For example:
#### Inventory Cmdlet
```powershell
Get-Help Get-WorkSpacesInventory -Full
```

#### Reboot Cmdlet
```powershell
Get-Help Initialize-WorkSpacesReboot -Full
```

### Walkthrough 
FOr this walkthrough, you use [AWS CloudShell](https://aws.amazon.com/cloudshell/). CloudShell has [PowerShell.Core](https://github.com/PowerShell/PowerShell#user-content-windows-powershell-vs-powershell-core) and [AWS Tools for PowerShell](https://aws.amazon.com/powershell/) already installed. Note that CloudShell runs outside of your environment so it will not be able to get user details from Active Directory. To get these details in your inventory, invoke the `Get-WorkSpacesInventory` cmdlet from a machine that can reach Active Directory with credentials to call `Get-ADUser`. The assumed role within CloudShell will need Identity Access Management permissions to call:
- [Get-WKSWorkspace](https://docs.aws.amazon.com/powershell/latest/reference/items/Get-WKSWorkspace.html)
- [Get-WKSWorkspaceDirectories](https://docs.aws.amazon.com/powershell/latest/reference/items/Get-WKSWorkspaceDirectory.html)
- [Restart-WKSWorkspace](https://docs.aws.amazon.com/powershell/latest/reference/items/Restart-WKSWorkspace.html)
- (Optional)[Get-WKSWorkspacesConnectionStatus](https://docs.aws.amazon.com/powershell/latest/reference/items/Get-WKSWorkspacesConnectionStatus.html)

#### Using the Module
1. After authenticating into the [AWS Management Console](https://aws.amazon.com/console/), navigate to [CloudShell](https://console.aws.amazon.com/cloudshell/home?).
2. Switch to PowerShell by invoking `pwsh`.
3. Download the module by invoking `wget https://github.com/aws-samples/amazon-workspaces-admin-module/blob/main/amazon-workspaces-admin-module.psm1`.
4. Import the module by invoking `Import-Module ./amazon-workspaces-admin-module.psm1 -force`.
5. Generate your inventory by invoking `Get-WorkSpacesInventory -csv $true -region REGION-PLACEHOLDER`. See the **Usage** section for additional usage information. 
6. You pass the CSV generated in the previous step into the `Initialize-WorkSpacesReboot` cmdlet. If you would like to exclude WorkSpaces from the bulk report, simply update the CSV. To reboot the WorkSpaces in the CSV, invoke `Initialize-WorkSpacesReboot -csvPath ./WorkSpacesInventory.csv -region REGION-PLACEHOLDER`. See the **Usage** section for additional usage information.

**Note** The reboot API call is optimized load each call to the maximum of 25 WorkSpaces. If three API calls fail when calling either cmdlet, the call will exit. 


## Security

See [CONTRIBUTING](CONTRIBUTING.md#security-issue-notifications) for more information.

## License

This library is licensed under the MIT-0 License. See the LICENSE file.

