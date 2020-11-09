<# 
Execute this script to programatically find and close any handles on an Azure storage account file share.
This is useful for times like when FSLogix profiles are being locked by a zombie session
Requirements: 
- Run on machine on a network allowed to access the Az storage. 
- Must have Az.Accounts and Az.Storage. 
- Azure Account used must have appropriate permissions.
#>

# Detect if Modules are installed
$stormodule = Get-InstalledModule -Name "Az.Storage"
$returnstore = $stormodule.Name | Select-String "Az.Storage"
$accmodule = Get-InstalledModule -Name "Az.Accounts"
$returnacc = $accmodule.Name | Select-String "Az.Accounts"

if ($null -eq $returnstore -or $null -eq $returnacc)
{
Write-Host "Please install the Az Module or Az.Storage and Az.Accounts"
break
}

# Import Needed Modules
Import-Module Az.Accounts
Import-Module Az.Storage

# Log into Azure with User Cred
Write-Host "Prompting for Azure Account" -ForegroundColor Green
$null = Connect-AzAccount

# Prompt for information. Can be hard coded here if desired (or added as parameters)
$subId = Read-Host -Prompt "SubscriptionID: "
$rg = Read-Host -Prompt "Azure SA Resource Group: "
$StorageName = Read-Host -Prompt "Storage Account Name: "
$ShareName =  Read-Host -Prompt "Azure Files Share Name: "
$user = Read-Host -Prompt "Username with Locked Profile: "

# Set Azure context, make sure subscription is correct
Write-Host "setting subcription to: $subid " -ForegroundColor Green
$null = Set-AzContext -SubscriptionId $subId

# Get storage account key, and set context for storage account. retreive file handles and store in variable
$key = Get-AzStorageAccountkey -ResourceGroupName $rg -Name $StorageName
$ctx = New-AzStorageContext -StorageAccountName $StorageName -StorageAccountKey $key.value[0]
$getAzSFH = Get-AzStorageFileHandle -ShareName $ShareName -Recursive -context $ctx | Sort-Object ClientIP,OpenTime,Path

# Retrieve handles, Display with path and IP
foreach ($vmIP in $getAzSFH){
    if ($vmIP.path -match $user){
        Write-Host -NoNewline "Handle found matching $user : "
        Write-Host -NoNewline "IP:  $($vmIp.ClientIP), " -ForegroundColor Cyan
        write-host  "Path:  $($vmIP.path) " -ForegroundColor Magenta
    }
}

# Prompt to close handles
$ynclose = Read-Host -Prompt "Attempt to close these handles? (Y or N): "

# Close all handles that matched eariler
if ($ynclose -match "[yY]"){
    foreach ($handle in $getAzSFH){
        if ($handle.path -match $user){
            Write-Host "Closing $($handle.path) " -ForegroundColor Yellow
            Close-AzStorageFileHandle -ShareName $ShareName -context $ctx -Path $handle.Path -CloseAll

        }
    }
}
else {
    Write-Host "No handles closed" -ForegroundColor Green
}

# Log out of Azure session
Write-Host "Tasks complete, logging out of Azure session"
$DC = get-azcontext
$null = Disconnect-AzAccount $dc.Account.Id
