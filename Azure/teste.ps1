
#Get today's date
$today = (get-date).ToString("yyyyMMdd")

#Getting the day of Week
$weekday = (get-date).DayOfWeek.value__.ToString()

#Getting the day of Month
$monthday = (get-date).ToString("dd").PadLeft(2,'0')

# Getting the tags
$backup_daily=7
$backup_weeky=2
$backup_monthly=7

# Defining the day that backups will be performerd
$week_day_of_backup = 6
$monthly_day_of_backup = 1

$backup_retention_date=0
$name_tag=""

#Defining the backup Strategy
if ($backup_daily -gt 0) {
    $retention=$backup_daily
    $name_tag="Daily"
}

if (($backup_weeky -gt 0) -and ( $weekday -eq $week_day_of_backup)) {
    $retention=7*$backup_weeky
    $name_tag="Weekly"
    
}

$monthly_day_of_backup = $monthly_day_of_backup.ToString().PadLeft(2,'0')

if (($backup_monthly -gt 0) -and ( $monthday -eq $monthly_day_of_backup)) {
    $retention=31*$backup_monthly
    $name_tag="Monthly"
    
}

# Showing the backup that will be executed
$backup_retention_date = (get-date).AddDays($retention).ToString("yyyyMMdd")
echo "Backup Type: $name_tag"
echo "Retention: $retention days"
echo "Date of exclusion: $backup_retention_date"


#Connecting on Azure
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

