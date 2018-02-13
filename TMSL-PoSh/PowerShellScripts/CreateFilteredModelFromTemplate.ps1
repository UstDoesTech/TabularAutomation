$masterFolderLocation = "C:\Temp\Master\"
$tabularModelDeploymentLocation = "C:\Temp\TabularModels\"
$templateTabular = $masterFolderLocation + 'AdventureworksTabular_LARGE.json'

$month = "May"
$year = "2013"

$databaseName = "AdventureWorksFilteredModel $month $year"

$impersonationMode = "impersonateAccount"
#$account = "DOMAIN\\USERNAME"
#$password = "PASSWORD"

$tabularModel = Get-Content $templateTabular | Out-String
$tabularModel = $tabularModel -replace "%DATABASENAME%", $databaseName
$tabularModel = $tabularModel -replace "%MONTH%", $month
$tabularModel = $tabularModel -replace "%YEAR%", $year
$tabularModel = $tabularModel -replace "%IMPERSONATIONMODE%", $impersonationMode
$tabularModel = $tabularModel -replace "%ACCOUNT%", $account
$tabularModel = $tabularModel -replace "%PASSWORD%", $password

$tabularModel | out-file "$tabularModelDeploymentLocation $databaseName.json"

# AAS: Provider=MSOLAP;Data Source=asazure://westeurope.asazure.windows.net/adventureworksssas;Initial Catalog=<Initial Catalog>
$serverName = "localhost"
# Refresh options for database are: full clearValues calculate dataOnly automatic defragment
$refreshType = "automatic"

# Deploy the new database
Invoke-ASCmd –InputFile "$tabularModelDeploymentLocation $databaseName.json" -Server $serverName
# Process the new database
Invoke-ASCmd -Server $serverName -Query "{""refresh"":{""type"": ""$refreshType"", ""objects"": [{""database"": ""$databaseName""}]}}"

