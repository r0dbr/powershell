# List all Subscriptions:
# Get-AzSubscription


#Get today's date
$today = (get-date).ToString("yyyyMMdd")

#Getting the day of Week
$weekday = (get-date).DayOfWeek.value__.ToString()

#Getting the day of Month
$monthday = (get-date).ToString("dd").PadLeft(2,'0')


#Connecting on Azure
$connectionName = "AzureRunAsConnection"
try{
	#Getting the service principal connection "AzureRunAsConnection"
	$servicePrincipalConnection = Get-AutomationConnection -name $connectionName
	Write-Host "Logging into Azure..."
	Add-AzAccount -ServicePrincipal -Tenant $servicePrincipalConnection.TenantID -ApplicationID $servicePrincipalConnection.ApplicationID -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint
}
catch{
	if(!$servicePrincipalConnection){
	$ErrorMessage = "Connection $connectionName not found."
	Connect-AzAccount
	$ErrorMessage = "Logged"
	throw $ErrorMessage
	}else {
		Write-Error -Message $_.Exception
		throw $_.Exception
	}
}
if($err) {
	throw $err
}


#Get all Vms:
$machine_list=(Get-AzResource -ResourceType Microsoft.Compute/virtualMachines)

#Getting the machine information
foreach ($machine in $machine_list )  {
	$backup = $false
	Write-Host ""
	Write-Host "------------------------"
	$machine_name = $machine.Name
	$location = $machine.Location
	$resourceGroupName = $machine.ResourceGroupName
	Write-Host "Machine ID = $machine.id"
	Write-Host "Machine Name = $machine_name"
	Write-Host "Resource Group = $resourceGroupName"
	Write-Host "------------------------"

	foreach ( $magine_tag in $machine.Tags ) {
		$name_tag = ""
		$retention = ""
		$backup_retention_date = ""

		if ($magine_tag['Backup-Daily']) {
			$backup = $true
			$retention=[int]$magine_tag['Backup-Daily']
    		$name_tag="Daily"
		}
		if ( ($magine_tag['Backup-Weekly']) -and ( $weekday -eq $week_day_of_backup)) {
			$backup = $true
			$retention=[int]$magine_tag['Backup-Weekly']*7
    		$name_tag="Weekly"
		}

		#first Saturday of a Month
		$date = Get-Date
		if ( ($magine_tag['Backup-Monthly']) -and ($date.Day -lt 7) -and ($date.DayOfWeek -eq "Friday") ) {
			$backup = $true
			$retention=[int]$magine_tag['Backup-Monthly']*31
    		$name_tag="Monthly"
		}
	}
	$expiration_date = (get-date).AddDays($retention).ToString("yyyyMMdd")
	if ( $backup ) {
		Write-Host "Backup Details:"
		Write-Host "  - Backup Type: $name_tag"
		Write-Host "  - Retention: $retention days"
		Write-Host "  - Date of exclusion: $backup_retention_date"
		$prefix = "snap-"
		$timestamp = Get-Date -f yyyyMMdd-HHmmss
		$timestampseparator = "-"
		$tagname = @{Expiration="$expiration_date";Name="$prefix";Description="$prefix + snapshot";Department="RMG-IT";Admin="Rodrigo Carvalho";Owner="Rodrigo Sakakibara"}
		$snapshotName = $prefix + $machine_name + $timestampseparator + $timestamp
		$vm = Get-AzVM -ResourceGroupName $resourceGroupName -Name $machine_name

		# Performing backup from the primary disks
		Write-Host "  - Snapstot Name: $snapshotName"
		$snapshot = New-AzSnapshotConfig -Tag $tagname -SourceUri $vm.StorageProfile.OsDisk.ManagedDisk.Id -Location $location -CreateOption copy
		New-AzSnapshot -Snapshot $snapshot -SnapshotName $snapshotName -ResourceGroupName $resourceGroupName

		if($vm.StorageProfile.DataDisks.Count -ge 1){
			Write-Host "  - Aditional Disks:"
			#Condition with more than one data disks
			for($i=0; $i -le $vm.StorageProfile.DataDisks.Count - 1; $i++){

				#Snapshot name of the data disk
				$snapshotName = $prefix + $vm.StorageProfile.DataDisks[$i].Name + $timestampseparator + $timestamp

				#Create snapshot configuration
				$snapshot = New-AzSnapshotConfig -Tag $tagname -SourceUri $vm.StorageProfile.DataDisks[$i].ManagedDisk.Id -Location $location -CreateOption copy

				#Taking the snapshot of the aditional Disk
				Write-Host "     * Snapstot Name: $snapshotName"
				New-AzSnapshot -Snapshot $snapshot -SnapshotName $snapshotName -ResourceGroupName $resourceGroupName
			}
		}

	} else {
		Write-Host "** No Backup Defined **"
	}
	
}
