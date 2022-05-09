# Azure Backup Servers 	


$connectionName = "AzureRunAsConnection"
try{
	#Getting the service principal connection "AzureRunAsConnection"
	$servicePrincipalConnection = Get-AutomationConnection -name $connectionName
	"Logging into Azure..."
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
echo "listing servers"

# Get VMs with snapshot tag
$tagResList = (Get-AzResource -TagName "Backup-Daily") | foreach {
	Get-AzResource -ResourceId $_.resourceid
}
 

foreach($tagRes in $tagResList) {

	if($tagRes.ResourceId -match "Microsoft.Compute")
	{
		$vmInfo = Get-AzVM -ResourceGroupName $tagRes.ResourceId.Split("//")[4] -Name $tagRes.ResourceId.Split("//")[8]
		#Set local variables
		$prefix = "snap-"
		$location = $vmInfo.Location
		$resourceGroupName = $vmInfo.ResourceGroupName
		$tagvalue = (get-date).AddDays(+30).ToString("yyyyMMdd")
        $tagname = @{Expiration="$tagvalue";Name="$prefix";Description="$prefix + snapshot";Department="RMG-IT";Admin="Jose Quintero";Owner="Rodrigo Sakakibara"}
        $timestamp = Get-Date -f yyyyMMdd-HHmmss
		$timestampseparator = "-"
		#Snapshot name of OS data disk
		$snapshotName = $prefix + $vmInfo.Name + $timestampseparator + $timestamp
		#Create snapshot configuration
		echo "Creating snapshot: $snapshotName"
		#$snapshot = New-AzSnapshotConfig -Tag $tagname -SourceUri $vmInfo.StorageProfile.OsDisk.ManagedDisk.Id -Location $location -CreateOption copy
		#Take snapshot
		#New-AzSnapshot -Snapshot $snapshot -SnapshotName $snapshotName -ResourceGroupName $resourceGroupName
		if($vmInfo.StorageProfile.DataDisks.Count -ge 1){
			#Condition with more than one data disks
			for($i=0; $i -le $vmInfo.StorageProfile.DataDisks.Count - 1; $i++){
				#Snapshot name of OS data disk
				$snapshotName = $prefix + $vmInfo.StorageProfile.DataDisks[$i].Name + $timestampseparator + $timestamp
				#Create snapshot configuration
				#$snapshot = New-AzSnapshotConfig -Tag $tagname -SourceUri $vmInfo.StorageProfile.DataDisks[$i].ManagedDisk.Id -Location $location -CreateOption copy
				#Take snapshot
                echo "$snapshotName"
				#New-AzSnapshot -Snapshot $snapshot -SnapshotName $snapshotName -ResourceGroupName $resourceGroupName
			}
		}
		else{
			Write-Host $vmInfo.Name + " doesn't have any additional data disk."
		}
	}
	else{
		$tagRes.ResourceId + " is not a compute instance"
		}
}