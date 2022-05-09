echo "Starting the backup..."

# List all Subscriptions:
# Get-AzSubscription

#Get the date with the righ timezone
$tDate =(Get-Date).ToUniversalTime()

#Getting the timezone
$tz = [System.TimeZoneInfo]::FindSystemTimeZoneById("Eastern Standard Time")

#getting the date object with the correct timezone
$tCurrentTime = [System.TimeZoneInfo]::ConvertTimeFromUtc($tDate, $tz)

#Get today's date
$today = (get-date -Date $tCurrentTime).ToString("yyyyMMdd")

#Getting the day of Week
$weekday = (get-date -Date $tCurrentTime).DayOfWeek
$week_day_of_backup = "Saturday"

#Getting the day of Month
$monthday = (get-date -Date $tCurrentTime).ToString("dd").PadLeft(2,'0')


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
	$machine_name = $machine.Name
	$location = $machine.Location
	$resourceGroupName = $machine.ResourceGroupName
	$machine_type = $machine.Type

	echo "Machine Name = $machine_name"

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
		$date = (Get-Date -Date $tCurrentTime)
		if ( ($magine_tag['Backup-Monthly']) -and ($date.Day -lt 7) -and ($date.DayOfWeek -eq "Friday") ) {
			$backup = $true
			$retention=[int]$magine_tag['Backup-Monthly']*31
    		$name_tag="Monthly"
		}
	}
	$expiration_date = (get-date -Date $tCurrentTime).AddDays($retention).ToString("yyyyMMdd")
	if ( $backup ) {
		echo "Machine ID = $machine.id"
		echo "Resource Group = $resourceGroupName"
		echo "Resource Group = $resourceGroupName"
		echo "Machine Type = $machine_type"
		echo "Backup Details:"
		echo "  - Backup Type: $name_tag"
		echo "  - Retention: $retention days"
		echo "  - Date of exclusion: $expiration_date"
		$prefix = "snap-"
		$timestamp = (Get-Date -Date $tCurrentTime -f yyyyMMdd-HHmmss)
		$timestampseparator = "-"
		$tagname = @{Expiration="$expiration_date";Name="$prefix";Description="$prefix + snapshot";Department="RMG-IT";Admin="Rodrigo Carvalho";Owner="Rodrigo Sakakibara"}
		$snapshotName = $prefix + $machine_name + $timestampseparator + $timestamp
		$vm = Get-AzVM -ResourceGroupName $resourceGroupName -Name $machine_name

		# Performing backup from the primary disks
		echo "  - Snapstot Name: $snapshotName"
		$snapshot = New-AzSnapshotConfig -Tag $tagname -SourceUri $vm.StorageProfile.OsDisk.ManagedDisk.Id -Location $location -CreateOption copy
		#New-AzSnapshot -Snapshot $snapshot -SnapshotName $snapshotName -ResourceGroupName $resourceGroupName

		if($vm.StorageProfile.DataDisks.Count -ge 1){
			echo "  - Aditional Disks:"
			#Condition with more than one data disks
			for($i=0; $i -le $vm.StorageProfile.DataDisks.Count - 1; $i++){

				#Snapshot name of the data disk
				$snapshotName = $prefix + $vm.StorageProfile.DataDisks[$i].Name + $timestampseparator + $timestamp

				#Create snapshot configuration
				$snapshot = New-AzSnapshotConfig -Tag $tagname -SourceUri $vm.StorageProfile.DataDisks[$i].ManagedDisk.Id -Location $location -CreateOption copy

				#Taking the snapshot of the aditional Disk
				echo "     * Snapstot Name: $snapshotName"
				#New-AzSnapshot -Snapshot $snapshot -SnapshotName $snapshotName -ResourceGroupName $resourceGroupName
			}
		}

	} else {
		echo "** No Backup Defined **"

	}
	echo "------------------------"	
}
echo "Deleting expired snapshots..."
Get-AzSnapshot | foreach {
	$expiration=$_.Tags['Expiration']
	if ( $expiration -lt (get-date  -Date $tCurrentTime -f yyyyMMdd)) {
		$snapshot_name = $_.Name
		$snapshot_id = $_.Id
		$snapthot_resource = $_.ResourceGroupName
		echo "Deleting snapshot $snapshot_name with expiration $expiration"
		echo "Remove-AzSnapshot  -AsJob -ResourceGroupName $snapthot_resource  -SnapshotName $snapshot_name -Force"
	
	}
}
