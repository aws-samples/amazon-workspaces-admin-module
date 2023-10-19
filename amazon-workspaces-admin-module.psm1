<#
Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.

Permission is hereby granted, free of charge, to any person obtaining a copy of this
software and associated documentation files (the "Software"), to deal in the Software
without restriction, including without limitation the rights to use, copy, modify,
merge, publish, distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A
PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#>

function Get-WorkSpacesInventory(){
     <#
        .SYNOPSIS
            This cmdlet will create an inventory for your Amazon WorkSpaces in a specified region that is exported as a CSV or PowerShell object.
        .DESCRIPTION
            This cmdlet will build an inventory of your deployed WorkSpaces in a specified region. All registered directories in that region
            will be referenced for building the inventory. If this cmdlet is executed within the Active Directory domain that aligns to the directories
            and has permissions to call Get-ADUser, the inventory will include Active Directory attributes.
        .PARAMETER region
            This required parameter is a string value for the region you are building the WorkSpaces report for. For example, 'us-east-1'. 
        .PARAMETER directoryId
            This is an optional string parameter that, if specified, will only inventory the WorkSpaces in this provided directory Id. If unspecified, all regional directories will be inventoried.
        .PARAMETER csv
            This is an optional boolean parameter that, if set to $true, will export the inventory as a CSV file in your working dirctory named: 'WorkSpacesInventory-REGION-MM-dd-yyyy_HH-mm.csv'.
            If set to $false or unspecified, the inventory will return as a PowerShell object. 
        .PARAMETER connectedStatus
            This is an optional boolean parameter that, if set to $true, will check the connection status of the WorkSpaces' user. If unspecified, the entry will be set to UNKNOWN. Note that
            the API used for this is one call per WorkSpace. 
        .EXAMPLE
            $wksObject = Get-WorkSpacesInventory -region us-east-1
            Get-WorkSpacesInventory -csv $true -region us-east-1
            Get-WorkSpacesInventory -csv $true -connectedStatus $true -region us-east-1
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$region,
        [Parameter(Mandatory=$false)]
        [string]$directoryId,
        [Parameter(Mandatory=$false)]
        [bool]$csv,
        [Parameter(Mandatory=$false)]
        [bool]$connectedStatus
    )

    $awsRegions = (Get-AWSRegion).Region 
    if (-not($region -in $awsRegions)){
        Write-Host "Provided region is not an AWS Region."
        break
    }
    $WorkSpacesInventory = @()
    $DeployedDirectories = @()

    $RegionsCall = Get-WKSWorkspaceDirectories -Region $region
    if($directoryId){
        $RegionsCall = $RegionsCall | where {$_.DirectoryId -eq $directoryId}
    }
    if($RegionsCall){
        foreach($WksDir in $RegionsCall){
            $DeployedDirectoriesTemp = New-Object -TypeName PSobject
            $DeployedDirectoriesTemp | Add-Member -NotePropertyName "Region" -NotePropertyValue $region
            $DeployedDirectoriesTemp | Add-Member -NotePropertyName "RegistrationCode" -NotePropertyValue $WksDir.RegistrationCode
            $DeployedDirectoriesTemp | Add-Member -NotePropertyName "DirectoryId" -NotePropertyValue $WksDir.DirectoryId
            $DeployedDirectories += $DeployedDirectoriesTemp
        }
        foreach($DeployedDirectory in $DeployedDirectories){
            $RegionalWks = Get-WKSWorkSpaces -Region $region -DirectoryId $DeployedDirectory.DirectoryId
            foreach ($Wks in $RegionalWks){
                $adErr = $false
                $entry = New-Object -TypeName PSobject
                $entry | Add-Member -NotePropertyName "WorkSpaceId" -NotePropertyValue $Wks.WorkspaceId
                $entry | Add-Member -NotePropertyName "Region" -NotePropertyValue $region
                $entry | Add-Member -NotePropertyName "UserName" -NotePropertyValue $Wks.UserName 
                $entry | Add-Member -NotePropertyName "ComputerName" -NotePropertyValue $Wks.ComputerName
                $entry | Add-Member -NotePropertyName "Compute" -NotePropertyValue $Wks.WorkspaceProperties.ComputeTypeName | Out-String
                $entry | Add-Member -NotePropertyName "RootVolume" -NotePropertyValue $Wks.WorkspaceProperties.RootVolumeSizeGib 
                $entry | Add-Member -NotePropertyName "UserVolume" -NotePropertyValue $Wks.WorkspaceProperties.UserVolumeSizeGib
                $entry | Add-Member -NotePropertyName "RunningMode" -NotePropertyValue $Wks.WorkspaceProperties.RunningMode
                if($Wks.WorkspaceProperties.Protocols -like "WSP"){$wsProto = 'WSP'}else{$wsProto = 'PCoIP'}
                $entry | Add-Member -NotePropertyName "Protocol" -NotePropertyValue $wsProto
                $entry | Add-Member -NotePropertyName "IPAddress" -NotePropertyValue $Wks.IPAddress
                $entry | Add-Member -NotePropertyName "RegCode" -NotePropertyValue ($DeployedDirectory | Where-Object {$_.directoryId -eq $Wks.directoryId}).RegistrationCode
                $entry | Add-Member -NotePropertyName "directoryId" -NotePropertyValue $Wks.directoryId
                $entry | Add-Member -NotePropertyName "State" -NotePropertyValue $Wks.State
                $entry | Add-Member -NotePropertyName "BundleId" -NotePropertyValue $Wks.BundleId
                if($connectedStatus -eq $true){
                    if($Wks.State -ne 'STOPPED'){
                        $connectionState = Get-WKSWorkspacesConnectionStatus -WorkspaceId $Wks.WorkspaceId -region $region
                        $entry | Add-Member -NotePropertyName "ConnectionState" -NotePropertyValue $connectionState.ConnectionState
                    }else{
                        $entry | Add-Member -NotePropertyName "ConnectionState" -NotePropertyValue "DISCONNECTED"
                    }
                }else{
                    $entry | Add-Member -NotePropertyName "ConnectionState" -NotePropertyValue "UNKNOWN"
                }
                try{
                    $ADUser = Get-ADUser -Identity $Wks.UserName -Properties "EmailAddress"
                }catch{
                    $adErr = $true
                }
                if($adErr -eq $false){
                    $entry | Add-Member -NotePropertyName "FirstName" -NotePropertyValue ($ADUser.GivenName)
                    $entry | Add-Member -NotePropertyName "LastName" -NotePropertyValue ($ADUser.Surname)
                    $entry | Add-Member -NotePropertyName "Email" -NotePropertyValue ($ADUser.EmailAddress)
                    $WorkSpacesInventory += $entry
                }else{
                    $entry | Add-Member -NotePropertyName "FirstName" -NotePropertyValue "AD Info Not Available"
                    $entry | Add-Member -NotePropertyName "LastName" -NotePropertyValue "AD Info Not Available"
                    $entry | Add-Member -NotePropertyName "Email" -NotePropertyValue "AD Info Not Available"
                    $WorkSpacesInventory += $entry
                }
            }
        }
        if($csv){
            $csvCreationTime = Get-Date -format "MM-dd-yyyy_HH-mm"
            $WorkSpacesInventory | Export-Csv -Path ".\WorkSpacesInventory-$region-$csvCreationTime.csv"
        }else{
            return $WorkSpacesInventory
        }
    }else{
        if($directoryId){
            Write-Host "The specified directory `"$directoryId`" was not found as registered in the specified AWS Region: $region"
        }else{
            Write-Host "There are no registered directories in the specified AWS Region: $region"
        }
        break
    }
}

function Initialize-WorkSpacesReboot {
    <#
        .SYNOPSIS
            This cmdlet will invoke a Restart API against the Amazon WorkSpaces in the specified CSV inventory.
        .DESCRIPTION
            This cmdlet will ingest your WorkSpaces inventory through a specified CSV path. This is limited to the WorkSpaces that are in an AVAILABLE or 
            UNHEALTHY state. The WorkSpaces specified in your CSV will be rebooted. 
        .PARAMETER region
            This required parameter is a string value for the region you invoking the Reboot calls in. For example, 'us-east-1'. 
        .PARAMETER csvPath
            This is a required string parameter for the file path of your CSV inventory. If the file cannot be found, the cmdlet will exit. 
        .PARAMETER dryRun
            This is an optional boolean parameter that, if set to $true, will not invoke the Restart API calls. Instead, it will write them to the PowerShell 
            terminal as a dry run. If unspecified, the APIs will be invoked.
        .PARAMETER force
            This is an optional boolean parameter that, if set to $true, will ignore the users that have a connection state of CONNECTED. Note, by forcing
            the users connected will lose access during the reboot. If unspecified, the connected users will be ignored in the reboot call.
        .EXAMPLE
            Initialize-WorkSpacesReboot -csvPath ./WorkSpacesInventory.csv -region us-east-1
            Initialize-WorkSpacesReboot -csvPath ./WorkSpacesInventory.csv -dryRun $true -region us-east-1
            Initialize-WorkSpacesReboot -csvPath ./WorkSpacesInventory.csv -force $true -region us-east-1
            Initialize-WorkSpacesReboot -csvPath ./WorkSpacesInventory.csv -dryRun $true -force $true -region us-east-1
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$region,
        [Parameter(Mandatory=$true)]
        [string]$csvPath,
        [Parameter(Mandatory=$false)]
        [bool]$dryRun,
        [Parameter(Mandatory=$false)]
        [bool]$force
    )
    if(Test-Path $csvPath){
        $wksInventory = Import-CSV $csvPath
    }else{
        Write-Host "The provided CSV path was not found."
        break
    }
    if($force -ne $true){
        $wksRebootList = $wksInventory | where {$_.Region -eq $region} | where {($_.State -eq 'AVAILABLE') -or ($_.State -eq 'UNHEALTHY')} | where {$_.ConnectionState -eq 'DISCONNECTED'}
    }else{
        $wksRebootList = $wksInventory | where {$_.Region -eq $region} | where {($_.State -eq 'AVAILABLE') -or ($_.State -eq 'UNHEALTHY')} 
    }
    if($wksRebootList.WorkspaceId.count -eq 0){
        Write-Host "No WorkSpaces are available for reboot in the provided CSV."
        break
    }
    $response = Read-Host "There are currently"$wksRebootList.WorkspaceId.count"WorkSpaces in your list that will be rebooted. Would you like to Reboot these WorkSpaces? (Y/N)"
    if($response -like 'Y'){
        $counter = 0
        $builder = @()
        
        foreach($wks in $wksRebootList){
            $counter++
            if($counter -eq $wksRebootList.WorkspaceId.count){
                $builder += $wks.WorkSpaceId
                $callBlock = "Restart-WKSWorkspace -Region $region -WorkSpaceId $builder"
                $scriptblock = [Scriptblock]::Create($callBlock) 
                if($dryRun -eq $true){
                    Write-Host $callBlock
                }else{
                    try{
                        Invoke-Command -scriptblock $scriptblock
                    }Catch{
                        $msg = $_
                        $logging = New-Object -TypeName PSobject
                        $logging | Add-Member -NotePropertyName "ErrorCode" -NotePropertyValue "Error During Rebuild"
                        $logging | Add-Member -NotePropertyName "ErrorMessage" -NotePropertyValue $msg
                        Write-Host $logging
                    }
                }
            }
            elseif($counter % 25 -ne 0){ 
                $builder += $wks.WorkSpaceId + ","
            }else{
                $builder += $wks.WorkSpaceId
                $callBlock = "Restart-WKSWorkspace -Region $region -WorkSpaceId $builder"
                $scriptblock = [Scriptblock]::Create($callBlock) 
                if($dryRun -eq $true){
                    Write-Host $callBlock
                }else{
                    try{
                        Invoke-Command -scriptblock $scriptblock
                    }Catch{
                        $msg = $_
                        $logging = New-Object -TypeName PSobject
                        $logging | Add-Member -NotePropertyName "ErrorCode" -NotePropertyValue "Error During Rebuild"
                        $logging | Add-Member -NotePropertyName "ErrorMessage" -NotePropertyValue $msg
                        Write-Host $logging
                    }
                }
                $builder = @()
            }
        }
    }else{
        Write-Host "Restart WorkSpaces was not executed because you answered with"`'$response`'
    }
}

function Initialize-WorkSpacesStart {
    <#
        .SYNOPSIS
            This cmdlet will invoke a Start API against the Amazon WorkSpaces in the specified CSV inventory.
        .DESCRIPTION
            This cmdlet will ingest your WorkSpaces inventory through a specified CSV path. This is limited to the WorkSpaces that are in a STOPPED state. 
            The WorkSpaces specified in your CSV will be started.
        .PARAMETER region
            This required parameter is a string value for the region you invoking the Start calls in. For example, 'us-east-1'. 
        .PARAMETER csvPath
            This is a required string parameter for the file path of your CSV inventory. If the file cannot be found, the cmdlet will exit. 
        .PARAMETER dryRun
            This is an optional boolean parameter that, if set to $true, will not invoke the Start API calls. Instead, it will write them to the PowerShell 
            terminal as a dry run. If unspecified, the APIs will be invoked.
        .EXAMPLE
            Initialize-WorkSpacesStart -csvPath ./WorkSpacesInventory.csv -region us-east-1
            Initialize-WorkSpacesStart -csvPath ./WorkSpacesInventory.csv -dryRun $true -region us-east-1
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$region,
        [Parameter(Mandatory=$true)]
        [string]$csvPath,
        [Parameter(Mandatory=$false)]
        [bool]$dryRun
    )
    if(Test-Path $csvPath){
        $wksInventory = Import-CSV $csvPath
    }else{
        Write-Host "The provided CSV path was not found."
        break
    }
    $wksStartList = $wksInventory | where {$_.Region -eq $region} | where {$_.State -eq 'STOPPED'}
    if($wksStartList.WorkspaceId.count -eq 0){
        Write-Host "No WorkSpaces are available to be started in the provided CSV."
        break
    }

    $response = Read-Host "There are currently"$wksStartList.WorkspaceId.count"WorkSpaces in your list that will be started. Would you like to Start these WorkSpaces? (Y/N)"
    if($response -like 'Y'){
        $counter = 0
        $builder = @()
        
        foreach($wks in $wksStartList){
            $counter++
            if($counter -eq $wksStartList.WorkspaceId.count){
                $builder += $wks.WorkSpaceId
                $callBlock = "Start-WKSWorkspace -Region $region -WorkSpaceId $builder"
                $scriptblock = [Scriptblock]::Create($callBlock) 
                if($dryRun -eq $true){
                    Write-Host $callBlock
                }else{
                    try{
                        Invoke-Command -scriptblock $scriptblock
                    }Catch{
                        $msg = $_
                        $logging = New-Object -TypeName PSobject
                        $logging | Add-Member -NotePropertyName "ErrorCode" -NotePropertyValue "Error During Rebuild"
                        $logging | Add-Member -NotePropertyName "ErrorMessage" -NotePropertyValue $msg
                        Write-Host $logging
                    }
                }
            }
            elseif($counter % 25 -ne 0){ 
                $builder += $wks.WorkSpaceId + ","
            }else{
                $builder += $wks.WorkSpaceId
                $callBlock = "Start-WKSWorkspace -Region $region -WorkSpaceId $builder"
                $scriptblock = [Scriptblock]::Create($callBlock) 
                if($dryRun -eq $true){
                    Write-Host $callBlock
                }else{
                    try{
                        Invoke-Command -scriptblock $scriptblock
                    }Catch{
                        $msg = $_
                        $logging = New-Object -TypeName PSobject
                        $logging | Add-Member -NotePropertyName "ErrorCode" -NotePropertyValue "Error During Rebuild"
                        $logging | Add-Member -NotePropertyName "ErrorMessage" -NotePropertyValue $msg
                        Write-Host $logging
                    }
                }
                $builder = @()
            }
        }
    }else{
        Write-Host "Start WorkSpaces was not executed because you answered with"`'$response`'
    }
}

function Initialize-WorkSpacesStop {
    <#
        .SYNOPSIS
            This cmdlet will invoke a Stop API against the Amazon WorkSpaces in the specified CSV inventory.
        .DESCRIPTION
            This cmdlet will ingest your WorkSpaces inventory through a specified CSV path. This is limited to the WorkSpaces that are in an AVAILABLE, 
            IMPAIRED, UNHEALTHY, or ERROR state. The WorkSpaces specified in your CSV will be stopped.
        .PARAMETER region
            This required parameter is a string value for the region you invoking the Start calls in. For example, 'us-east-1'. 
        .PARAMETER csvPath
            This is a required string parameter for the file path of your CSV inventory. If the file cannot be found, the cmdlet will exit. 
        .PARAMETER dryRun
            This is an optional boolean parameter that, if set to $true, will not invoke the Stop API calls. Instead, it will write them to the PowerShell 
            terminal as a dry run. If unspecified, the APIs will be invoked.
        .PARAMETER force
            This is an optional boolean parameter that, if set to $true, will ignore the users that have a connection state of CONNECTED. Note, by forcing
            the users connected will lose access during the stop. If unspecified, the connected users will be ignored in the stop call.
        .EXAMPLE
            Initialize-WorkSpacesStop -csvPath ./WorkSpacesInventory.csv -region us-east-1
            Initialize-WorkSpacesStop -csvPath ./WorkSpacesInventory.csv -force $true -region us-east-1
            Initialize-WorkSpacesStop -csvPath ./WorkSpacesInventory.csv -dryRun $true -region us-east-1
            Initialize-WorkSpacesStop -csvPath ./WorkSpacesInventory.csv -dryRun $true -force $true -region us-east-1
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$region,
        [Parameter(Mandatory=$true)]
        [string]$csvPath,
        [Parameter(Mandatory=$false)]
        [bool]$dryRun,
        [Parameter(Mandatory=$false)]
        [bool]$force
    )
    if(Test-Path $csvPath){
        $wksInventory = Import-CSV $csvPath
    }else{
        Write-Host "The provided CSV path was not found."
        break
    }
    if($force -eq $true){
        $wksStartList = $wksInventory | where {$_.Region -eq $region} | where {($_.State -eq 'AVAILABLE') -or ($_.State -eq 'IMPAIRED') -or ($_.State -eq 'UNHEALTHY') -or ($_.State -eq 'ERROR')}
    }else{
        $wksStartList = $wksInventory | where {$_.Region -eq $region} | where {($_.State -eq 'AVAILABLE') -or ($_.State -eq 'IMPAIRED') -or ($_.State -eq 'UNHEALTHY') -or ($_.State -eq 'ERROR')} | where {$_.ConnectionState -eq 'DISCONNECTED'}
    }
    if($wksStartList.WorkspaceId.count -eq 0){
        Write-Host "No WorkSpaces are available to be stopped in the provided CSV."
        break
    }

    $response = Read-Host "There are currently"$wksStartList.WorkspaceId.count"WorkSpaces in your list that will be stopped. Would you like to Stop these WorkSpaces? (Y/N)"
    if($response -like 'Y'){
        $counter = 0
        $builder = @()
        
        foreach($wks in $wksStartList){
            $counter++
            if($counter -eq $wksStartList.WorkspaceId.count){
                $builder += $wks.WorkSpaceId
                $callBlock = "Start-WKSWorkspace -Region $region -WorkSpaceId $builder"
                $scriptblock = [Scriptblock]::Create($callBlock) 
                if($dryRun -eq $true){
                    Write-Host $callBlock
                }else{
                    try{
                        Invoke-Command -scriptblock $scriptblock
                    }Catch{
                        $msg = $_
                        $logging = New-Object -TypeName PSobject
                        $logging | Add-Member -NotePropertyName "ErrorCode" -NotePropertyValue "Error During Rebuild"
                        $logging | Add-Member -NotePropertyName "ErrorMessage" -NotePropertyValue $msg
                        Write-Host $logging
                    }
                }
            }
            elseif($counter % 25 -ne 0){ 
                $builder += $wks.WorkSpaceId + ","
            }else{
                $builder += $wks.WorkSpaceId
                $callBlock = "Start-WKSWorkspace -Region $region -WorkSpaceId $builder"
                $scriptblock = [Scriptblock]::Create($callBlock) 
                if($dryRun -eq $true){
                    Write-Host $callBlock
                }else{
                    try{
                        Invoke-Command -scriptblock $scriptblock
                    }Catch{
                        $msg = $_
                        $logging = New-Object -TypeName PSobject
                        $logging | Add-Member -NotePropertyName "ErrorCode" -NotePropertyValue "Error During Rebuild"
                        $logging | Add-Member -NotePropertyName "ErrorMessage" -NotePropertyValue $msg
                        Write-Host $logging
                    }
                }
                $builder = @()
            }
        }
    }else{
        Write-Host "Stop WorkSpaces was not executed because you answered with"`'$response`'
    }
}

function Initialize-WorkSpacesRebuild {
    <#
        .SYNOPSIS
            This cmdlet will invoke a Rebuild API against the Amazon WorkSpaces in the specified CSV inventory.
        .DESCRIPTION
            This cmdlet will ingest your WorkSpaces inventory through a specified CSV path. This is limited to the WorkSpaces that are in an AVAILABLE, UNHEALTHY,
            STOPPED, ERROR, or REBOOTING state. The WorkSpaces specified in your CSV will be rebuilt. Note that the API used for this is one call per WorkSpace. 
        .PARAMETER region
            This required parameter is a string value for the region you invoking the Start calls in. For example, 'us-east-1'. 
        .PARAMETER csvPath
            This is a required string parameter for the file path of your CSV inventory. If the file cannot be found, the cmdlet will exit. 
        .PARAMETER dryRun
            This is an optional boolean parameter that, if set to $true, will not invoke the Rebuild API calls. Instead, it will write them to the PowerShell 
            terminal as a dry run. If unspecified, the APIs will be invoked.
        .EXAMPLE
            Initialize-WorkSpacesRebuild -csvPath ./WorkSpacesInventory.csv -region us-east-1
            Initialize-WorkSpacesRebuild -csvPath ./WorkSpacesInventory.csv -dryRun $true -region us-east-1
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$region,
        [Parameter(Mandatory=$true)]
        [string]$csvPath,
        [Parameter(Mandatory=$false)]
        [bool]$dryRun
    )
    if(Test-Path $csvPath){
        $wksInventory = Import-CSV $csvPath
    }else{
        Write-Host "The provided CSV path was not found."
        break
    }
    $wksStartList = $wksInventory | where {$_.Region -eq $region} | where {($_.State -eq 'AVAILABLE') -or ($_.State -eq 'UNHEALTHY') -or ($_.State -eq 'ERROR') -or ($_.State -eq 'STOPPED') -or ($_.State -eq 'REBOOTING')}
    if($wksStartList.WorkspaceId.count -eq 0){
        Write-Host "No WorkSpaces are available to be rebuilt in the provided CSV."
        break
    }
    $response = Read-Host "There are currently Rebuilding"$wksStartList.WorkspaceId.count"WorkSpaces in your list. Would you like to Rebuild these WorkSpaces? (Y/N)"
    if($response -like 'Y'){
        $response = Read-Host "The Rebuild action is a potentially destructive action that can result in the loss of data. Are you sure you would like to Rebuild the"$wksStartList.WorkspaceId.count"UNHEALTHY WorkSpaces? (Y/N)"
        if($response -like 'Y'){
            foreach($ws in $WorkSpaces){
                $builder = $ws.WorkSpaceId
                $callBlock = "Reset-WKSWorkspace -Region $region -WorkSpaceId $builder"
                $scriptblock = [Scriptblock]::Create($callBlock) 
                if($dryRun -eq $true){
                    Write-Host $callBlock
                }else{
                    try{
                        Invoke-Command -scriptblock $scriptblock
                    }Catch{
                        $msg = $_
                        $logging = New-Object -TypeName PSobject
                        $logging | Add-Member -NotePropertyName "ErrorCode" -NotePropertyValue "Error During Rebuild"
                        $logging | Add-Member -NotePropertyName "ErrorMessage" -NotePropertyValue $msg
                        Write-Host $logging
                    }
                }
            }
        }else{
            Write-Host "Rebuild WorkSpaces was not executed because you answered with"`'$response`'
        }
    }else{
        Write-Host "Rebuild WorkSpaces was not executed because you answered with"`'$response`'
    }
}